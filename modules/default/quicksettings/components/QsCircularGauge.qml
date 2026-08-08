import QtQuick
import QtQuick.Layouts

// ── QsCircularGauge ───────────────────────────────────────────────────────
// Anel de progresso desenhado via Canvas (sem depender de QtQuick.Shapes),
// com valor central e label embaixo. Usado na linha "System" do dashboard
// compacto: CPU / RAM / Disk / Temp.
Item {
    id: root

    property real   value:      0        // 0–100
    property string valueLabel: ""       // texto central, ex.: "42%" ou "61°"
    property string label:      ""       // ex.: "CPU"

    property color colorAccent:     "#a8c8ff"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorProgressBg: "#474747"

    property int  diameter:   52
    property int  strokeWidth: 4

    implicitWidth:  diameter
    implicitHeight: diameter + 18

    ColumnLayout {
        anchors.fill: parent
        spacing: 4

        Item {
            Layout.preferredWidth:  root.diameter
            Layout.preferredHeight: root.diameter
            Layout.alignment: Qt.AlignHCenter

            Canvas {
                id: cv
                anchors.fill: parent
                antialiasing: true

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.reset()
                    var cx = width / 2, cy = height / 2
                    var r  = Math.min(width, height) / 2 - root.strokeWidth / 2
                    var start = -Math.PI / 2

                    // trilho de fundo
                    ctx.beginPath()
                    ctx.lineWidth = root.strokeWidth
                    ctx.strokeStyle = Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.5)
                    ctx.lineCap = "round"
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI, false)
                    ctx.stroke()

                    // progresso
                    var frac = Math.max(0, Math.min(1, root.value / 100))
                    if (frac > 0) {
                        ctx.beginPath()
                        ctx.lineWidth = root.strokeWidth
                        ctx.strokeStyle = root.colorAccent
                        ctx.lineCap = "round"
                        ctx.arc(cx, cy, r, start, start + frac * 2 * Math.PI, false)
                        ctx.stroke()
                    }
                }

                Behavior on opacity { NumberAnimation { duration: 150 } }
            }

            // redesenha quando value ou cores mudam
            Connections {
                target: root
                function onValueChanged()       { cv.requestPaint() }
                function onColorAccentChanged() { cv.requestPaint() }
            }
            Component.onCompleted: cv.requestPaint()

            Text {
                anchors.centerIn: parent
                text: root.valueLabel
                color: root.colorText
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Text {
            Layout.alignment: Qt.AlignHCenter
            text: root.label
            color: root.colorTextDim
            font.pixelSize: 9
            opacity: 0.8
        }
    }
}
