import SwiftUI

class PDFExporter {
    static func exportViewModel(_ viewModel: CanvasViewModel) -> URL? {
        // We now allow exporting even if there are no vector shapes (e.g., just the tracing background or an empty grid!)
        var minX: CGFloat = 0.0
        var minY: CGFloat = 0.0
        var maxX: CGFloat = 1000.0
        var maxY: CGFloat = 1000.0
        
        if !viewModel.shapes.isEmpty {
            minX = .infinity
            minY = .infinity
            maxX = -.infinity
            maxY = -.infinity
            
            for shape in viewModel.shapes {
                let b = shape.boundingBox
                if b.minX < minX { minX = b.minX }
                if b.minY < minY { minY = b.minY }
                if b.maxX > maxX { maxX = b.maxX }
                if b.maxY > maxY { maxY = b.maxY }
            }
        }
        
        let padding: CGFloat = 60.0
        let w = max(maxX - minX, 100.0)
        let h = max(maxY - minY, 100.0)
        
        let renderingView = ZStack(alignment: .topLeading) {
            Color.white
            ZStack(alignment: .topLeading) {
                // If they want to export the tracing image as part of the PDF, they can! (but strictly optional based on current architecture)
                if let tracingImage = viewModel.tracingImage {
                    Image(uiImage: tracingImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 2000, maxHeight: 2000)
                        .opacity(0.4)
                        .allowsHitTesting(false)
                }

                ForEach(viewModel.shapes) { shape in
                    ShapeRenderer(shape: shape, viewModel: viewModel)
                }
            }
            .offset(x: -minX + padding, y: -minY + padding)
        }
        .frame(width: w + padding * 2, height: h + padding * 2)
        
        let renderer = ImageRenderer(content: renderingView)
        
        let url = URL.documentsDirectory.appendingPathComponent("CanvasExport.pdf")
        
        renderer.render { size, context in
            var box = CGRect(x: 0, y: 0, width: size.width, height: size.height)
            guard let pdf = CGContext(url as CFURL, mediaBox: &box, nil) else { return }
            pdf.beginPDFPage(nil)
            
            // Just apply the context rendering
            context(pdf)
            
            pdf.endPDFPage()
            pdf.closePDF()
        }
        
        return url
    }
}
