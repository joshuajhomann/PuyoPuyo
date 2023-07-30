import SwiftUI

struct CellLayoutValueKey: LayoutValueKey {
    static let defaultValue = (CGFloat.zero, CGFloat.zero)
}

public extension View {
    func cellLocation(_ x: Int, _ y: Int) -> some View {
        layoutValue(key: CellLayoutValueKey.self, value: (CGFloat(x),CGFloat(y)))
    }
}

public struct CellLayout: Layout {
    public typealias Cache = CellGeometry
    private let rows: Double
    private let columns: Double
    private let aspectRatio: Double
    private let cellAspectRatio: Double
    private let onUpdateGeometry: ((CellGeometry) -> Void)?
    public init(
        rows integerRows: Int,
        columns integerColumns: Int,
        cellAspectRatio: Double = 1.0,
        onUpdateGeometry: ((CellGeometry) -> Void)?
    ) {
        rows = Double(integerRows)
        columns = Double(integerColumns)
        self.cellAspectRatio = cellAspectRatio
        aspectRatio = columns / rows * cellAspectRatio
        self.onUpdateGeometry = onUpdateGeometry
    }
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize {
        let size = proposal.replacingUnspecifiedDimensions()
        let proposedAspectRatio = size.width / size.height
        return proposedAspectRatio > aspectRatio
        ? .init(
            width: size.height * aspectRatio,
            height: size.height
        )
        : .init(
            width: size.width,
            height: size.width / aspectRatio
        )
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) {
        if bounds != cache.bounds {
            cache.bounds = bounds
            let gridSize = sizeThatFits(proposal: proposal, subviews: subviews, cache: &cache)
            cache.cellSize = CGSize(width: gridSize.width / columns, height: gridSize.height / rows)
            cache.origin = .init(
                x: bounds.origin.x + (bounds.size.width - gridSize.width) * 0.5,
                y: bounds.origin.y + (bounds.size.height - gridSize.height) * 0.5
            )
            cache.centerOfFirstCell = .init(
                x: cache.origin.x + cache.cellSize.width / 2,
                y: cache.origin.y + cache.cellSize.height / 2
            )
            onUpdateGeometry?(cache)
        }
        for view in subviews {
            let (x,y) = view[CellLayoutValueKey.self]
            let cellSize = cache.cellSize
            view.place(
                at: .init(
                    x: cache.centerOfFirstCell.x + cellSize.width * x,
                    y: cache.centerOfFirstCell.y + cellSize.height * y
                ),
                anchor: .center,
                proposal: .init(width: cellSize.width, height: cellSize.height)
            )
        }
    }

    public func updateCache(_ cache: inout CellGeometry, subviews: Subviews) { }

    public func makeCache(subviews: Subviews) -> Cache {
        .init()
    }
}


extension CellLayout {
    public struct CellGeometry {
        var bounds: CGRect = .zero
        var origin: CGPoint = .zero
        var cellSize: CGSize = .zero
        var centerOfFirstCell: CGPoint = .zero
        public init() {
            bounds = .zero
            origin = .zero
            centerOfFirstCell = .zero
            cellSize = .zero
        }
    }
}
