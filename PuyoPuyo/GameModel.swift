//
//  GameModel.swift
//  PuyoPyuo
//
//  Created by Joshua Homann on 7/4/23.
//

import Foundation
import Observation
import SwiftUI

@Observable
@MainActor
final class GameModel {
    private(set) var cells: [Puyo] = []
    private(set) var player: [Puyo] = [.init(x: 4, y: 0), .init(x: 5, y: 0)]
    private(set) var showPlayer = true
    private(set) var orbit: Angle = .zero
    private(set) var tick = false
    private(set) var dropTime = 1.0
    var canMove = true
    private var board: [Puyo?] = []
    private(set) var cellGeometry: CellLayout.CellGeometry = .init()
    private var timerSubscription: Task<Void, Never>? = nil
    nonisolated init() {}
    func callAsFunction() async {
        board = Array(repeating: nil, count: Constant.rowCount * Constant.columnCount)
        startDropTimer()
    }
    nonisolated func update(geometry: CellLayout.CellGeometry) {
        Task { @MainActor [weak self] in
            self?.cellGeometry = geometry
        }
    }
    func drop() {
        if player.allSatisfy({ canMove($0.x, $0.y + 1)}) {
            player.indices.forEach { player[$0].y += 1 }
        } else {
            player.forEach { player in
                let newCell = Puyo(x: player.x, y: player.y, color: player.color)
                board[player.x + player.y * Constant.columnCount] = newCell
                cells.append(newCell)
            }
            showPlayer = false
            stopDropTimer()
        }
    }
    func canRotate() -> Bool {
        let θ = orbit.radians + .τ / 4
        let proposedX = Int(cos(θ)) + player[0].x
        let proposedY = Int(sin(θ)) + player[0].y
        return canMove(proposedX, proposedY)
    }
    func rotate() {
        let θ = orbit.radians + .τ / 4
        player[1].x = Int(cos(θ)) + player[0].x
        player[1].y = Int(sin(θ)) + player[0].y
        orbit = .radians(θ)
    }
    func move(to point: CGPoint) {
        let proposed = cells(for: point)
        guard !proposed.isEmpty else { return }
        player = proposed
        stopDropTimer()
        startDropTimer(isFast: true)
    }
    func player(contains point: CGPoint) -> Bool {
        let cellX = Int(point.x / cellGeometry.cellSize.width)
        let cellY = Int(point.y / cellGeometry.cellSize.height)
        guard cellX == player[0].x || cellX == player[1].x else { return false }
        return cellY == player[0].y ||
        cellY == player[0].y - 1 ||
        cellY == player[1].y ||
        cellY == player[1].y - 1
    }
    func cells(for point: CGPoint) -> [Puyo] {
        let cellX = Int(point.x / cellGeometry.cellSize.width)
        let cellY = max(Int(point.y / cellGeometry.cellSize.height), player[0].y)
        var copy = player.map { Puyo(x: cellX, y: cellY, color: $0.color) }
        let Δx = player[1].x - player[0].x
        let Δy = player[1].y - player[0].y
        copy[1].x += Δx
        copy[1].y += Δy
        guard copy.allSatisfy({ canMove($0.x, $0.y) }) else { return [] }
        return copy
    }
    func canCollapse() -> Bool {
        Constant.columns.contains { x in
            Constant.rows.dropLast().contains { y in
                board[x + y * Constant.columnCount] != nil && board[x + (y + 1) * Constant.columnCount] == nil
            }
        }
    }
    func collapse() {
        Constant.columns.forEach { x in
            Constant.rows.dropFirst().reversed().forEach { y in
                let currentIndex = x + y * Constant.columnCount
                let aboveIndex = x + (y - 1) * Constant.columnCount
                if board[currentIndex] == nil && board[aboveIndex] != nil {
                    board[currentIndex] = board[aboveIndex]
                    board[currentIndex]?.x = x
                    board[currentIndex]?.y = y
                    board[aboveIndex] = nil
                }
            }
        }
        cells = board.compactMap { $0 }
    }
    func matches() -> Set<Int> {
        func reduceMatches(x: Int, y: Int, target: Color, into matches: inout Set<Int>) {
            guard Constant.columns.contains(x) && Constant.rows.contains(y) else { return }
            let index = x + y * Constant.columnCount
            guard !matches.contains(index), target == board[index]?.color else { return }
            matches.insert(index)
            for (ax, ay) in Constant.adjacency.lazy.map({ (x + $0.0, y + $0.1)}) {
                reduceMatches(x: ax, y: ay, target: target, into: &matches)
            }
        }
        var matches = Set<Int>()
        return Constant.columns
            .lazy
            .flatMap { x in Constant.rows.lazy.map { y in (x,y) } }
            .reduce(into: Set<Int>()) { allMatches, coordinate in
                let (x, y) = coordinate
                let index = x + y * Constant.columnCount
                guard let target = board[index]?.color, !allMatches.contains(index) else { return }
                matches.removeAll(keepingCapacity: true)
                reduceMatches(x: x, y: y, target: target, into: &matches)
                if matches.count >= 4 {
                    allMatches.formUnion(matches)
                }
            }
    }
    func animateRemove(matches: Set<Int>) {
        for match in matches {
            board[match]?.isRemoved = true
        }
        cells = board.compactMap {$0}
    }
    func remove(matches: Set<Int>) {
        for match in matches {
            board[match] = nil
        }
        cells = board.compactMap {$0}
    }
    func nextPiece() {
        player = [.init(x: 4, y: 0), .init(x: 5, y: 0)]
        orbit = .zero
        showPlayer = true
        startDropTimer()
    }
    private func startDropTimer(isFast: Bool = false) {
        timerSubscription?.cancel()
        dropTime = isFast ? 1e-1 : 1e0
        timerSubscription = .init { @MainActor [weak self] in
            for await _ in AsyncStream(unfolding: { try? await Task.sleep(for: .milliseconds(isFast ? 100 : 1000))}) {
                guard self?.canMove ?? false else { continue }
                self?.tick.toggle()
            }
        }
    }
    private func stopDropTimer() {
        timerSubscription?.cancel()
        timerSubscription = nil
    }
    private func canMove(_ x: Int, _ y: Int) -> Bool {
        (Constant.columns).contains(x) &&
        (Constant.rows).contains(y) &&
        board[x + y * Constant.columnCount] == nil
    }
}

extension GameModel {
    enum Constant {
        static let rowCount: Int = 12
        static let columnCount: Int = 8
        static let rows = (0..<rowCount)
        static let columns = (0..<columnCount)
        static let adjacency: [(Int, Int)] = [(1,0),(-1,0),(0,1),(0,-1)]
    }
}

extension GameModel {
    struct Puyo: Identifiable, Hashable {
        var id = UUID()
        var x: Int
        var y: Int
        var color: Color
        var isRemoved = false
        init(x: Int, y: Int, color: Color = Color.allCases[(0...3).randomElement()!]) {
            self.x = x
            self.y = y
            self.color = color
        }
    }
    enum Color: Int, CaseIterable {
        case blue, purple, pink, orange, green, teal
        var angle: Angle {
            .radians(Double(rawValue) / Double(Self.allCases.count) * .τ)
        }
    }
}

extension Double {
    static let τ = 2.0 * .pi
}
