import SwiftUI
import PencilKit

extension ShapeColor {
    var rawUIColor: UIColor {
        switch self {
        case .graphite: return UIColor.white // Explicitly white for dark canvas
        case .rose: return UIColor.systemPink
        case .ocean: return UIColor.systemBlue
        case .teal: return UIColor.systemTeal
        case .amber: return UIColor.systemOrange
        }
    }
}

struct PencilKitCanvas: UIViewRepresentable {
    @ObservedObject var viewModel: CanvasViewModel
    var isPencilKitActive: Bool
    
    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.isOpaque = false
        canvas.backgroundColor = .clear
        canvas.overrideUserInterfaceStyle = .dark // FORCE Apple Toolbar & Ink to recognize Dark Mode natively
        canvas.delegate = context.coordinator
        
        // Unleash the native Apple ToolPicker
        let toolPicker = PKToolPicker()
        toolPicker.addObserver(canvas)
        context.coordinator.toolPicker = toolPicker
        
        canvas.tool = PKInkingTool(.pen, color: .white, width: 3.0)
        
        return canvas
    }
    
    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        uiView.isUserInteractionEnabled = isPencilKitActive
        
        if isPencilKitActive {
            uiView.becomeFirstResponder()
            context.coordinator.toolPicker?.setVisible(true, forFirstResponder: uiView)
        } else {
            uiView.resignFirstResponder()
            context.coordinator.toolPicker?.setVisible(false, forFirstResponder: uiView)
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, PKCanvasViewDelegate {
        var parent: PencilKitCanvas
        var toolPicker: PKToolPicker?
        
        init(_ parent: PencilKitCanvas) { self.parent = parent }
        
        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            let strokes = canvasView.drawing.strokes
            guard !strokes.isEmpty else { return }
            
            var newShapes: [DrawnShape] = []
            
            for stroke in strokes {
                let points = stroke.path.interpolatedPoints(by: .distance(3.5)).map { $0.location }
                guard points.count > 2 else { continue }
                
                var matchedColor: ShapeColor = parent.viewModel.currentStyle.color
                if let ink = stroke.ink as? PKInk {
                    let uic = ink.color
                    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, w: CGFloat = 0
                    if uic.getRed(&r, green: &g, blue: &b, alpha: nil) {
                        if r > 0.8 && g < 0.5 && b < 0.5 { matchedColor = .rose }
                        else if b > 0.8 && r < 0.5 && g < 0.7 { matchedColor = .ocean }
                        else if g > 0.7 && b > 0.7 && r < 0.6 { matchedColor = .teal }
                        else if r > 0.8 && g > 0.5 && b < 0.4 { matchedColor = .amber }
                        else { matchedColor = .graphite }
                    } else if uic.getWhite(&w, alpha: nil) {
                        matchedColor = .graphite
                    }
                }
                
                var newStyle = parent.viewModel.currentStyle
                newStyle.color = matchedColor
                
                let shape = DrawnShape(type: .scribble(points: points), style: newStyle)
                newShapes.append(shape)
            }
            
            if !newShapes.isEmpty {
                DispatchQueue.main.async {
                    self.parent.viewModel.pushUndoSnapshot()
                    self.parent.viewModel.shapes.append(contentsOf: newShapes)
                    canvasView.drawing = PKDrawing()
                }
            }
        }
    }
}
