import SwiftUI

class Haptic {
    static let shared = Haptic()
    func snap() { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    func light() { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

enum DrawingTool: String, CaseIterable {
    case move, curve, rectangle, ellipse, line, point, label, eraser
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
        case .rectangle(let s, let e), .ellipse(let s, let e), .line(let s, let e):
            return CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: max(30.0, abs(e.x - s.x)), height: max(30.0, abs(e.y - s.y))).insetBy(dx: -20.0, dy: -20.0)
        case .smoothCurve(let pts, _):
            let xs = pts.map { $0.x }; let ys = pts.map { $0.y }
            let minX = (xs.min() ?? 0.0), minY = (ys.min() ?? 0.0)
            return CGRect(x: minX, y: minY, width: (xs.max() ?? 0.0) - minX, height: (ys.max() ?? 0.0) - minY).insetBy(dx: -20.0, dy: -20.0)
        case .point(let p):
            return CGRect(x: p.x - 15.0, y: p.y - 15.0, width: 30.0, height: 30.0)
        case .label(_, let p, let sc):
            let w = 200.0 * sc, h = 100.0 * sc
            return CGRect(x: p.x - (w / 2.0), y: p.y - (h / 2.0) - (15.0 * sc), width: w, height: h)
        }
    }
    
    var snapPoints: [CGPoint] {
        switch type {
        case .rectangle(let s, let e):
            let minX = min(s.x, e.x), maxX = max(s.x, e.x)
            let minY = min(s.y, e.y), maxY = max(s.y, e.y)
            let center = CGPoint(x: (minX + maxX) / 2.0, y: (minY + maxY) / 2.0)
            return [
                CGPoint(x: minX, y: minY),
                CGPoint(x: maxX, y: maxY),
                CGPoint(x: minX, y: maxY),
                CGPoint(x: maxX, y: minY),
                center,
                CGPoint(x: center.x, y: minY),
                CGPoint(x: center.x, y: maxY),
                CGPoint(x: minX, y: center.y),
                CGPoint(x: maxX, y: center.y)
            ]
        case .ellipse(let s, let e):
            let minX = min(s.x, e.x), maxX = max(s.x, e.x)
            let minY = min(s.y, e.y), maxY = max(s.y, e.y)
            let center = CGPoint(x: (minX + maxX) / 2.0, y: (minY + maxY) / 2.0)
            return [
                CGPoint(x: minX, y: minY),
                CGPoint(x: maxX, y: maxY),
                CGPoint(x: minX, y: maxY),
                CGPoint(x: maxX, y: minY),
                center,
                CGPoint(x: center.x, y: minY),
                CGPoint(x: center.x, y: maxY),
                CGPoint(x: minX, y: center.y),
                CGPoint(x: maxX, y: center.y)
            ]
        case .line(let s, let e): return [s, e, CGPoint(x: (s.x + e.x) / 2.0, y: (s.y + e.y) / 2.0)]
        case .smoothCurve(let p, _): return [p.first, p.last].compactMap { $0 }
        case .point(let p): return [p]
        case .label(_, let p, _): return [p]
        }
    }
    
    func closestPointOnEdge(to point: CGPoint) -> CGPoint? {
        switch type {
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
            
        default: return nil
        }
    }
    
    func hitTest(_ point: CGPoint) -> Bool {
        if !boundingBox.contains(point) { return false }
        let tolerance: CGFloat = 15.0
        
        switch type {
        case .label: return true
        case .point(let p): return point.distance(to: p) < tolerance
        case .line(let s, let e): return point.distanceToLineSegment(start: s, end: e) < tolerance
        case .rectangle(let s, let e):
            let rect = CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
            if style.fillType != .none && rect.contains(point) { return true }
            let p1 = CGPoint(x: rect.minX, y: rect.minY), p2 = CGPoint(x: rect.maxX, y: rect.minY)
            let p3 = CGPoint(x: rect.maxX, y: rect.maxY), p4 = CGPoint(x: rect.minX, y: rect.maxY)
            return point.distanceToLineSegment(start: p1, end: p2) < tolerance || point.distanceToLineSegment(start: p2, end: p3) < tolerance || point.distanceToLineSegment(start: p3, end: p4) < tolerance || point.distanceToLineSegment(start: p4, end: p1) < tolerance
        case .ellipse(let s, let e):
            let rect = CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: abs(e.x - s.x), height: abs(e.y - s.y))
            if style.fillType != .none && rect.contains(point) { return true }
            let rx = rect.width / 2.0, ry = rect.height / 2.0
            if rx <= 0 || ry <= 0 { return false }
            let distToEdge = abs(sqrt(pow((point.x - rect.midX) / rx, 2) + pow((point.y - rect.midY) / ry, 2)) - 1.0) * min(rx, ry)
            return distToEdge < tolerance
        case .smoothCurve(let pts, let isClosed):
            for i in 0 ..< pts.count - 1 { if point.distanceToLineSegment(start: pts[i], end: pts[i+1]) < tolerance { return true } }
            if isClosed, let f = pts.first, let l = pts.last { if point.distanceToLineSegment(start: l, end: f) < tolerance { return true } }
            return false
        }
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
