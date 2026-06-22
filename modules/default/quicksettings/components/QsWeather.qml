import Quickshell.Io
import QtQuick
import QtQuick.Layouts

// ── QsWeather ─────────────────────────────────────────────────────────────────
// Clima atual via wttr.in (sem necessidade de API key). Busca uma vez ao
// carregar e depois a cada 30 minutos — clima não muda rápido o suficiente
// para justificar polling mais frequente.
//
// Formato pedido ao wttr.in: "%C|%t|%h|%w" (condição|temperatura|umidade|vento)
// Separador "|" evita ambiguidade de parsing.
Item {
    id: root

    property color colorAccent:  "#ffb4a9"
    property color colorText:    "#e2e2e2"
    property color colorTextDim: "#c6c6c6"

    property bool compact: false   // true = card menor, lado a lado com outro widget

    property string city: "Belo Horizonte"

    property string condition:   ""
    property string temperature: ""
    property string humidity:    ""
    property string wind:        ""
    property bool   loading:     false
    property bool   hasError:    false

    function refresh() {
        if (weatherProc.running) return
        root.loading  = true
        root.hasError = false
        var encodedCity = root.city.replace(/ /g, "+")
        weatherProc.command = ["bash", "-c",
            "curl -s --max-time 6 'wttr.in/" + encodedCity + "?m&format=%C|%t|%h|%w'"]
        weatherProc.running = true
    }

    Process {
        id: weatherProc
        property string _buf: ""
        stdout: SplitParser { onRead: (l) => weatherProc._buf += l }
        onRunningChanged: {
            if (!running) {
                var out = weatherProc._buf.trim()
                weatherProc._buf = ""
                root.loading = false
                var parts = out.split("|")
                if (parts.length < 4 || out.indexOf("Unknown") >= 0 || out === "") {
                    root.hasError = true
                    return
                }
                root.condition   = parts[0].trim()
                root.temperature = parts[1].trim()
                root.humidity    = parts[2].trim()
                root.wind        = parts[3].trim()
            }
        }
    }

    Component.onCompleted: refresh()
    Timer { interval: 30 * 60 * 1000; repeat: true; running: true; onTriggered: root.refresh() }

    // ── Ícone simplificado a partir da condição textual ──────────────────────
    readonly property string icon: {
        var c = root.condition.toLowerCase()
        if (c.indexOf("thunder") >= 0)                          return "\uf0e7"
        if (c.indexOf("snow") >= 0 || c.indexOf("sleet") >= 0)  return "\uf2dc"
        if (c.indexOf("rain") >= 0 || c.indexOf("drizzle") >= 0) return "\uf73d"
        if (c.indexOf("fog") >= 0 || c.indexOf("mist") >= 0)    return "\uf74e"
        if (c.indexOf("overcast") >= 0 || c.indexOf("cloud") >= 0) return "\uf0c2"
        if (c.indexOf("clear") >= 0 || c.indexOf("sunny") >= 0) return "\uf185"
        return "\uf185"
    }

    implicitHeight: root.compact ? 54 : 64

    Rectangle {
        anchors.fill: parent
        radius: 12
        color: Qt.rgba(1, 1, 1, 0.07)

        RowLayout {
            anchors.fill: parent
            anchors.margins: root.compact ? 8 : 10
            spacing: root.compact ? 6 : 10

            Text {
                text: root.icon
                color: root.colorAccent
                font.pixelSize: root.compact ? 16 : 22
                font.family: "JetBrainsMono Nerd Font"
                visible: !root.loading && !root.hasError
            }

            ColumnLayout {
                Layout.fillWidth: true; spacing: 2

                Text {
                    visible: root.loading
                    text: "Carregando…"
                    color: root.colorTextDim; font.pixelSize: root.compact ? 9 : 10
                }
                Text {
                    visible: root.hasError && !root.loading
                    text: "Indisponível"
                    color: root.colorTextDim; font.pixelSize: root.compact ? 9 : 10
                }
                Text {
                    visible: !root.loading && !root.hasError
                    text: root.temperature
                    color: root.colorText
                    font.pixelSize: root.compact ? 13 : 15; font.weight: Font.Medium
                }
                Text {
                    visible: !root.loading && !root.hasError && !root.compact
                    Layout.fillWidth: true
                    text: root.condition
                    color: root.colorTextDim
                    font.pixelSize: 9; elide: Text.ElideRight
                }
            }

            Text {
                visible: !root.loading && !root.compact
                text: "\uf021"   // refresh
                color: root.colorTextDim
                font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
                opacity: 0.6
                MouseArea {
                    anchors.fill: parent; anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.refresh()
                }
            }
        }
    }
}
