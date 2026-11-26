import QtQuick 2.6

// The magnified "balloon" shown above a letter key while it is pressed.
// Covers the whole keyboard; draws only around the pressed key.
Item {
    id: popup

    property real kx: 0
    property real ky: 0
    property real kw: 0
    property real kh: 0
    property string text: ""
    property color color: "#434343"
    property color textColor: "#ffffff"
    property color edgeColor: "transparent"   // outline, for white balloons on white keys
    property string fontFamily: ""
    property real unit: 1          // reference unit in pixels

    readonly property real ext: 13 * unit                       // how far the head sticks out
    readonly property real extL: Math.max(0, Math.min(ext, kx - 2 * unit))
    readonly property real extR: Math.max(0, Math.min(ext, width - (kx + kw) - 2 * unit))
    readonly property real headH: kh * 1.2
    readonly property real headTop: ky - headH - kh * 0.02
    readonly property real neckTop: ky + kh * 0.06              // where the head starts narrowing
    readonly property real neckBottom: ky + kh * 0.34           // where it reaches key width

    onKxChanged: canvas.requestPaint()
    onKyChanged: canvas.requestPaint()
    onKwChanged: canvas.requestPaint()
    onVisibleChanged: if (visible) canvas.requestPaint()
    onColorChanged: canvas.requestPaint()
    onEdgeColorChanged: canvas.requestPaint()

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()
            if (!popup.visible)
                return
            var r = 10 * popup.unit
            var L = popup.kx - popup.extL, R = popup.kx + popup.kw + popup.extR
            var T = popup.headTop, B = popup.ky + popup.kh
            var l = popup.kx, rr = popup.kx + popup.kw
            var n1 = popup.neckTop, n2 = popup.neckBottom
            ctx.fillStyle = popup.color
            ctx.beginPath()
            ctx.moveTo(l + r, B)
            ctx.arcTo(l, B, l, B - r, r)
            ctx.lineTo(l, n2)
            ctx.bezierCurveTo(l, (n1 + n2) / 2, L, (n1 + n2) / 2, L, n1)
            ctx.lineTo(L, T + r)
            ctx.arcTo(L, T, L + r, T, r)
            ctx.lineTo(R - r, T)
            ctx.arcTo(R, T, R, T + r, r)
            ctx.lineTo(R, n1)
            ctx.bezierCurveTo(R, (n1 + n2) / 2, rr, (n1 + n2) / 2, rr, n2)
            ctx.lineTo(rr, B - r)
            ctx.arcTo(rr, B, rr - r, B, r)
            ctx.closePath()
            ctx.fill()
            if (popup.edgeColor.a > 0) {
                ctx.strokeStyle = popup.edgeColor
                ctx.lineWidth = Math.max(1, 1.2 * popup.unit)
                ctx.stroke()
            }
        }
    }

    Text {
        x: popup.kx - popup.extL
        width: popup.kw + popup.extL + popup.extR
        y: popup.headTop
        height: popup.headH
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: popup.text
        color: popup.textColor
        font.family: popup.fontFamily
        font.pixelSize: 44 * popup.unit
    }
}
