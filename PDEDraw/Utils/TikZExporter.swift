import Foundation
import CoreGraphics

struct TikZExporter {
    static let scale: CGFloat = 50.0
    
    static func generateCode(from shapes: [DrawnShape], canvasSize: CGSize) -> String {
        var code = "% Add \\usetikzlibrary{patterns} to preamble\n\\begin{tikzpicture}[scale=1.0, even odd rule]\n"
        for shape in shapes {
            let style = shape.style
            var opts = [String]()
            let cName = style.color == .graphite ? "gray" : style.color.rawValue
            
            if style.color != .graphite { opts.append(cName) }
            if style.lineStyle == .dashed { opts.append("dashed") }
            if style.lineStyle == .dotted { opts.append("dotted") }
            if style.hasArrow { opts.append("->") }
            
            switch style.fillType {
            case .none: break
            case .solid: opts.append("fill=\(cName)!20")
            case .northEast: opts.append("pattern=north east lines, pattern color=\(cName)!60")
            case .northWest: opts.append("pattern=north west lines, pattern color=\(cName)!60")
            case .crosshatch: opts.append("pattern=crosshatch, pattern color=\(cName)!60")
            case .hole: opts.append("fill=white")
            }
            
            let optStr = opts.isEmpty ? "" : "[\(opts.joined(separator: ", "))]"
            
            switch shape.type {
            case .label(let text, let pos, let lScale):
                code += String(format: "    \\node[scale=%.2f] at (%.2f, %.2f) {$%@$};\n", lScale, pos.x / scale, (canvasSize.height - pos.y) / scale, text)
            case .point(let p):
                code += String(format: "    \\fill[\(cName)] (%.2f, %.2f) circle (3pt);\n", p.x / scale, (canvasSize.height - p.y) / scale)
            default:
                code += "    \\draw\(optStr) \(getPathString(for: shape, canvasHeight: canvasSize.height));\n"
            }
        }
        code += "\\end{tikzpicture}"
        return code
    }
    
    private static func getPathString(for shape: DrawnShape, canvasHeight: CGFloat) -> String {
        switch shape.type {
        case .ellipse(let s, let e):
            let cx = (s.x + e.x) / 2.0 / scale, cy = (canvasHeight - (s.y + e.y) / 2.0) / scale
            return String(format: "(%.2f, %.2f) ellipse (%.2f and %.2f)", cx, cy, abs(e.x-s.x)/2.0/scale, abs(e.y-s.y)/2.0/scale)
        case .rectangle(let s, let e):
            return String(format: "(%.2f, %.2f) rectangle (%.2f, %.2f)", s.x/scale, (canvasHeight-s.y)/scale, e.x/scale, (canvasHeight-e.y)/scale)
        case .line(let s, let e):
            return String(format: "(%.2f, %.2f) -- (%.2f, %.2f)", s.x/scale, (canvasHeight-s.y)/scale, e.x/scale, (canvasHeight-e.y)/scale)
        case .smoothCurve(let pts, let closed):
            let coords = pts.map { String(format: "(%.2f, %.2f)", $0.x/scale, (canvasHeight-$0.y)/scale) }.joined(separator: " ")
            return "\(closed ? "plot [smooth cycle]" : "plot [smooth]") coordinates {\(coords)}"
        default: return ""
        }
    }
}
