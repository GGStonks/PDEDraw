import SwiftUI
import PhotosUI

// MARK: - Activity View for Safe Share Sheet on iPad/Mac
struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ShareWrapper: Identifiable {
    let id = UUID()
    let url: URL
}

struct MainView: View {
    @StateObject var viewModel = CanvasViewModel()
    @State private var showInspector = false
    @State private var showPreview = false
    @State private var showToast = false
    
    @State private var selectedPhoto: PhotosPickerItem? = nil
    @State private var shareWrapper: ShareWrapper? = nil
    
    // Draggable Toolbar State
    @State private var paletteOffset: CGSize = CGSize(width: 24, height: -24)
    @GestureState private var dragOffset: CGSize = .zero

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
                
                // 2. Premium Toast Notification
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
                        .glassEffect(in: RoundedRectangle(cornerRadius: 24))
                        .transition(.move(edge: .top).combined(with: .opacity).combined(with: .scale(scale: 0.9)))
                        
                        Spacer()
                    }
                    .padding(.top, 16)
                    .zIndex(3)
                }
                
                // 3. Top Action Bar
                VStack {
                    TopActionBar
                    Spacer()
                }
                .padding(.horizontal, 24)
                
                // 4. Floating Draggable Palette
                FloatingPalette
                    .position(
                        x: geo.size.width / 2 + paletteOffset.width + dragOffset.width,
                        y: geo.size.height - 90 + paletteOffset.height + dragOffset.height
                    )
                    // Apply drag to the entire ZStack bounding box through the background layer setup
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation
                            }
                            .onEnded { value in
                                paletteOffset.width += value.translation.width
                                paletteOffset.height += value.translation.height
                                
                                // Keep it inside screen bounds safely
                                let margin: CGFloat = 60
                                let minX: CGFloat = -geo.size.width / 2 + margin
                                let maxX: CGFloat = geo.size.width / 2 - margin
                                let minY: CGFloat = -geo.size.height + margin + 140
                                let maxY: CGFloat = -margin
                                
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                    paletteOffset.width = min(max(paletteOffset.width, minX), maxX)
                                    paletteOffset.height = min(max(paletteOffset.height, minY), maxY)
                                }
                            }
                    )
            }
            .sheet(isPresented: $showPreview) {
                GeometryReader { geo in
                    TikZPreviewView(tikzCode: TikZExporter.generateCode(from: viewModel.shapes, canvasSize: geo.size))
                }
            }
            .sheet(item: $shareWrapper) { item in
                ActivityView(activityItems: [item.url], applicationActivities: nil)
            }
            .preferredColorScheme(.dark)
            .onChange(of: selectedPhoto) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            viewModel.tracingImage = image
                            Haptic.shared.success()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UI Components
    
    var TopActionBar: some View {
        HStack {
            Button(action: { viewModel.clear() }) {
                Image(systemName: "trash")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.8))
                    .clipShape(Circle())
                    .shadow(color: .red.opacity(0.3), radius: 8, y: 4)
            }
            
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(viewModel.canUndo ? .white : .white.opacity(0.35))
                    .frame(width: 44, height: 44)
                    .glassEffect(in: Circle())
            }
            .disabled(!viewModel.canUndo)
            
            Spacer()
            
            PhotosPicker(selection: $selectedPhoto, matching: .images, photoLibrary: .shared()) {
                Image(systemName: "photo.badge.plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: Circle())
            }
            
            Button(action: {
                if let url = PDFExporter.exportViewModel(viewModel) {
                    self.shareWrapper = ShareWrapper(url: url)
                }
            }) {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: Circle())
            }
            
            Button(action: { showPreview = true; Haptic.shared.light() }) {
                Image(systemName: "eye")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                    .frame(width: 44, height: 44)
                    .glassEffect(in: Circle())
            }
            
            GeometryReader { geo in
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
                    .foregroundColor(.white)
                    .background(Color.blue)
                    .clipShape(Capsule())
                    .shadow(color: .blue.opacity(0.4), radius: 8, y: 4)
                }
            }.frame(width: 90, height: 44)
        }
        .padding(.vertical, 12)
    }
    
    // Draggable Minimal Floating Palette
    var FloatingPalette: some View {
        VStack(spacing: 0) {
            
            // Dedicated drag grip area that is physically larger to grab easily
            ZStack {
                Color.clear.frame(height: 24)
                Capsule()
                    .fill(Color.secondary.opacity(0.5))
                    .frame(width: 42, height: 5)
            }
            .contentShape(Rectangle()) // Catches the drags effortlessly
            .padding(.top, 4)
            .padding(.bottom, 4)
            
            HStack(spacing: 6) {
                let tools: [DrawingTool] = [.scribble, .eraser, .lasso, .move, .point, .line, .rectangle, .ellipse, .curve, .label]
                
                ForEach(tools, id: \.self) { t in
                    let isActive = viewModel.currentTool == t
                    Button(action: {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.currentTool = t
                            if t == .scribble { viewModel.currentStyle.lineStyle = .solid }
                        }
                        Haptic.shared.light()
                    }) {
                        Image(systemName: icon(t, isActive: isActive))
                            .font(.system(size: 19, weight: isActive ? .bold : .medium))
                            .foregroundColor(isActive ? (t == .eraser ? .white : .black) : .primary.opacity(0.8))
                            .frame(width: 42, height: 42)
                            .background(
                                isActive ? (t == .eraser ? Color.red : Color(UIColor.systemGray4)) : Color.clear
                            )
                            .clipShape(Circle())
                    }
                }
            }
            .padding(.horizontal, 14)
            
            Divider()
                .background(Color.secondary.opacity(0.3))
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            
            // Integrated Mini Inspector
            HStack(spacing: 12) {
                // Color Swatches
                ForEach([ShapeColor.graphite, ShapeColor.rose, ShapeColor.ocean, ShapeColor.amber], id: \.self) { c in
                    Circle()
                        .fill(c.swiftUIColor)
                        .frame(width: 26, height: 26)
                        .overlay(
                            Circle().stroke(Color.primary, lineWidth: viewModel.currentStyle.color == c ? 2.0 : 0.0)
                        )
                        .scaleEffect(viewModel.currentStyle.color == c ? 1.15 : 1.0)
                        .onTapGesture {
                            withAnimation(.spring()) { viewModel.currentStyle.color = c }
                            Haptic.shared.light()
                        }
                }
                
                Spacer()
                
                // Expand Full Inspector
                Button(action: {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { showInspector.toggle() }
                    Haptic.shared.light()
                }) {
                    Image(systemName: showInspector ? "slider.horizontal.3" : "slider.horizontal.2.square.on.square")
                        .font(.system(size: 18, weight: showInspector ? .heavy : .medium))
                        .foregroundColor(showInspector ? .black : .primary.opacity(0.9))
                        .frame(width: 38, height: 38)
                        .background(showInspector ? Color.white : Color(UIColor.secondarySystemBackground).opacity(0.5))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            // Pop-out Full Inspector
            if showInspector {
                InspectorView(viewModel: viewModel, style: $viewModel.currentStyle)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, 12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(UIColor.systemBackground).opacity(0.1))
                .background(Material.ultraThin)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        )
        // Drag works over the whole background, not just the handle! 
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        // Fixed max width for a beautiful floating card, tools compactly fit
        .frame(width: 480)
        .shadow(color: Color.black.opacity(0.4), radius: 30, y: 15)
        .shadow(color: Color.black.opacity(0.2), radius: 8, y: 4)
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Color.white.opacity(0.15), lineWidth: 1))
    }
    
    func icon(_ t: DrawingTool, isActive: Bool) -> String {
        switch t {
        case .move: return isActive ? "hand.point.up.left.fill" : "hand.point.up.left"
        case .lasso: return "lasso"
        case .curve: return "point.3.connected.trianglepath.dotted"
        case .scribble: return isActive ? "pencil.tip.crop.circle.badge.plus" : "pencil.tip.crop.circle"
        case .rectangle: return isActive ? "rectangle.fill" : "rectangle"
        case .ellipse: return isActive ? "circle.fill" : "circle"
        case .line: return "line.diagonal"
        case .point: return "smallcircle.filled.circle"
        case .label: return "textformat"
        case .eraser: return isActive ? "eraser.fill" : "eraser"
        }
    }
}

// MARK: - Premium Inspector View (Embedded Variant)
struct InspectorView: View {
    @ObservedObject var viewModel: CanvasViewModel
    @Binding var style: ShapeStyle
    
    // Grid layouts for seamless custom buttons that ignore drag interceptions
    let optionGrid = [GridItem(.adaptive(minimum: 75), spacing: 8)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            
            Divider().background(Color.secondary.opacity(0.3))
            
            // Canvas Options
            HStack(alignment: .top) {
                Text("Canvas")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 65, alignment: .leading)
                    .padding(.top, 6)
                
                LazyVGrid(columns: optionGrid, alignment: .leading, spacing: 10) {
                    ForEach(GridStyle.allCases, id: \.self) { g in
                        Text(g.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(viewModel.gridStyle == g ? Color.primary : Color(UIColor.tertiarySystemFill))
                            .foregroundColor(viewModel.gridStyle == g ? Color(UIColor.systemBackground) : .primary)
                            .clipShape(Capsule())
                            .onTapGesture {
                                withAnimation(.spring()) { viewModel.gridStyle = g }
                                Haptic.shared.light()
                            }
                    }
                }
            }
            
            // Stroke Options
            HStack(alignment: .top) {
                Text("Stroke")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 65, alignment: .leading)
                    .padding(.top, 6)
                
                LazyVGrid(columns: optionGrid, alignment: .leading, spacing: 10) {
                    ForEach(LineStyle.allCases, id: \.self) { s in
                        Text(s.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(style.lineStyle == s ? Color.primary : Color(UIColor.tertiarySystemFill))
                            .foregroundColor(style.lineStyle == s ? Color(UIColor.systemBackground) : .primary)
                            .clipShape(Capsule())
                            .onTapGesture {
                                withAnimation(.spring()) { style.lineStyle = s }
                                Haptic.shared.light()
                            }
                    }
                }
            }
            
            // Fill Options
            HStack(alignment: .top) {
                Text("Fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 65, alignment: .leading)
                    .padding(.top, 6)
                
                LazyVGrid(columns: optionGrid, alignment: .leading, spacing: 10) {
                    ForEach(FillType.allCases, id: \.self) { f in
                        Text(f.rawValue.capitalized)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(style.fillType == f ? Color.primary : Color(UIColor.tertiarySystemFill))
                            .foregroundColor(style.fillType == f ? Color(UIColor.systemBackground) : .primary)
                            .clipShape(Capsule())
                            .onTapGesture {
                                withAnimation(.spring()) { style.fillType = f }
                                Haptic.shared.light()
                            }
                    }
                }
            }
            
            Toggle(isOn: $style.hasArrow) {
                Text("Arrowhead")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .tint(Color.primary)
            
        }
        .padding(.horizontal, 16)
        .padding(.top, 4)
    }
}
