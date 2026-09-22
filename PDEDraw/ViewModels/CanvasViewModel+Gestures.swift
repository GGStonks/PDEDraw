import SwiftUI

extension CanvasViewModel {
    func ensureCachePrepared() {
        if !isDragging {
            isDragging = true
            let unselectedShapes = shapes.filter { !grabbedShapeIDs.contains($0.id) }
            cachedIntersections = getIntersections(from: unselectedShapes)
            cachedSnapPoints = unselectedShapes.flatMap { $0.snapPoints }
        }
    }

    func handleDrag(currentLoc: CGPoint, startLoc: CGPoint) {
        if currentTool == .label { return }
        
        let rawLoc = currentLoc
        let usesSnapEngine: Bool = currentTool != .scribble && currentTool != .lasso
        if usesSnapEngine { ensureCachePrepared() }
        let snappedLoc = usesSnapEngine ? findSnapPoint(near: rawLoc) : rawLoc
        
        switch currentTool {
        case .move:
            let hitIndex = bestHitShapeIndex(at: startLoc, tolerance: moveHitTolerance, boundingPadding: moveBoundingPadding)
            
            if lastMoveLocation == nil {
                var shouldSelectHit = false
                if grabbedShapeIDs.isEmpty {
                    shouldSelectHit = true
                } else if let hit = hitIndex {
                    let hitID = shapes[hit].id
                    if !grabbedShapeIDs.contains(hitID) {
                        shouldSelectHit = true
                    }
                } else {
                    grabbedShapeIDs = []
                }
                
                if shouldSelectHit {
                    if let hit = hitIndex {
                        grabbedShapeIDs = [shapes[hit].id]
                    } else {
                        grabbedShapeIDs = []
                    }
                }
                
                if !grabbedShapeIDs.isEmpty {
                    if !hasCapturedMoveSnapshot {
                        pushUndoSnapshot()
                        hasCapturedMoveSnapshot = true
                    }
                    lastMoveLocation = startLoc
                    Haptic.shared.light()
                }
            } else if !grabbedShapeIDs.isEmpty, let last = lastMoveLocation {
                let dx = rawLoc.x - last.x
                let dy = rawLoc.y - last.y
                
                for id in grabbedShapeIDs {
                    translateShape(id: id, dx: dx, dy: dy)
                }
                lastMoveLocation = rawLoc
            }
            
        case .curve:
            if currentPoints.isEmpty { currentPoints.append(startLoc) }
            
            if let last = currentPoints.last, rawLoc.distance(to: last) > curveSamplingDistance {
                let first = currentPoints.first!
                if rawLoc.distance(to: first) < 18.0 && currentPoints.count > 5 {
                    if snapDotLocation != first { Haptic.shared.snap() }
                    snapDotLocation = first
                } else {
                    snapDotLocation = nil
                    appendCurvePoint(snappedLoc)
                }
            }

        case .scribble, .lasso:
            if currentPoints.isEmpty {
                currentPoints.append(startLoc)
                currentPoints.append(rawLoc)
            } else if let last = currentPoints.last, rawLoc.distance(to: last) > 2.0 { // Small increase in threshold eliminates micro-tremors from 240Hz iPad digitizer!
                currentPoints.append(rawLoc)
            }
            
        case .line:
            if currentDragStart == nil { currentDragStart = findSnapPoint(near: startLoc) }
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
            if currentDragStart == nil { currentDragStart = findSnapPoint(near: startLoc) }
            currentDragEnd = snappedLoc
            
        case .ellipse:
            if currentDragStart == nil { currentDragStart = findSnapPoint(near: startLoc) }
            if let center = currentDragStart {
                let targetLoc = snappedLoc
                let dx = abs(targetLoc.x - center.x)
                let dy = abs(targetLoc.y - center.y)
                let isCircle = abs(dx - dy) < 30.0
                
                let s = isCircle ? max(dx, dy) : 0
                let rx = isCircle ? s : dx
                let ry = isCircle ? s : dy
                
                currentDragEnd = CGPoint(x: center.x + rx, y: center.y + ry)
            }
            
        case .eraser:
            if let hitIndex = bestHitShapeIndex(at: rawLoc, tolerance: eraserHitTolerance, boundingPadding: eraserBoundingPadding) {
                pushUndoSnapshot()
                
                let hitID = shapes[hitIndex].id
                
                if grabbedShapeIDs.contains(hitID) {
                    shapes.removeAll { grabbedShapeIDs.contains($0.id) }
                    grabbedShapeIDs.removeAll()
                } else {
                    shapes.remove(at: hitIndex)
                    grabbedShapeIDs.remove(hitID)
                }
                
                Haptic.shared.light()
                isDragging = false
                ensureCachePrepared()
            }
            
        case .label: break
        }
    }

    func finishDrag(currentLoc: CGPoint, startLoc: CGPoint) {
        if currentTool == .label {
            if currentLoc.distance(to: startLoc) < 5.0 { typingPos = currentLoc }
            return
        }
        
        if currentTool == .move {
            resetState(preserveSelection: false)
            return
        }

        var wasLasso = false

        if currentTool == .curve && currentPoints.count > 2 {
            let first = currentPoints.first!, last = currentPoints.last!
            let closed = (snapDotLocation == first) || (first.distance(to: last) < 18.0)
            pushUndoSnapshot()
            shapes.append(DrawnShape(type: .smoothCurve(points: currentPoints, isClosed: closed), style: currentStyle))
        } else if currentTool == .scribble && !currentPoints.isEmpty {
            pushUndoSnapshot()
            shapes.append(DrawnShape(type: .scribble(points: currentPoints), style: currentStyle))
        } else if currentTool == .lasso && currentPoints.count > 2 {
            wasLasso = true
            let lassoPath = Path { p in
                if let first = currentPoints.first {
                    p.move(to: first)
                    // Lasso still uses Catmull for tight enclosure math!
                    p.addCentripetalCatmullRomSpline(points: currentPoints, isClosed: true)
                }
            }
            var selected: Set<UUID> = []
            for shape in shapes {
                let rect = shape.boundingBox
                let center = CGPoint(x: rect.midX, y: rect.midY)
                if lassoPath.contains(center) {
                    selected.insert(shape.id)
                }
            }
            grabbedShapeIDs = selected
            if !selected.isEmpty {
                Haptic.shared.success()
            }
        } else if let s = currentDragStart, let e = currentDragEnd {
            let type: ShapeType
            switch currentTool {
            case .rectangle: type = .rectangle(start: s, end: e)
            case .ellipse: type = .ellipse(start: CGPoint(x: s.x - (e.x - s.x), y: s.y - (e.y - s.y)), end: e)
            case .line: type = .line(start: s, end: e)
            case .point: type = .point(position: e)
            default: resetState(); return
            }
            pushUndoSnapshot()
            shapes.append(DrawnShape(type: type, style: currentStyle))
        }
        
        resetState(preserveSelection: wasLasso)
    }

    func clearSelection() {
        grabbedShapeIDs = []
    }

    func resetState(preserveSelection: Bool = false) {
        currentPoints = []
        currentDragStart = nil
        currentDragEnd = nil
        if !preserveSelection {
            grabbedShapeIDs = []
        }
        snapDotLocation = nil
        isCurrentlySnapping = false
        lastMoveLocation = nil
        hasCapturedMoveSnapshot = false
        
        isDragging = false
        cachedSnapPoints.removeAll(keepingCapacity: true)
        cachedIntersections.removeAll(keepingCapacity: true)
    }
}
