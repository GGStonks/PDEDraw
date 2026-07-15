import SwiftUI

struct MainView: View {
    @StateObject var viewModel = CanvasViewModel()
    private let toolbarTools: [DrawingTool] = [.move, .curve, .scribble, .triangle, .rectangle, .ellipse, .line, .point, .label, .eraser]
    @State private var showInspector = false
    @State private var showPreview = false
    @State private var showToast = false
    @State private var dockOffset: CGSize = .zero
    @State private var dockDragStart: CGSize = .zero
    @State private var isDraggingDock = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                LinearGradient(
                    colors: [Color.black, Color(red: 0.06, green: 0.07, blue: 0.11)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                Circle()
                    .fill(LinearGradient(colors: [Color.blue.opacity(0.28), Color.clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 360, height: 360)
                    .blur(radius: 24)
                    .offset(x: -120, y: -260)
                    .allowsHitTesting(false)
                
                Circle()
                    .fill(LinearGradient(colors: [Color.purple.opacity(0.24), Color.clear], startPoint: .top, endPoint: .bottom))
                    .frame(width: 320, height: 320)
                    .blur(radius: 26)
                    .offset(x: 160, y: 320)
                    .allowsHitTesting(false)
                
                // 1. The Canvas
                CanvasView(viewModel: viewModel)
                
                // 2. Premium Toast Notification (AirPods Style)
                if showToast {
                    VStack {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .green)
                                .font(.title2)
                            Text("TikZ Code Copied")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundColor(.primary)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .liquidGlass(cornerRadius: 24)
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                        
                        Spacer()
                    }
                    .padding(.top, geo.safeAreaInsets.top + 16)
                    .zIndex(3)
                }
                
                // 3. Top Action Bar & Bottom Dock
                VStack {
                    HStack {
                        // Clear Canvas Button
                        Button(action: { viewModel.clear() }) {
                            Image(systemName: "trash")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.red.opacity(0.95))
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                        }
                        
                        Button(action: { viewModel.undo() }) {
                            Image(systemName: "arrow.uturn.backward")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.35))
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                        }
                        .disabled(!viewModel.canUndo)
                        
                        Spacer()
                        
                        // Preview Button
                        Button(action: { showPreview = true; Haptic.shared.light() }) {
                            Image(systemName: "eye")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                        }
                        
                        // Copy TikZ Button (Premium Pill)
                        Button(action: {
                            UIPasteboard.general.string = TikZExporter.generateCode(from: viewModel.shapes, canvasSize: geo.size)
                            Haptic.shared.success()
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { showToast = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                                withAnimation(.easeOut(duration: 0.3)) { showToast = false }
                            }
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "doc.on.clipboard.fill")
                                Text("TikZ")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .padding(.horizontal, 16)
                            .frame(height: 44)
                            .background(
                                LinearGradient(colors: [Color(red: 0.18, green: 0.39, blue: 0.94), Color(red: 0.35, green: 0.25, blue: 0.96)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 0.5))
                            .shadow(color: Color(red: 0.18, green: 0.39, blue: 0.94).opacity(0.35), radius: 14, y: 8)
                        }
                    }.padding(.horizontal, 20).padding(.top, 10)
                    
                    Spacer()
                    
                    // 4. The "visionOS" Floating Dock
                    HStack(spacing: 8) {
                        ForEach(toolbarTools, id: \.self) { t in
                            let isActive = viewModel.currentTool == t
                            Button(action: {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.72, blendDuration: 0.05)) { viewModel.currentTool = t }
                                Haptic.shared.light()
                            }) {
                                Image(systemName: icon(t, isActive: isActive))
                                    .font(.system(size: 18, weight: isActive ? .bold : .medium))
                                    .foregroundColor(isActive ? .blue : .primary.opacity(0.7))
                                    .frame(width: 44, height: 44)
                                    .background(isActive ? Color(UIColor.systemBackground).opacity(0.8) : Color.clear)
                                    .clipShape(Circle())
                                    .shadow(color: isActive ? .black.opacity(0.1) : .clear, radius: 4, y: 2)
                                    .scaleEffect(isActive ? 1.1 : 1.0) // Pops out when selected
                            }
                        }
                        
                        Divider().frame(height: 24).padding(.horizontal, 4)
                        
                        // Inspector Toggle
                        Button(action: {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showInspector.toggle() }
                            Haptic.shared.light()
                        }) {
                            Image(systemName: "slider.horizontal.3")
                                .font(.system(size: 18, weight: showInspector ? .bold : .medium))
                                .foregroundColor(showInspector ? .white : .primary.opacity(0.7))
                                .frame(width: 44, height: 44)
                                .background(showInspector ? Color.blue : Color.clear)
                                .clipShape(Circle())
                                .shadow(color: showInspector ? .blue.opacity(0.4) : .clear, radius: 8, y: 4)
                        }
                    }
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(Color.white.opacity(0.12), lineWidth: 0.5)) // Glass specular highlight
                    .shadow(color: .black.opacity(0.35), radius: 28, y: 15)
                    .scaleEffect(isDraggingDock ? 1.03 : 1.0)
                    .offset(dockOffset)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { value in
                                if !isDraggingDock {
                                    dockDragStart = dockOffset
                                    isDraggingDock = true
                                    Haptic.shared.light()
                                }
                                let proposed = CGSize(
                                    width: dockDragStart.width + value.translation.width,
                                    height: dockDragStart.height + value.translation.height
                                )
                                dockOffset = clampedDockOffset(proposed, in: geo.size)
                            }
                            .onEnded { value in
                                let momentumX = value.predictedEndTranslation.width - value.translation.width
                                let momentumY = value.predictedEndTranslation.height - value.translation.height
                                let projected = CGSize(
                                    width: dockOffset.width + momentumX * 0.18,
                                    height: dockOffset.height + momentumY * 0.18
                                )
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.78, blendDuration: 0.15)) {
                                    dockOffset = clampedDockOffset(projected, in: geo.size)
                                    isDraggingDock = false
                                }
                            }
                    )
                    .overlay(
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(isDraggingDock ? 0.22 : 0.12), Color.white.opacity(0.02)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .padding(1.5)
                            .blendMode(.screen)
                    )
                    .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8), value: isDraggingDock)
                }
                
                // 5. The Pro Inspector Panel
                if showInspector {
                    InspectorView(style: $viewModel.currentStyle)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .move(edge: .trailing).combined(with: .opacity).combined(with: .scale(scale: 0.95))
                        ))
                        .zIndex(2)
                        // Dynamic positioning based on screen size
                        .position(x: geo.size.width - 170.0, y: geo.size.height - 280.0)
                }
            }
            .sheet(isPresented: $showPreview) { TikZPreviewView(tikzCode: TikZExporter.generateCode(from: viewModel.shapes, canvasSize: geo.size)) }
            .preferredColorScheme(.dark)
        }
    }
    
    // Uses filled icons for active states, outlined for inactive
    func icon(_ t: DrawingTool, isActive: Bool) -> String {
        switch t {
        case .move: return isActive ? "hand.point.up.left.fill" : "hand.point.up.left"
        case .curve: return "scribble.variable"
        case .scribble: return isActive ? "signature" : "signature"
        case .triangle: return isActive ? "triangle.fill" : "triangle"
        case .rectangle: return isActive ? "rectangle.fill" : "rectangle"
        case .ellipse: return isActive ? "circle.fill" : "circle"
        case .line: return "line.diagonal"
        case .point: return "smallcircle.filled.circle"
        case .label: return "textformat"
        case .eraser: return isActive ? "eraser.fill" : "eraser"
        }
    }
    
    private func clampedDockOffset(_ offset: CGSize, in size: CGSize) -> CGSize {
        let dockWidthEstimate = CGFloat(toolbarTools.count) * 52.0 + 90.0
        let maxHorizontal = max(0.0, (size.width - dockWidthEstimate) / 2.0)
        let minVertical = -(size.height * 0.55)
        let maxVertical = 0.0
        let x = min(max(offset.width, -maxHorizontal), maxHorizontal)
        let y = min(max(offset.height, minVertical), maxVertical)
        return CGSize(width: x, height: y)
    }
}

// MARK: - Premium Inspector View
struct InspectorView: View {
    @Binding var style: ShapeStyle
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            
            // Header
            HStack {
                Image(systemName: "paintbrush.pointed.fill")
                    .foregroundColor(.blue)
                Text("Style & Format")
                    .font(.system(.headline, design: .rounded))
            }
            .padding(.bottom, -4)
            
            // Color Swatches
            HStack(spacing: 12) {
                ForEach(ShapeColor.allCases, id: \.self) { c in
                    Circle()
                        .fill(c.swiftUIColor)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(Color(UIColor.systemBackground), lineWidth: style.color == c ? 3.0 : 0.0)
                                .padding(-4)
                        )
                        .overlay(
                            Circle()
                                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                        )
                        .shadow(color: c.swiftUIColor.opacity(style.color == c ? 0.4 : 0.0), radius: 6, y: 3)
                        .scaleEffect(style.color == c ? 1.1 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { style.color = c }
                            Haptic.shared.light()
                        }
                }
            }
            
            Divider()
            
            // Stroke Section
            VStack(alignment: .leading, spacing: 12) {
                Text("STROKE").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                
                Picker("LineStyle", selection: $style.lineStyle) {
                    ForEach(LineStyle.allCases, id: \.self) { s in
                        Text(s.rawValue.capitalized).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                
                Toggle(isOn: $style.hasArrow) {
                    Label("Arrowhead", systemImage: "arrow.right")
                        .font(.system(size: 14, weight: .medium))
                }
                .tint(.blue)
            }
            
            Divider()
            
            // Fill Section
            VStack(alignment: .leading, spacing: 12) {
                Text("FILL").font(.system(size: 11, weight: .bold)).foregroundColor(.secondary)
                
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(FillType.allCases, id: \.self) { f in
                            Text(f.rawValue.capitalized)
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(style.fillType == f ? Color.blue : Color(UIColor.secondarySystemBackground))
                                .foregroundColor(style.fillType == f ? .white : .primary)
                                .cornerRadius(8)
                                .shadow(color: style.fillType == f ? .blue.opacity(0.3) : .clear, radius: 4, y: 2)
                                .onTapGesture {
                                    withAnimation(.spring()) { style.fillType = f }
                                    Haptic.shared.light()
                                }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(width: 290)
        .liquidGlass(cornerRadius: 24)
    }
}

extension View {
    func liquidGlass(cornerRadius: CGFloat) -> some View {
        self
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(LinearGradient(colors: [Color.white.opacity(0.72), Color.white.opacity(0.08)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.0)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.white.opacity(0.22), lineWidth: 0.35)
                    .blur(radius: 1.0)
            )
            .shadow(color: .white.opacity(0.24), radius: 3.0, y: -1.0)
            .shadow(color: .black.opacity(0.18), radius: 18.0, y: 10.0)
    }
}
