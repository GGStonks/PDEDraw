import SwiftUI

class Haptic {
    static let shared = Haptic()
    func snap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

enum DrawingTool: String, CaseIterable {
    case move, curve, scribble, lasso, rectangle, ellipse, line, point, label, eraser
}

enum LineStyle: String, CaseIterable {
    case solid, dashed, dotted
}

enum FillType: String, CaseIterable {
    case none, solid, northEast, northWest, crosshatch, hole
}

enum ShapeColor: String, CaseIterable {
    case graphite = "black", rose = "purple", ocean = "blue", teal = "teal", amber = "orange"
    var swiftUIColor: Color {
        switch self {
        case .graphite: return .primary
        case .rose: return .pink
        case .ocean: return .indigo
        case .teal: return .teal
        case .amber: return .orange
        }
    }
}

struct ShapeStyle {
    var color: ShapeColor = .graphite
    var lineStyle: LineStyle = .solid
    var fillType: FillType = .none
    var hasArrow: Bool = false
    
    var strokeStyle: StrokeStyle {
        switch lineStyle {
        case .solid: return StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
        case .dashed: return StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [10.0, 8.0])
        case .dotted: return StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round, dash: [2.0, 6.0])
        }
    }
}

enum ShapeType {
    case smoothCurve(points: [CGPoint], isClosed: Bool)
    case scribble(points: [CGPoint])
    case triangle(start: CGPoint, end: CGPoint)
    case rectangle(start: CGPoint, end: CGPoint)
    case ellipse(start: CGPoint, end: CGPoint)
    case line(start: CGPoint, end: CGPoint)
    case point(position: CGPoint)
    case label(text: String, position: CGPoint, scale: CGFloat)
}

struct DrawnShape: Identifiable {
    let id = UUID()
    var type: ShapeType
    var style: ShapeStyle
    
    var boundingBox: CGRect {
        switch type {
        case .triangle(let s, let e), .rectangle(let s, let e), .ellipse(let s, let e), .line(let s, let e):
            return CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: max(30.0, abs(e.x - s.x)), height: max(30.0, abs(e.y - s.y))).insetBy(dx: -20.0, dy: -20.0)
        case .smoothCurve(let pts, _):
            let xs = pts.map { $0.x }; let ys = pts.map { $0.y }
            let minX = (xs.min() ?? 0.0), minY = (ys.min() ?? 0.0)
            return CGRect(x: minX, y: minY, width: (xs.max() ?? 0.0) - minX, height: (ys.max() ?? 0.0) - minY).insetBy(dx: -20.0, dy: -20.0)
        case .scribble(let pts):
            let xs = pts.map { $0.x }; let ys = pts.map { $0.y }
            let minX = (xs.min() ?? 0.0), minY = (ys.min() ?? 0.0)
            return CGRect(x: minX, y: minY, width: (xs.max() ?? 0.0) - minX, height: (ys.max() ?? 0.0) - minY).insetBy(dx: -14.0, dy: -14.0)
        case .point(let p):
            return CGRect(x: p.x - 15.0, y: p.y - 15.0, width: 30.0, height: 30.0)
        case .label(_, let p, let sc):
            let w = 200.0 * sc, h = 100.0 * sc
            return CGRect(x: p.x - (w / 2.0), y: p.y - (h / 2.0) - (15.0 * sc), width: w, height: h)
        }
    }
    
    var snapPoints: [CGPoint] {
        switch type {
        case .triangle(let s, let e):
            let p = trianglePoints(start: s, end: e)
            let center = CGPoint(x: (p[0].x + p[1].x + p[2].x) / 3.0, y: (p[0].y + p[1].y + p[2].y) / 3.0)
            return [p[0], p[1], p[2], center]
        case .rectangle(let s, let e):
            let c = CGPoint(x: (s.x + e.x) / 2.0, y: (s.y + e.y) / 2.0)
            let p1 = CGPoint(x: min(s.x, e.x), y: min(s.y, e.y))
            let p2 = CGPoint(x: max(s.x, e.x), y: min(s.y, e.y))
            let p3 = CGPoint(x: max(s.x, e.x), y: max(s.y, e.y))
            let p4 = CGPoint(x: min(s.x, e.x), y: max(s.y, e.y))
            return [
                p1, p2, p3, p4, c,
                CGPoint(x: c.x, y: p1.y),
                CGPoint(x: p3.x, y: c.y),
                CGPoint(x: c.x, y: p3.y),
                CGPoint(x: p1.x, y: c.y)
            ]
        case .ellipse(let s, let e):
            let minX = min(s.x, e.x)
            let maxX = max(s.x, e.x)
            let minY = min(s.y, e.y)
            let maxY = max(s.y, e.y)
            let c = CGPoint(x: (minX + maxX) / 2.0, y: (minY + maxY) / 2.0)
            let rx = (maxX - minX) / 2.0
            let ry = (maxY - minY) / 2.0
            let diagonal = CGFloat(0.70710678118)
            return [
                CGPoint(x: minX, y: minY),
                CGPoint(x: maxX, y: minY),
                CGPoint(x: maxX, y: maxY),
                CGPoint(x: minX, y: maxY),
                c,
                CGPoint(x: c.x, y: c.y - ry),
                CGPoint(x: c.x + rx, y: c.y),
                CGPoint(x: c.x, y: c.y + ry),
                CGPoint(x: c.x - rx, y: c.y),
                CGPoint(x: c.x + rx * diagonal, y: c.y - ry * diagonal),
                CGPoint(x: c.x + rx * diagonal, y: c.y + ry * diagonal),
                CGPoint(x: c.x - rx * diagonal, y: c.y + ry * diagonal),
                CGPoint(x: c.x - rx * diagonal, y: c.y - ry * diagonal)
            ]
        case .line(let s, let e): return [s, e, CGPoint(x: (s.x + e.x) / 2.0, y: (s.y + e.y) / 2.0)]
        case .smoothCurve(let p, _):
            guard p.count > 2 else { return [p.first, p.last].compactMap { $0 } }
            let strideCount = max(1, p.count / 8)
            var sampled = [p.first, p.last].compactMap { $0 }
            for index in stride(from: strideCount, to: p.count - 1, by: strideCount) {
                sampled.append(p[index])
            }
            return sampled
        case .scribble(let p):
            guard p.count > 2 else { return [p.first, p.last].compactMap { $0 } }
            let strideCount = max(1, p.count / 12)
            var sampled = [p.first, p.last].compactMap { $0 }
            for index in stride(from: strideCount, to: p.count - 1, by: strideCount) {
                sampled.append(p[index])
            }
            return sampled
        case .point(let p): return [p]
        case .label(_, let p, _): return [p]
        }
    }
    
    func closestPointOnEdge(to point: CGPoint) -> CGPoint? {
        switch type {
        case .triangle(let s, let e):
            let p = trianglePoints(start: s, end: e)
            let edges = [point.project(start: p[0], end: p[1]), point.project(start: p[1], end: p[2]), point.project(start: p[2], end: p[0])]
            return edges.min(by: { point.distance(to: $0) < point.distance(to: $1) })
        case .ellipse(let s, let e):
            let cx = (s.x + e.x) / 2.0, cy = (s.y + e.y) / 2.0
            let rx = abs(e.x - s.x) / 2.0, ry = abs(e.y - s.y) / 2.0
            let angle = atan2(point.y - cy, point.x - cx)
            return CGPoint(x: cx + rx * cos(angle), y: cy + ry * sin(angle))
            
        case .rectangle(let s, let e):
            let p1 = CGPoint(x: min(s.x, e.x), y: min(s.y, e.y)), p2 = CGPoint(x: max(s.x, e.x), y: min(s.y, e.y))
            let p3 = CGPoint(x: max(s.x, e.x), y: max(s.y, e.y)), p4 = CGPoint(x: min(s.x, e.x), y: max(s.y, e.y))
            let edges = [point.project(start: p1, end: p2), point.project(start: p2, end: p3), point.project(start: p3, end: p4), point.project(start: p4, end: p1)]
            return edges.min(by: { point.distance(to: $0) < point.distance(to: $1) })
            
        case .line(let s, let e):
            return point.project(start: s, end: e)
            
        case .smoothCurve(let pts, let isClosed):
            var closest: CGPoint? = nil
            var minDist: CGFloat = .infinity
            for i in 0 ..< pts.count - 1 {
                let proj = point.project(start: pts[i], end: pts[i+1])
                let d = point.distance(to: proj)
                if d < minDist { minDist = d; closest = proj }
            }
            if isClosed, let f = pts.first, let l = pts.last {
                let proj = point.project(start: l, end: f)
                let d = point.distance(to: proj)
                if d < minDist { minDist = d; closest = proj }
            }
            return closest
        case .scribble(let pts):
            guard pts.count > 1 else { return pts.first }
            var closest: CGPoint? = nil
            var minDist: CGFloat = .infinity
            for i in 0 ..< pts.count - 1 {
                let proj = point.project(start: pts[i], end: pts[i + 1])
                let d = point.distance(to: proj)
                if d < minDist { minDist = d; closest = proj }
            }
            return closest
            
        default: return nil
        }
    }
    
    func hitDistance(to point: CGPoint, tolerance: CGFloat = 15.0, boundingPadding: CGFloat = 20.0) -> CGFloat? {
        let paddedBounds = boundingBox.insetBy(dx: -(boundingPadding - 20.0), dy: -(boundingPadding - 20.0))
        if !paddedBounds.contains(point) { return nil }

        switch type {
        case .label(_, let p, _):
            return point.distance(to: p)
        case .point(let p):
            let d = point.distance(to: p)
            return d < tolerance ? d : nil
        case .line(let s, let e):
            let d = point.distanceToLineSegment(start: s, end: e)
            return d < tolerance ? d : nil
        case .triangle(let s, let e):
            let p = trianglePoints(start: s, end: e)
            var triPath = Path()
            triPath.move(to: p[0])
            triPath.addLine(to: p[1])
            triPath.addLine(to: p[2])
            triPath.closeSubpath()
            if style.fillType != .none && triPath.contains(point) { return 0.0 }
            let d = min(
                point.distanceToLineSegment(start: p[0], end: p[1]),
                point.distanceToLineSegment(start: p[1], end: p[2]),
                point.distanceToLineSegment(start: p[2], end: p[0])
            )
            return d < tolerance ? d : nil
        case .rectangle(let s, let e):
            let rect = CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
            if style.fillType != .none && rect.contains(point) { return 0.0 }
            let p1 = CGPoint(x: rect.minX, y: rect.minY), p2 = CGPoint(x: rect.maxX, y: rect.minY)
            let p3 = CGPoint(x: rect.maxX, y: rect.maxY), p4 = CGPoint(x: rect.minX, y: rect.maxY)
            let d = min(
                point.distanceToLineSegment(start: p1, end: p2),
                point.distanceToLineSegment(start: p2, end: p3),
                point.distanceToLineSegment(start: p3, end: p4),
                point.distanceToLineSegment(start: p4, end: p1)
            )
            return d < tolerance ? d : nil
        case .ellipse(let s, let e):
            let rect = CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
            if style.fillType != .none && rect.contains(point) { return 0.0 }
            let rx = rect.width / 2.0, ry = rect.height / 2.0
            if rx <= 0 || ry <= 0 { return nil }
            let distToEdge = abs(sqrt(pow((point.x - rect.midX) / rx, 2) + pow((point.y - rect.midY) / ry, 2)) - 1.0) * min(rx, ry)
            return distToEdge < tolerance ? distToEdge : nil
        case .smoothCurve(let pts, let isClosed):
            var minDist: CGFloat = .infinity
            for i in 0 ..< pts.count - 1 {
                minDist = min(minDist, point.distanceToLineSegment(start: pts[i], end: pts[i+1]))
            }
            if isClosed, let f = pts.first, let l = pts.last {
                minDist = min(minDist, point.distanceToLineSegment(start: l, end: f))
            }
            return minDist < tolerance ? minDist : nil
        case .scribble(let pts):
            guard pts.count > 1 else { return nil }
            var minDist: CGFloat = .infinity
            for i in 0 ..< pts.count - 1 {
                minDist = min(minDist, point.distanceToLineSegment(start: pts[i], end: pts[i+1]))
            }
            return minDist < tolerance ? minDist : nil
        }
    }

    func hitTest(_ point: CGPoint, tolerance: CGFloat = 15.0, boundingPadding: CGFloat = 20.0) -> Bool {
        hitDistance(to: point, tolerance: tolerance, boundingPadding: boundingPadding) != nil
    }

    private func trianglePoints(start: CGPoint, end: CGPoint) -> [CGPoint] {
        let minX = min(start.x, end.x)
        let maxX = max(start.x, end.x)
        let minY = min(start.y, end.y)
        let maxY = max(start.y, end.y)
        let apex = CGPoint(x: (minX + maxX) / 2.0, y: minY)
        let rightBase = CGPoint(x: maxX, y: maxY)
        let leftBase = CGPoint(x: minX, y: maxY)
        return [apex, rightBase, leftBase]
    }
}

extension CGPoint {
    func offset(dx: CGFloat, dy: CGFloat) -> CGPoint { CGPoint(x: self.x + dx, y: self.y + dy) }
    func distance(to other: CGPoint) -> CGFloat { hypot(self.x - other.x, self.y - other.y) }
    
    func project(start: CGPoint, end: CGPoint) -> CGPoint {
        let dx = end.x - start.x, dy = end.y - start.y
        let lenSq = dx * dx + dy * dy
        if lenSq == 0 { return start }
        let t = max(0, min(1, ((self.x - start.x) * dx + (self.y - start.y) * dy) / lenSq))
        return CGPoint(x: start.x + t * dx, y: start.y + t * dy)
    }
    
    func distanceToLineSegment(start: CGPoint, end: CGPoint) -> CGFloat {
        return distance(to: project(start: start, end: end))
    }
}
