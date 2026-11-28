import SwiftUI

private enum CanvasSpace {
    static let name = "widgetCanvas"
}

/// Transparent layer above the rendered design that handles selecting, dragging, resizing
/// and rotating elements.
struct CanvasInteractionLayer: View {
    @ObservedObject var model: EditorModel
    let canvas: CGSize

    var body: some View {
        ZStack {
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    model.selection = nil
                }

            ForEach(model.design.elements) { element in
                if !element.isHidden {
                    ElementHitArea(model: model, element: element, canvas: canvas)
                }
            }

            if let selected = model.selectedElement, !selected.isHidden {
                SelectionChrome(model: model, element: selected, canvas: canvas)
            }

            if model.guideX {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: 1, height: canvas.height)
                    .allowsHitTesting(false)
            }
            if model.guideY {
                Rectangle()
                    .fill(Color.yellow)
                    .frame(width: canvas.width, height: 1)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: canvas.width, height: canvas.height)
        .coordinateSpace(name: CanvasSpace.name)
    }
}

// MARK: - Hit area and dragging

private struct ElementHitArea: View {
    @ObservedObject var model: EditorModel
    let element: DesignElement
    let canvas: CGSize
    @State private var dragStart: CGPoint?

    var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .frame(
                width: max(12, CGFloat(element.width) * canvas.width),
                height: max(12, CGFloat(element.height) * canvas.height)
            )
            .onTapGesture {
                model.selection = element.id
            }
            .gesture(dragGesture)
            .rotationEffect(.degrees(element.rotation))
            .position(x: CGFloat(element.x) * canvas.width, y: CGFloat(element.y) * canvas.height)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(CanvasSpace.name))
            .onChanged { value in
                if dragStart == nil {
                    model.selection = element.id
                    guard !element.isLocked else { return }
                    model.beginInteraction()
                    dragStart = CGPoint(x: element.x, y: element.y)
                }
                guard let start = dragStart else { return }
                var newX = Double(start.x) + Double(value.translation.width / canvas.width)
                var newY = Double(start.y) + Double(value.translation.height / canvas.height)
                newX = min(max(newX, -0.2), 1.2)
                newY = min(max(newY, -0.2), 1.2)

                let snapX = abs(newX - 0.5) < 0.02
                let snapY = abs(newY - 0.5) < 0.02
                if snapX { newX = 0.5 }
                if snapY { newY = 0.5 }
                model.guideX = snapX
                model.guideY = snapY

                let targetX = newX
                let targetY = newY
                model.edit(element.id, registersUndo: false) { item in
                    item.x = targetX
                    item.y = targetY
                }
            }
            .onEnded { _ in
                dragStart = nil
                model.guideX = false
                model.guideY = false
            }
    }
}

// MARK: - Selection outline and handles

private struct ResizeStart {
    var x: Double
    var y: Double
    var width: Double
    var height: Double
}

private struct SelectionChrome: View {
    @ObservedObject var model: EditorModel
    let element: DesignElement
    let canvas: CGSize
    @State private var resizeStart: ResizeStart?
    @State private var isRotating = false

    private var boxWidth: CGFloat { max(12, CGFloat(element.width) * canvas.width) }
    private var boxHeight: CGFloat { max(12, CGFloat(element.height) * canvas.height) }

    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.accentColor, lineWidth: 1.5)
                .allowsHitTesting(false)

            if !element.isLocked {
                // Rotate handle, above the top edge.
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 1.5, height: 14)
                    .position(x: boxWidth / 2, y: -7)
                    .allowsHitTesting(false)
                handleDot(systemName: "arrow.triangle.2.circlepath")
                    .gesture(rotateGesture)
                    .position(x: boxWidth / 2, y: -22)

                // Resize handle, bottom-right corner.
                handleDot(systemName: "arrow.up.left.and.arrow.down.right")
                    .gesture(resizeGesture)
                    .position(x: boxWidth, y: boxHeight)
            } else {
                Image(systemName: "lock.fill")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .padding(5)
                    .background(Circle().fill(Color.accentColor))
                    .position(x: boxWidth, y: 0)
                    .allowsHitTesting(false)
            }
        }
        .frame(width: boxWidth, height: boxHeight)
        .rotationEffect(.degrees(element.rotation))
        .position(x: CGFloat(element.x) * canvas.width, y: CGFloat(element.y) * canvas.height)
    }

    private func handleDot(systemName: String) -> some View {
        Image(systemName: systemName)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 24, height: 24)
            .background(Circle().fill(Color.accentColor))
            .overlay(Circle().stroke(Color.white, lineWidth: 1.5))
            .frame(width: 40, height: 40)
            .contentShape(Circle())
    }

    private var resizeGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasSpace.name))
            .onChanged { value in
                if resizeStart == nil {
                    model.beginInteraction()
                    resizeStart = ResizeStart(x: element.x, y: element.y, width: element.width, height: element.height)
                }
                guard let start = resizeStart else { return }

                let phi = element.rotation * .pi / 180
                let tx = Double(value.translation.width)
                let ty = Double(value.translation.height)
                // Screen-space drag expressed along the element's own (rotated) axes.
                let localDX = tx * cos(phi) + ty * sin(phi)
                let localDY = -tx * sin(phi) + ty * cos(phi)

                let canvasW = Double(canvas.width)
                let canvasH = Double(canvas.height)
                let newWidthPts = max(24, start.width * canvasW + localDX)
                let newHeightPts = max(24, start.height * canvasH + localDY)
                let appliedDX = newWidthPts - start.width * canvasW
                let appliedDY = newHeightPts - start.height * canvasH

                // Keep the opposite corner fixed: the centre moves by half the change,
                // rotated back into canvas space.
                let shiftX = (appliedDX / 2) * cos(phi) - (appliedDY / 2) * sin(phi)
                let shiftY = (appliedDX / 2) * sin(phi) + (appliedDY / 2) * cos(phi)

                let newWidth = newWidthPts / canvasW
                let newHeight = newHeightPts / canvasH
                let newX = start.x + shiftX / canvasW
                let newY = start.y + shiftY / canvasH
                model.edit(element.id, registersUndo: false) { item in
                    item.width = newWidth
                    item.height = newHeight
                    item.x = newX
                    item.y = newY
                }
            }
            .onEnded { _ in
                resizeStart = nil
            }
    }

    private var rotateGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(CanvasSpace.name))
            .onChanged { value in
                if !isRotating {
                    model.beginInteraction()
                    isRotating = true
                }
                let centerX = element.x * Double(canvas.width)
                let centerY = element.y * Double(canvas.height)
                let dx = Double(value.location.x) - centerX
                let dy = Double(value.location.y) - centerY
                var degrees = atan2(dy, dx) * 180 / .pi + 90
                if degrees > 180 {
                    degrees -= 360
                }
                let snapped = (degrees / 45).rounded() * 45
                if abs(degrees - snapped) < 4 {
                    degrees = snapped
                }
                let target = degrees
                model.edit(element.id, registersUndo: false) { item in
                    item.rotation = target
                }
            }
            .onEnded { _ in
                isRotating = false
            }
    }
}
