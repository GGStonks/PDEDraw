import SwiftUI

struct MainView: View {
    @StateObject var viewModel = CanvasViewModel()
    @State private var showInspector = false
    @State private var showPreview = false
    @State private var showToast = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
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
                        .background(.regularMaterial)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 0.5)) // Glass edge
                        .shadow(color: .black.opacity(0.12), radius: 15, y: 8)
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
                                .foregroundColor(.red.opacity(0.8))
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
                        }
                        
                        Spacer()
                        
                        // Preview Button
                        Button(action: { showPreview = true; Haptic.shared.light() }) {
                            Image(systemName: "eye")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.primary)
                                .frame(width: 44, height: 44)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 0.5))
                                .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
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
                                LinearGradient(colors: [Color.blue.opacity(0.9), Color.indigo.opacity(0.9)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                            .foregroundColor(.white)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 0.5))
                            .shadow(color: .blue.opacity(0.3), radius: 10, y: 5)
                        }
                    }.padding(.horizontal, 20).padding(.top, 10)
                    
                    Spacer()
                    
                    // 4. The "visionOS" Floating Dock
                    HStack(spacing: 8) {
                        ForEach([DrawingTool.move, .curve, .rectangle, .ellipse, .line, .point, .label, .eraser], id: \.self) { t in
                            let isActive = viewModel.currentTool == t
                            Button(action: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { viewModel.currentTool = t }
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
                    .overlay(Capsule().stroke(Color.white.opacity(0.5), lineWidth: 0.5)) // Glass specular highlight
                    .shadow(color: .black.opacity(0.12), radius: 25, y: 12)
                    .padding(.bottom, geo.safeAreaInsets.bottom + 16)
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
        }
    }
    
    // Uses filled icons for active states, outlined for inactive
    func icon(_ t: DrawingTool, isActive: Bool) -> String {
        switch t {
        case .move: return isActive ? "hand.point.up.left.fill" : "hand.point.up.left"
        case .curve: return "scribble.variable"
        case .rectangle: return isActive ? "rectangle.fill" : "rectangle"
        case .ellipse: return isActive ? "circle.fill" : "circle"
        case .line: return "line.diagonal"
        case .point: return "smallcircle.filled.circle"
        case .label: return "textformat"
        case .eraser: return isActive ? "eraser.fill" : "eraser"
        }
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
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(.thickMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.15), radius: 30, y: 15)
    }
}
