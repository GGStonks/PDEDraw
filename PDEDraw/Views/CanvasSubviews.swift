import SwiftUI
import UIKit.UIGestureRecognizerSubclass

// MARK: - HELPERS

// Custom Gesture Recognizer that triggers INSTANTLY on touch-down (unlike UIPanGestureRecognizer).
// Employs a direct bypass for 240Hz coalesced touch extraction to guarantee buttery smooth Apple Pencil tracking!
class InstantPencilGestureRecognizer: UIGestureRecognizer {
    var startLoc: CGPoint = .zero
    var activeTouch: UITouch?
    
    // Bypass standard target-action run loops entirely for 240Hz direct pipeline
    var directOnChanged: ((CGPoint, CGPoint) -> Void)?
    var directOnEnded: ((CGPoint, CGPoint) -> Void)?
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        // Enforce Apple Pencil & Mouse ONLY
        guard let touch = touches.first, (touch.type == .pencil || touch.type == .indirectPointer) else {
            state = .failed
            return
        }
        
        activeTouch = touch
        startLoc = touch.location(in: view)
        state = .began // Immediately claim the touch so ScrollView cannot steal it!
        directOnChanged?(startLoc, startLoc)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state != .failed, let touch = activeTouch, touches.contains(touch) else { return }
        state = .changed
        
        // Unleash the true 240Hz Apple Pencil touch resolution!
        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                directOnChanged?(cTouch.location(in: view), startLoc)
            }
        } else {
            directOnChanged?(touch.location(in: view), startLoc)
        }
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state != .failed, let touch = activeTouch, touches.contains(touch) else { return }
        
        if let coalesced = event.coalescedTouches(for: touch) {
            for cTouch in coalesced {
                directOnChanged?(cTouch.location(in: view), startLoc)
            }
        }
        
        state = .ended
        directOnEnded?(touch.location(in: view), startLoc)
        activeTouch = nil
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        guard state != .failed, let touch = activeTouch, touches.contains(touch) else { return }
        state = .cancelled
        directOnEnded?(touch.location(in: view), startLoc)
        activeTouch = nil
    }
}

// Intercepts pencil and indirect pointer (mouse) for drawing, but lets direct finger touches pass to ScrollView.
struct PencilTouchTracker: UIViewRepresentable {
    var onChanged: (CGPoint, CGPoint) -> Void
    var onEnded: (CGPoint, CGPoint) -> Void
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear // Transparent so it doesn't block rendering
        
        let gesture = InstantPencilGestureRecognizer(target: nil, action: nil)
        gesture.cancelsTouchesInView = true // Hard-block the ScrollView from receiving these touches
        
        // Pass mapping closures directly into the high-frequency gesture pipeline
        gesture.directOnChanged = onChanged
        gesture.directOnEnded = onEnded
        
        view.addGestureRecognizer(gesture)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let gesture = uiView.gestureRecognizers?.first as? InstantPencilGestureRecognizer {
            gesture.directOnChanged = onChanged
            gesture.directOnEnded = onEnded
        }
    }
}

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

struct LineGrid: View {
    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0.0, to: size.width, by: 40.0) {
                var p = Path()
                p.move(to: CGPoint(x: x, y: 0.0))
                p.addLine(to: CGPoint(x: x, y: size.height))
                context.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 1.0)
            }
            for y in stride(from: 0.0, to: size.height, by: 40.0) {
                var p = Path()
                p.move(to: CGPoint(x: 0.0, y: y))
                p.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(p, with: .color(.white.opacity(0.06)), lineWidth: 1.0)
            }
        }.ignoresSafeArea()
    }
}

extension Font { static func serif(size: CGFloat) -> Font { .system(size: size, weight: .bold, design: .serif) } }
