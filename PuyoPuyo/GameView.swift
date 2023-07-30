//
//  GameView.swift
//  PuyoPuyo
//
//  Created by Joshua Homann on 7/30/23.
//

import SwiftUI

struct GameView: View {
    private let viewModel = GameModel()
    @State private var phantom: [GameModel.Puyo] = []
    @GestureState private var isDraggingPiece: Bool? = nil
    var body: some View {
        CellLayout(
            rows: GameModel.Constant.rowCount,
            columns: GameModel.Constant.columnCount,
            onUpdateGeometry: viewModel.update(geometry:)
        ) {
            ForEach(GameModel.Constant.rows, id: \.self) { y in
                ForEach(GameModel.Constant.columns, id: \.self) { x in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill((x + y).isMultiple(of: 2) ? Color.white.opacity(0.95) :  Color.white.opacity(0.75))
                        .cellLocation(x, y)
                        .padding(2)
                        .zIndex(-1)
                }
            }
            ForEach(viewModel.cells) { cell in
                Puyo(cell: cell).cellLocation(cell.x, cell.y)
                    .scaleEffect(cell.isRemoved ? 0 : 1)
                    .opacity(cell.isRemoved ? 0 : 1)
                    .animation(.linear(duration: 1), value: cell.isRemoved)
            }
            Puyo(cell: viewModel.player[0])
                .cellLocation(viewModel.player[0].x, viewModel.player[0].y)
                .opacity(viewModel.showPlayer ? 1 : 0)
                .overlay(
                    Puyo(cell: viewModel.player[1])
                        .opacity(viewModel.showPlayer ? 1 : 0)
                        .rotationEffect(-viewModel.orbit)
                        .offset(x: viewModel.cellGeometry.cellSize.width)
                        .rotationEffect(viewModel.orbit)
                )
            ForEach(phantom) { phantom in
                Puyo(cell: phantom)
                    .opacity(0.5)
                    .cellLocation(phantom.x, phantom.y)
            }
        }
        .coordinateSpace(name: Space.board)
        .task { await viewModel() }
        .gesture(DragGesture(minimumDistance: 10, coordinateSpace: .named(Space.board))
            .updating($isDraggingPiece) { drag, isDraggingPiece, _ in
                isDraggingPiece = isDraggingPiece ?? viewModel.player(contains: drag.startLocation)
                guard isDraggingPiece == true else { return }
                let proposed = viewModel.cells(for: drag.location)
                if proposed.count == 2 && (phantom.isEmpty || phantom[0].x != proposed[0].x || phantom[0].y != proposed[0].y) {
                    DispatchQueue.main.async {
                        phantom = proposed
                    }
                }
            }
            .onEnded { action in
                DispatchQueue.main.async {
                    viewModel.move(to: action.location)
                    phantom = []
                }
            }
        )
        .onTapGesture {
            guard viewModel.canRotate() else { return }
            withAnimation { viewModel.rotate() }
        }
        .onChange(of: viewModel.tick) { _, _ in
            withAnimation(.linear(duration: viewModel.dropTime)) {
                viewModel.drop()
            } completion: {
                guard viewModel.canMove else { return }
                viewModel.canMove = false
                Task { @MainActor in
                    if viewModel.showPlayer == false {
                        repeat {
                            while viewModel.canCollapse() {
                                withAnimation(.linear(duration: viewModel.dropTime)) {
                                    viewModel.collapse()
                                }
                                try? await Task.sleep(nanoseconds: UInt64(viewModel.dropTime * 1e9))
                            }
                            let matches = viewModel.matches()
                            if !matches.isEmpty {
                                viewModel.animateRemove(matches: matches)
                                try? await Task.sleep(for: .milliseconds(250))
                                viewModel.remove(matches: matches)
                            }
                        } while viewModel.canCollapse()
                        viewModel.nextPiece()
                    }
                    viewModel.canMove = true
                }
            }
        }
        .padding()
    }
}

extension GameView {
    enum Space: Hashable {
        case board
    }
}
