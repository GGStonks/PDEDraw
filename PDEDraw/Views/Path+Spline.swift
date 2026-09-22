import SwiftUI

// MARK: - THE MASTER SPLINE ENGINE
extension Path {
    mutating func addCentripetalCatmullRomSpline(points: [CGPoint], isClosed: Bool) {
        let n = points.count
        guard n > 1 else { return }
        if n == 2 { move(to: points[0]); addLine(to: points[1]); return }
        
        move(to: points[0])
        let alpha: CGFloat = 0.5
        
        for i in 0 ..< (isClosed ? n : n - 1) {
            let p1 = points[i % n]
            let p2 = points[(i + 1) % n]
            
            let p0 = isClosed ? points[(i - 1 + n) % n] : (i == 0 ? CGPoint(x: 2.0 * p1.x - p2.x, y: 2.0 * p1.y - p2.y) : points[i - 1])
            let p3 = isClosed ? points[(i + 2) % n] : (i >= n - 2 ? CGPoint(x: 2.0 * p2.x - p1.x, y: 2.0 * p2.y - p1.y) : points[i + 2])
            
            let dx1 = p1.x - p0.x
            let dy1 = p1.y - p0.y
            let dx2 = p2.x - p1.x
            let dy2 = p2.y - p1.y
            let dx3 = p3.x - p2.x
            let dy3 = p3.y - p2.y
            
            let d1 = max(1e-4, sqrt(dx1 * dx1 + dy1 * dy1))
            let d2 = max(1e-4, sqrt(dx2 * dx2 + dy2 * dy2))
            let d3 = max(1e-4, sqrt(dx3 * dx3 + dy3 * dy3))
            
            let t1 = pow(d1, alpha)
            let t2 = pow(d2, alpha)
            let t3 = pow(d3, alpha)
            
            let t12 = t1 + t2
            let t23 = t2 + t3
            
            let m1x = (dx1 / t1) - ((p2.x - p0.x) / t12)
            let m1y = (dy1 / t1) - ((p2.y - p0.y) / t12)
            
            let m2x = (dx3 / t3) - ((p3.x - p1.x) / t23)
            let m2y = (dy3 / t3) - ((p3.y - p1.y) / t23)
            
            let cp1x = p1.x + (dx2 + t2 * m1x) / 3.0
            let cp1y = p1.y + (dy2 + t2 * m1y) / 3.0
            let cp2x = p2.x - (dx2 + t2 * m2x) / 3.0
            let cp2y = p2.y - (dy2 + t2 * m2y) / 3.0
            
            addCurve(to: p2, control1: CGPoint(x: cp1x, y: cp1y), control2: CGPoint(x: cp2x, y: cp2y))
        }
        if isClosed { closeSubpath() }
    }
    
    // Smooth quadratic curve algorithm that intentionally cuts corners of hardware jitter to produce beautiful silky trails for freeform handwriting
    mutating func addSilkyQuadCurves(points: [CGPoint]) {
        guard points.count > 1 else { return }
        move(to: points[0])
        
        if points.count == 2 {
            addLine(to: points[1])
            return
        }
        
        var previousMid = points[0]
        for i in 1..<(points.count - 1) {
            let current = points[i]
            let next = points[i+1]
            let mid = CGPoint(x: (current.x + next.x) / 2.0, y: (current.y + next.y) / 2.0)
            
            // Draw a quad curve to the midpoint, using the current true physical point exactly as the control handle
            // This mathematically absorbs hand tremors!
            addQuadCurve(to: mid, control: current)
            previousMid = mid
        }
        
        // Connect the final trailing tip
        if points.count > 2 {
            addLine(to: points.last!)
        }
    }
}
