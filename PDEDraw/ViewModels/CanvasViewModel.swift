import SwiftUI
import Combine

class CanvasViewModel: ObservableObject {
    private let pointSnapThreshold: CGFloat = 14.0
    private let edgeSnapThreshold: CGFloat = 8.0
    
    @Published var shapes: [DrawnShape] = []
    @Published private(set) var canUndo: Bool = false
    @Published var currentTool: DrawingTool = .curve
    @Published var currentStyle: ShapeStyle = ShapeStyle()
    
    @Published var currentPoints: [CGPoint] = []
    @Published var currentDragStart: CGPoint? = nil
    @Published var currentDragEnd: CGPoint? = nil
    
    @Published var snapDotLocation: CGPoint? = nil
    @Published var grabbedShapeID: UUID? = nil
    private var isCurrentlySnapping: Bool = false
    private var lastMoveLocation: CGPoint? = nil
    
    @Published var typingPos: CGPoint? = nil
    
    // Performance Cache for Drag Operations (ensures 120 FPS)
    private var cachedSnapPoints: [CGPoint] = []
    private var cachedIntersections: [CGPoint] = []
    private var isDragging: Bool = false
    private var undoStack: [[DrawnShape]] = []
    private var hasCapturedMoveSnapshot: Bool = false

    private func ensureCachePrepared() {
        if !isDragging {
            isDragging = true
            cachedIntersections = getIntersections(from: shapes)
            cachedSnapPoints = shapes.flatMap { $0.snapPoints }
        }
    }

    func handleDrag(value: DragGesture.Value) {
        if currentTool == .label { return }
        
        ensureCachePrepared()
        
        let rawLoc = value.location
        let snappedLoc = findSnapPoint(near: rawLoc)
        
        switch currentTool {
        case .move:
            if grabbedShapeID == nil {
                if let hitIndex = shapes.lastIndex(where: { $0.hitTest(value.startLocation) }) {
                    grabbedShapeID = shapes[hitIndex].id
                    if !hasCapturedMoveSnapshot {
                        pushUndoSnapshot()
                        hasCapturedMoveSnapshot = true
                    }
                    lastMoveLocation = value.startLocation
                    Haptic.shared.light()
                }
            } else if let id = grabbedShapeID, let last = lastMoveLocation {
                let dx = rawLoc.x - last.x
                let dy = rawLoc.y - last.y
                translateShape(id: id, dx: dx, dy: dy)
                lastMoveLocation = rawLoc
            }
            
        case .curve:
            if currentPoints.isEmpty { currentPoints.append(value.startLocation) }
            
            if let last = currentPoints.last, rawLoc.distance(to: last) > 6.0 {
                let first = currentPoints.first!
                if rawLoc.distance(to: first) < 18.0 && currentPoints.count > 5 {
                    if snapDotLocation != first { Haptic.shared.snap() }
                    snapDotLocation = first
                } else {
                    snapDotLocation = nil
                    currentPoints.append(snappedLoc)
                }
            }
            
        case .line:
            if currentDragStart == nil { currentDragStart = findSnapPoint(near: value.startLocation) }
            if let start = currentDragStart {
                if snapDotLocation != nil {
                    currentDragEnd = snappedLoc
                } else {
                    let dx = rawLoc.x - start.x, dy = rawLoc.y - start.y, dist = hypot(dx, dy), angle = atan2(dy, dx)
                    let step = Double.pi / 12.0
                    let lockedAngle = round(angle / step) * step
                    let finalAngle = (abs(angle - lockedAngle) < 0.05) ? lockedAngle : angle
                    currentDragEnd = CGPoint(x: start.x + dist * cos(finalAngle), y: start.y + dist * sin(finalAngle))
                }
            }
            
        case .rectangle, .point:
            if currentDragStart == nil { currentDragStart = findSnapPoint(near: value.startLocation) }
            currentDragEnd = snappedLoc
            
        case .ellipse:
            if currentDragStart == nil { currentDragStart = findSnapPoint(near: value.startLocation) }
            if let start = currentDragStart {
                let dx = rawLoc.x - start.x
                let dy = rawLoc.y - start.y
                let isCircle = abs(abs(dx) - abs(dy)) < 30.0
                
                if snapDotLocation != nil {
                    if isCircle {
                        let sdx = snappedLoc.x - start.x
                        let sdy = snappedLoc.y - start.y
                        let s = max(abs(sdx), abs(sdy))
                        currentDragEnd = CGPoint(x: start.x + (sdx > 0 ? s : -s), y: start.y + (sdy > 0 ? s : -s))
                    } else {
                        currentDragEnd = snappedLoc
                    }
                } else {
                    if isCircle {
                        let s = max(abs(dx), abs(dy))
                        currentDragEnd = CGPoint(x: start.x + (dx > 0 ? s : -s), y: start.y + (dy > 0 ? s : -s))
                    } else {
                        currentDragEnd = snappedLoc
                    }
                }
            }
            
        case .eraser:
            if let hitIndex = shapes.lastIndex(where: { $0.hitTest(rawLoc) }) {
                pushUndoSnapshot()
                shapes.remove(at: hitIndex)
                Haptic.shared.light()
                isDragging = false
                ensureCachePrepared()
            }
            
        case .label: break
        }
    }

    func finishDrag(value: DragGesture.Value) {
        if currentTool == .label {
            if value.location.distance(to: value.startLocation) < 5.0 { typingPos = value.location }
            return
        }
        
        if currentTool == .move {
            resetState()
            return
        }

        if currentTool == .curve && currentPoints.count > 2 {
            let first = currentPoints.first!, last = currentPoints.last!
            let closed = (snapDotLocation == first) || (first.distance(to: last) < 18.0)
            pushUndoSnapshot()
            shapes.append(DrawnShape(type: .smoothCurve(points: currentPoints, isClosed: closed), style: currentStyle))
        } else if let s = currentDragStart, let e = currentDragEnd {
            let type: ShapeType
            switch currentTool {
            case .rectangle: type = .rectangle(start: s, end: e)
            case .ellipse: type = .ellipse(start: s, end: e)
            case .line: type = .line(start: s, end: e)
            case .point: type = .point(position: e)
            default: resetState(); return
            }
            pushUndoSnapshot()
            shapes.append(DrawnShape(type: type, style: currentStyle))
        }
        resetState()
    }

    private func resetState() {
        currentPoints = []
        currentDragStart = nil
        currentDragEnd = nil
        grabbedShapeID = nil
        snapDotLocation = nil
        isCurrentlySnapping = false
        lastMoveLocation = nil
        hasCapturedMoveSnapshot = false
        
        isDragging = false
        cachedSnapPoints.removeAll(keepingCapacity: true)
        cachedIntersections.removeAll(keepingCapacity: true)
    }

    private func findSnapPoint(near point: CGPoint) -> CGPoint {
        var nearestPointSnap: (point: CGPoint, distance: CGFloat)? = nil
        for candidate in cachedIntersections + cachedSnapPoints {
            let distance = point.distance(to: candidate)
            if distance <= pointSnapThreshold && (nearestPointSnap == nil || distance < nearestPointSnap!.distance) {
                nearestPointSnap = (candidate, distance)
            }
        }
        
        if let nearest = nearestPointSnap {
            if !isCurrentlySnapping { Haptic.shared.snap() }
            isCurrentlySnapping = true
            snapDotLocation = nearest.point
            return nearest.point
        }
        
        var nearestEdgeSnap: (point: CGPoint, distance: CGFloat)? = nil
        for shape in shapes {
            if let edgeSnap = shape.closestPointOnEdge(to: point) {
                let distance = point.distance(to: edgeSnap)
                if distance <= edgeSnapThreshold && (nearestEdgeSnap == nil || distance < nearestEdgeSnap!.distance) {
                    nearestEdgeSnap = (edgeSnap, distance)
                }
            }
        }
        
        if let nearest = nearestEdgeSnap {
            isCurrentlySnapping = false
            snapDotLocation = nearest.point
            return nearest.point
        }
        
        isCurrentlySnapping = false
        snapDotLocation = nil
        return point
    }
    
    private func getIntersections(from targetShapes: [DrawnShape]) -> [CGPoint] {
        var intersections: [CGPoint] = []
        let lines = targetShapes.filter { if case .line = $0.type { return true } else { return false } }
        guard lines.count >= 2 else { return [] }
        for i in 0 ..< lines.count {
            for j in (i + 1) ..< lines.count {
                if case .line(let p1, let p2) = lines[i].type, case .line(let p3, let p4) = lines[j].type {
                    if let intersect = lineIntersection(p1, p2, p3, p4) { intersections.append(intersect) }
                }
            }
        }
        return intersections
    }

    private func lineIntersection(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        let d = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
        if d == 0 { return nil }
        let t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / d
        let u = -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) / d
        if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
            return CGPoint(x: p1.x + t * (p2.x - p1.x), y: p1.y + t * (p2.y - p1.y))
        }
        return nil
    }

    private func translateShape(id: UUID, dx: CGFloat, dy: CGFloat) {
        guard let i = shapes.firstIndex(where: { $0.id == id }) else { return }
        switch shapes[i].type {
        case .ellipse(let s, let e): shapes[i].type = .ellipse(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .rectangle(let s, let e): shapes[i].type = .rectangle(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .line(let s, let e): shapes[i].type = .line(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .point(let p): shapes[i].type = .point(position: p.offset(dx: dx, dy: dy))
        case .smoothCurve(let pts, let c): shapes[i].type = .smoothCurve(points: pts.map { $0.offset(dx: dx, dy: dy) }, isClosed: c)
        case .label(let t, let p, let sc): shapes[i].type = .label(text: t, position: p.offset(dx: dx, dy: dy), scale: sc)
        }
    }
    
    func addLabel(text: String, position: CGPoint) {
        if !text.isEmpty {
            pushUndoSnapshot()
            shapes.append(DrawnShape(type: .label(text: text, position: position, scale: 1.0), style: currentStyle))
        }
    }
    
    func updateLabelScale(id: UUID, scale: CGFloat) {
        if let i = shapes.firstIndex(where: { $0.id == id }), case .label(let t, let p, _) = shapes[i].type {
            shapes[i].type = .label(text: t, position: p, scale: scale)
        }
    }
    
    func clear() {
        guard !shapes.isEmpty else { return }
        pushUndoSnapshot()
        withAnimation { shapes.removeAll() }
        Haptic.shared.success()
    }
    
    func undo() {
        guard let previous = undoStack.popLast() else { return }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
            shapes = previous
        }
        canUndo = !undoStack.isEmpty
        resetState()
        Haptic.shared.light()
    }
    
    private func pushUndoSnapshot() {
        undoStack.append(shapes)
        canUndo = true
    }
}
