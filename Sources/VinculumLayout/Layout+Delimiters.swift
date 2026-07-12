import Foundation

extension MathLayoutEngine {

    /// A single fence glyph scaled to `targetHeight` and vertically centered on
    /// the body's extent. Shared by the inline delimiter and matrix paths,
    /// which differ only in the target height they pass.
    func stretchedFence(_ glyph: String, targetHeight: CGFloat, around bodyBox: MathBox, size: CGFloat) -> MathBox {
        guard !glyph.isEmpty else { return .empty }
        let probe = glyphBox(glyph, size: size, italic: false)
        let scale = max(1, targetHeight / max(probe.height, 1))
        let scaled = glyphBox(glyph, size: size * scale, italic: false)
        let offset = (bodyBox.ascent - bodyBox.descent) / 2 - (scaled.ascent - scaled.descent) / 2
        return MathBox(width: scaled.width, ascent: scaled.ascent + offset, descent: scaled.descent - offset,
                       elements: scaled.placed(at: CGPoint(x: 0, y: offset)))
    }

    /// `\left…\right`: a body flanked by fences sized to its height.
    func delimitedBox(_ left: String, _ body: MathNode, _ right: String, size: CGFloat, display: Bool) -> MathBox {
        let bodyBox = box(for: body, size: size, display: display)
        let target = max(bodyBox.height, size)
        let leftBox = stretchedFence(left, targetHeight: target, around: bodyBox, size: size)
        let rightBox = stretchedFence(right, targetHeight: target, around: bodyBox, size: size)
        let width = leftBox.width + bodyBox.width + rightBox.width

        var elements = leftBox.elements
        elements += bodyBox.placed(at: CGPoint(x: leftBox.width, y: 0))
        elements += rightBox.placed(at: CGPoint(x: leftBox.width + bodyBox.width, y: 0))
        return MathBox(width: width,
                       ascent: max(bodyBox.ascent, leftBox.ascent, rightBox.ascent),
                       descent: max(bodyBox.descent, leftBox.descent, rightBox.descent),
                       elements: elements)
    }

    /// Fences an already-laid-out box (a grid or stack) with stretched fences.
    func delimitedBoxAround(_ bodyBox: MathBox, left: String, right: String, size: CGFloat) -> MathBox {
        let leftBox = stretchedFence(left, targetHeight: bodyBox.height, around: bodyBox, size: size)
        let rightBox = stretchedFence(right, targetHeight: bodyBox.height, around: bodyBox, size: size)
        let width = leftBox.width + bodyBox.width + rightBox.width + size * 0.1

        var elements = leftBox.elements
        elements += bodyBox.placed(at: CGPoint(x: leftBox.width + size * 0.05, y: 0))
        elements += rightBox.placed(at: CGPoint(x: leftBox.width + bodyBox.width + size * 0.05, y: 0))
        return MathBox(width: width,
                       ascent: max(bodyBox.ascent, leftBox.ascent, rightBox.ascent),
                       descent: max(bodyBox.descent, leftBox.descent, rightBox.descent),
                       elements: elements)
    }

    /// Matrices, `cases`, `aligned`, `\substack`: a grid of cells with
    /// per-column alignment, centered on the math axis, optionally fenced.
    func matrixBox(_ rows: [[MathNode]], left: String, right: String,
                   style: MathMatrixStyle, size baseSize: CGFloat) -> MathBox {
        guard !rows.isEmpty else { return .empty }
        let size = style == .substack ? baseSize * 0.7 : baseSize

        let columns = rows.map(\.count).max() ?? 0
        var cellBoxes: [[MathBox]] = []
        var colWidth = [CGFloat](repeating: 0, count: columns)
        var rowAscent = [CGFloat](repeating: 0, count: rows.count)
        var rowDescent = [CGFloat](repeating: 0, count: rows.count)
        for (r, row) in rows.enumerated() {
            var boxes: [MathBox] = []
            for (c, cell) in row.enumerated() {
                let b = box(for: cell, size: size, display: false)
                boxes.append(b)
                colWidth[c] = max(colWidth[c], b.width)
                rowAscent[r] = max(rowAscent[r], b.ascent)
                rowDescent[r] = max(rowDescent[r], b.descent)
            }
            if row.isEmpty { rowAscent[r] = size * 0.5; rowDescent[r] = size * 0.2 }
            cellBoxes.append(boxes)
        }

        let rowGap = style == .substack ? size * 0.18 : size * 0.35
        let colGap = style == .aligned ? size * 0.16 : size * 0.7

        var totalHeight: CGFloat = 0
        for r in 0..<rows.count {
            totalHeight += rowAscent[r] + rowDescent[r]
            if r > 0 { totalHeight += rowGap }
        }
        let gridWidth = colWidth.reduce(0, +) + CGFloat(max(columns - 1, 0)) * colGap

        let axis = size * 0.26
        let ascent = totalHeight / 2 + axis
        let descent = totalHeight / 2 - axis

        var colX = [CGFloat](repeating: 0, count: columns)
        var running: CGFloat = 0
        for c in 0..<columns { colX[c] = running; running += colWidth[c] + colGap }

        func cellOriginX(col: Int, box: MathBox) -> CGFloat {
            switch style {
            case .cases: return colX[col]
            case .aligned: return col % 2 == 0 ? colX[col] + (colWidth[col] - box.width) : colX[col]
            case .centered, .substack: return colX[col] + (colWidth[col] - box.width) / 2
            }
        }

        var elements: [MathElement] = []
        var yTop = ascent
        for (r, boxes) in cellBoxes.enumerated() {
            let baseline = yTop - rowAscent[r]
            for (c, b) in boxes.enumerated() {
                elements += b.placed(at: CGPoint(x: cellOriginX(col: c, box: b), y: baseline))
            }
            yTop -= rowAscent[r] + rowDescent[r] + rowGap
        }
        let grid = MathBox(width: gridWidth, ascent: ascent, descent: descent, elements: elements)

        guard !left.isEmpty || !right.isEmpty else { return grid }
        return delimitedBoxAround(grid, left: left, right: right, size: size)
    }
}
