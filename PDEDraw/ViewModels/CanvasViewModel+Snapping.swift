import SwiftUI

extension CanvasViewModel {
    func findSnapPoint(near point: CGPoint) -> CGPoint {
        var bestCandidate: CGPoint? = nil
        var bestScore: CGFloat = .infinity
        
        for intersect in cachedIntersections {
            let distance = point.distance(to: intersect)
            if distance < snapPointThreshold && distance < bestScore {
                bestCandidate = intersect
                bestScore = distance
            }
        }
        
        for snapPoint in cachedSnapPoints {
            let distance = point.distance(to: snapPoint)
            let weightedScore = distance - 0.8
            if distance < snapPointThreshold && weightedScore < bestScore {
                bestCandidate = snapPoint
                bestScore = weightedScore
            }
        }
        
        let unselectedShapes = isDragging ? shapes.filter { !grabbedShapeIDs.contains($0.id) } : shapes
        for shape in unselectedShapes {
            if let edgeSnap = shape.closestPointOnEdge(to: point) {
                let distance = point.distance(to: edgeSnap)
                if distance < edgeSnapThreshold {
                    let weightedScore = distance + 0.5
                    if weightedScore < bestScore {
                        bestCandidate = edgeSnap
                        bestScore = weightedScore
                    }
                }
            }
        }
        
        if let bestCandidate {
            if !isCurrentlySnapping { Haptic.shared.snap() }
            isCurrentlySnapping = true
            snapDotLocation = bestCandidate
            return bestCandidate
        }
        
        isCurrentlySnapping = false
        snapDotLocation = nil
        return point
    }
    
    func getIntersections(from targetShapes: [DrawnShape]) -> [CGPoint] {
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

    func lineIntersection(_ p1: CGPoint, _ p2: CGPoint, _ p3: CGPoint, _ p4: CGPoint) -> CGPoint? {
        let d = (p1.x - p2.x) * (p3.y - p4.y) - (p1.y - p2.y) * (p3.x - p4.x)
        if d == 0 { return nil }
        let t = ((p1.x - p3.x) * (p3.y - p4.y) - (p1.y - p3.y) * (p3.x - p4.x)) / d
        let u = -((p1.x - p2.x) * (p1.y - p3.y) - (p1.y - p2.y) * (p1.x - p3.x)) / d
        if t >= 0 && t <= 1 && u >= 0 && u <= 1 {
            return CGPoint(x: p1.x + t * (p2.x - p1.x), y: p1.y + t * (p2.y - p1.y))
        }
        return nil
    }
}
