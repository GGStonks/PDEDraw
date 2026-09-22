import SwiftUI

struct CanvasView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @State private var tempText: String = ""

    var body: some View {
        ScrollView([.vertical, .horizontal], showsIndicators: true) {
            ZStack {
                Color.black.opacity(0.001) // Invisible but hittable background
                    .onTapGesture { loc in
                        if viewModel.currentTool == .label {
                            viewModel.typingPos = loc
                            tempText = ""
                        } else {
                            viewModel.typingPos = nil
                            if viewModel.currentTool == .move || viewModel.currentTool == .lasso { viewModel.clearSelection() }
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                
                switch viewModel.gridStyle {
                case .dots: DotGrid()
                case .grid: LineGrid()
                case .blank: EmptyView()
                }
                
                // Tracing Image Layer
                if let tracingImage = viewModel.tracingImage {
                    Image(uiImage: tracingImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 2000, maxHeight: 2000)
                        .opacity(0.4)
                        .allowsHitTesting(false)
                }
                
                // RENDERING FORME (Custom Math Shapes)
                Group {
                    ForEach(viewModel.shapes) { shape in
                        ShapeRenderer(shape: shape, viewModel: viewModel)
                            .opacity(viewModel.grabbedShapeIDs.contains(shape.id) ? 0.4 : 1.0)
                    }
                    
                    LivePreviewRenderer(viewModel: viewModel)
                }
                .compositingGroup() // Enables physical .destinationOut Hole punching!
                
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
                    .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .position(tp)
                }
                
                // Apple Pencil Native Math Tracker (Active for ALL tools)
                PencilTouchTracker(
                    onChanged: { loc, start in viewModel.handleDrag(currentLoc: loc, startLoc: start) },
                    onEnded: { loc, start in viewModel.finishDrag(currentLoc: loc, startLoc: start) }
                )
            }
            .frame(width: 4000, height: 4000) // Expansive canvas area
            .contentShape(Rectangle())
        }
        .background(Color.black.ignoresSafeArea())
        .ignoresSafeArea()
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
                if shape.style.fillType == .solid { 
                    path.fill(color.opacity(0.2), style: FillStyle(eoFill: true)) 
                } else if shape.style.fillType == .hole { 
                    path.fill(Color.black, style: FillStyle(eoFill: true))
                        .blendMode(.destinationOut)
                } else { 
                    PatternFill(type: shape.style.fillType, color: color).clipShape(path, style: FillStyle(eoFill: true)) 
                }
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
            if pts.count <= 2 && pts.last!.distance(to: first) < 5.0 {
                p.addEllipse(in: CGRect(x: first.x - 2.5, y: first.y - 2.5, width: 5.0, height: 5.0))
            } else {
                // EXCLUSIVE UPGRADE: Use the new silky quad curve engine for raw freehand rendering!
                p.addSilkyQuadCurves(points: pts)
            }
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

// MARK: - LIVE PREVIEW
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
                        if viewModel.currentTool == .rectangle {
                            let w = abs(e.x - s.x)
                            let h = abs(e.y - s.y)
                            p.addRect(CGRect(x: min(s.x, e.x), y: min(s.y, e.y), width: w, height: h))
                        }
                        if viewModel.currentTool == .ellipse {
                            let rx = abs(e.x - s.x)
                            let ry = abs(e.y - s.y)
                            p.addEllipse(in: CGRect(x: s.x - rx, y: s.y - ry, width: rx * 2, height: ry * 2))
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
                } else if viewModel.currentTool == .scribble { // Live Scribble Tracker
                    Path { p in
                        let pts = viewModel.currentPoints
                        if let first = pts.first {
                            if pts.count <= 2 && pts.last!.distance(to: first) < 5.0 {
                                p.addEllipse(in: CGRect(x: first.x - 2.5, y: first.y - 2.5, width: 5.0, height: 5.0))
                            } else {
                                p.addSilkyQuadCurves(points: pts)
                            }
                        }
                    }
                    .stroke(color.opacity(0.9), style: StrokeStyle(lineWidth: 2.7, lineCap: .round, lineJoin: .round))
                } else if viewModel.currentTool == .lasso {
                    Path { p in
                        if let first = viewModel.currentPoints.first {
                            p.move(to: first)
                            p.addCentripetalCatmullRomSpline(points: viewModel.currentPoints, isClosed: true)
                        }
                    }
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.0, lineCap: .round, lineJoin: .round, dash: [6.0, 6.0]))
                    .background(
                        Path { p in
                            if let first = viewModel.currentPoints.first {
                                p.move(to: first)
                                p.addCentripetalCatmullRomSpline(points: viewModel.currentPoints, isClosed: true)
                            }
                        }
                        .fill(Color.blue.opacity(0.1))
                    )
                }
            }
        }
    }
}
