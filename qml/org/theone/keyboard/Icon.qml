import QtQuick 2.6

// Vector icons drawn on a canvas so no image plugins are needed.
// Each icon is designed in its own small box (refW x refH, reference units) and scaled.
Canvas {
    id: icon

    property string name: ""          // shift | shiftOn | capsLock | backspace | return | emoji
    property color color: "#ffffff"
    property color cutout: "#1f1f1f"  // face details of the emoji icon
    property real scaleFactor: 1

    readonly property var boxes: ({
        "shift": [28, 25], "shiftOn": [28, 25], "capsLock": [28, 27],
        "backspace": [29, 25], "return": [28, 25], "emoji": [39, 39]
    })
    readonly property var box: boxes[name] || [24, 24]

    width: Math.ceil(box[0] * scaleFactor) + 4
    height: Math.ceil(box[1] * scaleFactor) + 4

    onNameChanged: requestPaint()
    onColorChanged: requestPaint()
    onScaleFactorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function arrowPath(ctx, stemBottom) {
        // Upward block arrow: head 28 wide, stem 12 wide.
        ctx.beginPath()
        ctx.moveTo(14, 1.2)
        ctx.lineTo(26.8, 13.2)
        ctx.lineTo(20, 13.2)
        ctx.lineTo(20, stemBottom)
        ctx.lineTo(8, stemBottom)
        ctx.lineTo(8, 13.2)
        ctx.lineTo(1.2, 13.2)
        ctx.closePath()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        ctx.save()
        ctx.translate(2, 2)
        ctx.scale(scaleFactor, scaleFactor)
        ctx.lineJoin = "round"
        ctx.lineCap = "round"
        ctx.strokeStyle = color
        ctx.fillStyle = color

        if (name === "shift" || name === "shiftOn") {
            arrowPath(ctx, 23.4)
            ctx.lineWidth = 2.6
            ctx.stroke()
            if (name === "shiftOn")
                ctx.fill()
        } else if (name === "capsLock") {
            arrowPath(ctx, 18.6)
            ctx.lineWidth = 2.6
            ctx.stroke()
            ctx.fill()
            ctx.fillRect(7.4, 22.6, 13.2, 3.6)
        } else if (name === "backspace") {
            ctx.lineWidth = 2.4
            var r = 3.4
            ctx.beginPath()
            ctx.moveTo(1.4, 12.5)
            ctx.lineTo(9.0, 1.4)
            ctx.lineTo(27.6 - r, 1.4)
            ctx.arcTo(27.6, 1.4, 27.6, 1.4 + r, r)
            ctx.lineTo(27.6, 23.6 - r)
            ctx.arcTo(27.6, 23.6, 27.6 - r, 23.6, r)
            ctx.lineTo(9.0, 23.6)
            ctx.closePath()
            ctx.stroke()
            ctx.lineWidth = 2.6
            ctx.beginPath()
            ctx.moveTo(13.6, 7.6)
            ctx.lineTo(22.6, 17.4)
            ctx.moveTo(22.6, 7.6)
            ctx.lineTo(13.6, 17.4)
            ctx.stroke()
        } else if (name === "return") {
            ctx.lineWidth = 2.4
            var rr = 3
            ctx.beginPath()
            ctx.moveTo(18.4, 1.6)
            ctx.lineTo(26.4 - rr, 1.6)
            ctx.arcTo(26.4, 1.6, 26.4, 1.6 + rr, rr)
            ctx.lineTo(26.4, 16.2 - rr)
            ctx.arcTo(26.4, 16.2, 26.4 - rr, 16.2, rr)
            ctx.lineTo(2.0, 16.2)
            ctx.moveTo(9.2, 9.0)
            ctx.lineTo(2.0, 16.2)
            ctx.lineTo(9.2, 23.4)
            ctx.stroke()
        } else if (name === "emoji") {
            ctx.beginPath()
            ctx.arc(19.5, 19.5, 19.5, 0, Math.PI * 2, false)
            ctx.fill()
            ctx.fillStyle = cutout
            // eyes
            ctx.beginPath()
            ctx.ellipse(11.4, 9.2, 4.0, 6.6)   // x, y, w, h (bounding box)
            ctx.fill()
            ctx.beginPath()
            ctx.ellipse(23.6, 9.2, 4.0, 6.6)
            ctx.fill()
            // wide open grin
            ctx.beginPath()
            ctx.moveTo(6.6, 20.6)
            ctx.lineTo(32.4, 20.6)
            ctx.arc(19.5, 20.6, 12.9, 0, Math.PI, false)
            ctx.closePath()
            ctx.fill()
            // teeth
            ctx.fillStyle = color
            ctx.beginPath()
            ctx.moveTo(9.4, 22.6)
            ctx.lineTo(29.6, 22.6)
            ctx.lineTo(28.6, 25.4)
            ctx.lineTo(10.4, 25.4)
            ctx.closePath()
            ctx.fill()
        }
        ctx.restore()
    }
}
