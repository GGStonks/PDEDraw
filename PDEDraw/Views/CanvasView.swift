import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var tempText: String = ""

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
                .onTapGesture { loc in
                    if viewModel.currentTool == .label {
                        viewModel.typingPos = loc
                        tempText = ""
                    } else {
                        viewModel.typingPos = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            
            DotGrid()
            
            // RENDERING FORME (Movimento matematico puro senza offset o lag visivi)
            ForEach(viewModel.shapes) { shape in
                ShapeRenderer(shape: shape, viewModel: viewModel)
                    .opacity(viewModel.grabbedShapeID == shape.id ? 0.4 : 1.0)
            }
            
            LivePreviewRenderer(viewModel: viewModel)
            
            if let snap = viewModel.snapDotLocation {
                Circle().fill(Color.orange).frame(width: 12.0, height: 12.0)
                    .overlay(Circle().stroke(Color.white, lineWidth: 2.0))
                    .shadow(radius: 4.0).position(snap)
            }
            
            if let tp = viewModel.typingPos {
                InstantTextField(text: $tempText, onCommit: {
                    viewModel.addLabel(text: tempText, position: tp)
                    viewModel.typingPos = nil
                    tempText = ""
                })
                .frame(width: 180.0, height: 44.0)
                .padding(12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
                .position(tp)
            }
        }
        .contentShape(Rectangle())
        .gesture(DragGesture(minimumDistance: 0)
            .onChanged { viewModel.handleDrag(value: $0) }
            .onEnded { viewModel.finishDrag(value: $0) }
        )
    }
}

// MARK: - INSTANT TEXTFIELD
struct InstantTextField: UIViewRepresentable {
    @Binding var text: String
    var onCommit: () -> Void
    
    func makeUIView(context: Context) -> UITextField {
        let tf = UITextField()
        tf.placeholder = "LaTeX..."
        if let desc = UIFont.systemFont(ofSize: 24.0, weight: .bold).fontDescriptor.withDesign(.serif) {
            tf.font = UIFont(descriptor: desc, size: 24.0)
        } else {
            tf.font = .boldSystemFont(ofSize: 24.0)
        }
        tf.textAlignment = .center
        tf.returnKeyType = .done
        tf.autocorrectionType = .no
        tf.autocapitalizationType = .none
        tf.tintColor = .systemBlue
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.textChanged), for: .editingChanged)
        
        DispatchQueue.main.async { tf.becomeFirstResponder() }
        return tf
    }
    
    func updateUIView(_ uiView: UITextField, context: Context) {
        if uiView.text != text { uiView.text = text }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: InstantTextField
        init(_ parent: InstantTextField) { self.parent = parent }
        @objc func textChanged(_ textField: UITextField) { parent.text = textField.text ?? "" }
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            parent.onCommit()
            textField.resignFirstResponder()
            return true
        }
    }
}

// MARK: - SHAPE RENDERER
struct ShapeRenderer: View {
    let shape: DrawnShape
    @ObservedObject var viewModel: CanvasViewModel
    
    var body: some View {
        let path = buildPath(for: shape.type)
        let color = shape.style.color.swiftUIColor
        
        ZStack {
            if shape.style.fillType != .none {
                if shape.style.fillType == .solid { path.fill(color.opacity(0.2), style: FillStyle(eoFill: true)) }
                else if shape.style.fillType == .hole { path.fill(Color(UIColor.systemBackground), style: FillStyle(eoFill: true)) }
                else { PatternFill(type: shape.style.fillType, color: color).clipShape(path, style: FillStyle(eoFill: true)) }
            }
            
            if case .label(let t, let p, let sc) = shape.type {
                ScalableLabel(shapeID: shape.id, text: t, scale: sc, color: color, position: p, viewModel: viewModel)
            } else {
                path.stroke(color, style: shape.style.strokeStyle)
                if shape.style.hasArrow { arrowView(for: shape, color: color) }
            }
        }
    }
    
    @ViewBuilder private func arrowView(for shape: DrawnShape, color: Color) -> some View {
        switch shape.type {
        case .line(let s, let e): ArrowHead(start: s, end: e).fill(color)
        case .smoothCurve(let pts, let closed):
            if !closed && pts.count > 2 { ArrowHead(start: pts[pts.count - 2], end: pts.last!).fill(color) } else { EmptyView() }
        default: EmptyView()
        }
    }

    private func buildPath(for type: ShapeType) -> Path {
        var p = Path()
        switch type {
        case .ellipse(let s, let e):
            let w = abs(e.x - s.x)
            let h = abs(e.y - s.y)
            p.addEllipse(in: CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: w, height: h))
        case .triangle(let s, let e):
            let minX = min(s.x, e.x)
            let maxX = max(s.x, e.x)
            let minY = min(s.y, e.y)
            let maxY = max(s.y, e.y)
            p.move(to: CGPoint(x: (minX + maxX) / 2.0, y: minY))
            p.addLine(to: CGPoint(x: maxX, y: maxY))
            p.addLine(to: CGPoint(x: minX, y: maxY))
            p.closeSubpath()
        case .rectangle(let s, let e):
            let w = abs(e.x - s.x)
            let h = abs(e.y - s.y)
            p.addRect(CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: w, height: h))
        case .line(let s, let e):
            p.move(to: s)
            p.addLine(to: e)
        case .point(let pt):
            p.addEllipse(in: CGRect(x: pt.x - 4.0, y: pt.y - 4.0, width: 8.0, height: 8.0))
        case .smoothCurve(let pts, let c):
            p.addCentripetalCatmullRomSpline(points: pts, isClosed: c)
        case .scribble(let pts):
            guard let first = pts.first else { break }
            p.move(to: first)
            p.addLines(pts.dropFirst())
        case .label: break
        }
        return p
    }
}

// MARK: - PINCH-TO-ZOOM LABEL
struct ScalableLabel: View {
    let shapeID: UUID; let text: String; let scale: CGFloat; let color: Color; let position: CGPoint
    @ObservedObject var viewModel: CanvasViewModel
    @State private var zoom: CGFloat = 1.0
    
    var body: some View {
        Text("$\(text)$")
            .font(.serif(size: 24.0))
            .foregroundColor(color)
            .scaleEffect(scale * zoom)
            .position(position)
            .gesture(MagnificationGesture()
                .onChanged { zoom = $0 }
                .onEnded { v in viewModel.updateLabelScale(id: shapeID, scale: scale * v); zoom = 1.0 }
            )
    }
}

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
}

// MARK: - HELPERS
struct PatternFill: View {
    let type: FillType; let color: Color
    var body: some View {
        Canvas { context, size in
            let spacing: CGFloat = 10.0
            let pColor = color.opacity(0.4)
            let limit = size.width + size.height
            for i in stride(from: -limit, to: limit, by: spacing) {
                if type == .northEast || type == .crosshatch {
                    var p = Path()
                    p.move(to: CGPoint(x: i, y: size.height))
                    p.addLine(to: CGPoint(x: i + size.height, y: 0.0))
                    context.stroke(p, with: .color(pColor), lineWidth: 1.5)
                }
                if type == .northWest || type == .crosshatch {
                    var p = Path()
                    p.move(to: CGPoint(x: i, y: 0.0))
                    p.addLine(to: CGPoint(x: i + size.height, y: size.height))
                    context.stroke(p, with: .color(pColor), lineWidth: 1.5)
                }
            }
        }
    }
}

struct ArrowHead: Shape {
    let start, end: CGPoint
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let angle = atan2(end.y - start.y, end.x - start.x)
        let size: CGFloat = 12.0
        p.move(to: end)
        
        let a1 = angle - (Double.pi / 6.0)
        let a2 = angle + (Double.pi / 6.0)
        
        let p1x = end.x - size * cos(a1)
        let p1y = end.y - size * sin(a1)
        
        let p2x = end.x - size * cos(a2)
        let p2y = end.y - size * sin(a2)
        
        p.addLine(to: CGPoint(x: p1x, y: p1y))
        p.addLine(to: CGPoint(x: p2x, y: p2y))
        p.closeSubpath()
        return p
    }
}

struct DotGrid: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0.0, to: size.width, by: 30.0) {
                for y in stride(from: 0.0, to: size.height, by: 30.0) {
                    context.fill(Path(ellipseIn: CGRect(x: x - 0.75, y: y - 0.75, width: 1.5, height: 1.5)), with: .color(.white.opacity(0.12)))
                }
            }
        }.ignoresSafeArea()
    }
}

extension Font { static func serif(size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) } }

struct LivePreviewRenderer: View {
    @ObservedObject var viewModel: CanvasViewModel
    var body: some View {
        let color = viewModel.currentStyle.color.swiftUIColor
        let stroke = StrokeStyle(lineWidth: 2.5, dash: [5.0])
        Group {
            if let s = viewModel.currentDragStart, let e = viewModel.currentDragEnd {
                if viewModel.currentTool == .point {
                    Path { p in p.addEllipse(in: CGRect(x: e.x - 4.0, y: e.y - 4.0, width: 8.0, height: 8.0)) }
                        .fill(color)
                } else {
                    Path { p in
                        let w = abs(e.x - s.x)
                        let h = abs(e.y - s.y)
                        
                        if viewModel.currentTool == .rectangle {
                            p.addRect(CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: w, height: h))
                        }
                        if viewModel.currentTool == .triangle {
                            let minX = min(s.x, e.x)
                            let maxX = max(s.x, e.x)
                            let minY = min(s.y, e.y)
                            let maxY = max(s.y, e.y)
                            p.move(to: CGPoint(x: (minX + maxX) / 2.0, y: minY))
                            p.addLine(to: CGPoint(x: maxX, y: maxY))
                            p.addLine(to: CGPoint(x: minX, y: maxY))
                            p.closeSubpath()
                        }
                        if viewModel.currentTool == .ellipse {
                            p.addEllipse(in: CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: w, height: h))
                        }
                        if viewModel.currentTool == .line {
                            p.move(to: s); p.addLine(to: e)
                        }
                    }.stroke(color.opacity(0.5), style: stroke)
                }
            }
            if !viewModel.currentPoints.isEmpty {
                if viewModel.currentTool == .curve {
                    let isClosingPreview = viewModel.snapDotLocation != nil
                    Path { p in p.addCentripetalCatmullRomSpline(points: viewModel.currentPoints, isClosed: isClosingPreview) }
                        .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2.5))
                } else if viewModel.currentTool == .scribble {
                    Path { p in
                        if let first = viewModel.currentPoints.first {
                            p.move(to: first)
                            p.addLines(viewModel.currentPoints.dropFirst())
                        }
                    }
                    .stroke(color.opacity(0.5), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                }
            }
        }
    }
}
