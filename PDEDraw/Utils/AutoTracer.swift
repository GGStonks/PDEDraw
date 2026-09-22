import Foundation
import CoreImage
import Vision
import CoreGraphics
import UIKit

class AutoTracer {
    static func trace(image: UIImage, targetCenter: CGPoint) -> [[CGPoint]] {
        guard let cgImage = image.cgImage else { return [] }
        let request = VNDetectContoursRequest()
        request.contrastAdjustment = 1.6
        request.maximumImageDimension = 1024
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try requestHandler.perform([request])
            guard let observation = request.results?.first as? VNContoursObservation else { return [] }
            
            var allPaths: [[CGPoint]] = []
            let width = CGFloat(cgImage.width)
            let height = CGFloat(cgImage.height)
            
            var minX: CGFloat = .infinity
            var minY: CGFloat = .infinity
            var maxX: CGFloat = -.infinity
            var maxY: CGFloat = -.infinity
            
            // Extract and scale points
            for i in 0..<observation.contourCount {
                let contour = try observation.contour(at: i)
                let points = contour.normalizedPoints.map { p in
                    // Vision origin is bottom-left, SwiftUI is top-left
                    let pt = CGPoint(x: CGFloat(p.x) * width, y: CGFloat(1.0 - p.y) * height)
                    if pt.x < minX { minX = pt.x }
                    if pt.y < minY { minY = pt.y }
                    if pt.x > maxX { maxX = pt.x }
                    if pt.y > maxY { maxY = pt.y }
                    return pt
                }
                
                // Downsample to make them smooth curves
                if points.count > 10 {
                    var sampled: [CGPoint] = []
                    let strideCount = max(1, points.count / 30) // sample up to 30 points per contour for smoothCatmull
                    for idx in stride(from: 0, to: points.count, by: strideCount) {
                        sampled.append(points[idx])
                    }
                    if !sampled.isEmpty {
                        allPaths.append(sampled)
                    }
                } else if points.count > 2 {
                    allPaths.append(points)
                }
            }
            
            let rectMidX = (minX + maxX) / 2.0
            let rectMidY = (minY + maxY) / 2.0
            let dx = targetCenter.x - rectMidX
            let dy = targetCenter.y - rectMidY
            
            // Translate to target center
            for i in 0..<allPaths.count {
                for j in 0..<allPaths[i].count {
                    allPaths[i][j].x += dx
                    allPaths[i][j].y += dy
                }
            }
            
            return allPaths
            
        } catch {
            print(error)
            return []
        }
    }
}
