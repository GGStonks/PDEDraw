import SwiftUI
import Combine

enum GridStyle: String, CaseIterable {
    case dots, grid, blank
}

class CanvasViewModel: ObservableObject {
    let pointSnapThreshold: CGFloat = 14.0
    let edgeSnapThreshold: CGFloat = 16.0
    
    @Published var shapes: [DrawnShape] = []
    
    @Published private(set) var canUndo: Bool = false
    @Published var currentTool: DrawingTool = .curve
    @Published var currentStyle: ShapeStyle = ShapeStyle()
    @Published var gridStyle: GridStyle = .dots
    
    @Published var currentPoints: [CGPoint] = []
    @Published var currentDragStart: CGPoint? = nil
    @Published var currentDragEnd: CGPoint? = nil
    
    @Published var snapDotLocation: CGPoint? = nil
    @Published var grabbedShapeIDs: Set<UUID> = []
    var isCurrentlySnapping: Bool = false
    var lastMoveLocation: CGPoint? = nil
    
    @Published var typingPos: CGPoint? = nil
    @Published var tracingImage: UIImage? = nil
    
    // Performance Cache for Drag Operations
    var cachedSnapPoints: [CGPoint] = []
    var cachedIntersections: [CGPoint] = []
    var isDragging: Bool = false
    
    var undoStack: [[DrawnShape]] = []
    var hasCapturedMoveSnapshot: Bool = false
    
    let snapPointThreshold: CGFloat = 20.0
    let curveSamplingDistance: CGFloat = 4.5
    let scribbleSamplingDistance: CGFloat = 2.5
    let moveHitTolerance: CGFloat = 30.0
    let moveBoundingPadding: CGFloat = 40.0
    let eraserHitTolerance: CGFloat = 12.0
    let eraserBoundingPadding: CGFloat = 16.0

    func translateShape(id: UUID, dx: CGFloat, dy: CGFloat) {
        guard let i = shapes.firstIndex(where: { $0.id == id }) else { return }
        switch shapes[i].type {
        case .ellipse(let s, let e): shapes[i].type = .ellipse(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .triangle(let s, let e): shapes[i].type = .triangle(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .rectangle(let s, let e): shapes[i].type = .rectangle(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .line(let s, let e): shapes[i].type = .line(start: s.offset(dx: dx, dy: dy), end: e.offset(dx: dx, dy: dy))
        case .point(let p): shapes[i].type = .point(position: p.offset(dx: dx, dy: dy))
        case .smoothCurve(let pts, let c): shapes[i].type = .smoothCurve(points: pts.map { $0.offset(dx: dx, dy: dy) }, isClosed: c)
        case .scribble(let pts): shapes[i].type = .scribble(points: pts.map { $0.offset(dx: dx, dy: dy) })
        case .label(let t, let p, let sc): shapes[i].type = .label(text: t, position: p.offset(dx: dx, dy: dy), scale: sc)
        }
    }
    
    func appendCurvePoint(_ point: CGPoint) {
        guard let last = currentPoints.last else {
            currentPoints.append(point)
            return
        }
        
        if point.distance(to: last) < curveSamplingDistance { return }
        
        if currentPoints.count >= 2 {
            let previous = currentPoints[currentPoints.count - 2]
            let projected = point.project(start: previous, end: last)
            let deviation = point.distance(to: projected)
            let pathStep = point.distance(to: last)
            if deviation < 1.2 && pathStep < 10.0 {
                currentPoints[currentPoints.count - 1] = point
                return
            }
        }
        
        currentPoints.append(point)
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
        guard !shapes.isEmpty || tracingImage != nil else { return }
        pushUndoSnapshot()
        withAnimation { 
            shapes.removeAll()
            grabbedShapeIDs.removeAll()
            tracingImage = nil
        }
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
    
    func pushUndoSnapshot() {
        undoStack.append(shapes)
        canUndo = true
    }

    func bestHitShapeIndex(at point: CGPoint, tolerance: CGFloat, boundingPadding: CGFloat) -> Int? {
        var bestIndex: Int? = nil
        var bestDistance: CGFloat = .infinity

        for index in shapes.indices {
            if let distance = shapes[index].hitDistance(to: point, tolerance: tolerance, boundingPadding: boundingPadding) {
                if distance < bestDistance - 0.1 || (abs(distance - bestDistance) <= 0.1 && (bestIndex == nil || index > bestIndex!)) {
                    bestDistance = distance
                    bestIndex = index
                }
            }
        }

        return bestIndex
    }
}
