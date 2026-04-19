import QtQuick
import QtQuick.Layouts

// ── NotificationItem ──────────────────────────────────────────────────────────
// Card de notificação individual. Usado tanto nos toasts flutuantes quanto
// na lista do painel de notificações.
//
// mode: "toast" (compacto, sem scroll) | "panel" (completo)
// urgency: 0=low, 1=normal, 2=critical

Item {
    id: root

    // ── Dados ──────────────────────────────────────────────────────────────
    property string appName:  ""
    property string appIcon:  ""
    property string summary:  ""
    property string body:     ""
    property int    urgency:  1
    property var    actions:  []
    property int    notifId:  -1
    property real   timestamp: 0

    // ── Modo ───────────────────────────────────────────────────────────────
    property string mode: "toast"   // "toast" | "panel"

    // ── Cores ──────────────────────────────────────────────────────────────
    property color colorBg:      "#1e1e2e"
    property color colorText:    "#cdd6f4"
    property color colorTextDim: "#9399b2"
    property color colorAccent:  "#89b4fa"
    property color colorMuted:   "#f38ba8"
    property color colorDivider: "#313244"

    // Urgency → cor de destaque da borda esquerda
    readonly property color urgencyColor: {
        if (urgency >= 2) return colorMuted      // crítico: vermelho
        if (urgency === 0) return colorTextDim   // baixo: cinza
        return colorAccent                        // normal: accent
    }

    // ── Sinais ─────────────────────────────────────────────────────────────
    signal dismissed(int id)
    signal actionInvoked(int id, string identifier)

    // ── Dimensões ──────────────────────────────────────────────────────────
    implicitWidth:  parent ? parent.width : 300
    implicitHeight: card.implicitHeight

    // ── Animação de entrada ────────────────────────────────────────────────
    property bool _visible: false
    opacity: _visible ? 1.0 : 0.0
    transform: Translate { y: _visible ? 0 : (mode === "toast" ? -8 : 4) }

    Behavior on opacity   { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on transform { }   // via Translate — sem Behavior nativa; controlado pelo opacity

    Component.onCompleted: Qt.callLater(function() { _visible = true })

    // ── Card ───────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.left:  parent.left
        anchors.right: parent.right
        radius: 10
        color:  Qt.rgba(root.colorBg.r, root.colorBg.g, root.colorBg.b, mode === "toast" ? 0.94 : 0.85)

        implicitHeight: col.implicitHeight + 16

        // Borda esquerda colorida por urgência
        Rectangle {
            anchors.left:   parent.left
            anchors.top:    parent.top
            anchors.bottom: parent.bottom
            anchors.topMargin:    4
            anchors.bottomMargin: 4
            width:  3
            radius: 2
            color:  root.urgencyColor
        }

        // Linha inferior (separador quando mode=panel)
        Rectangle {
            visible:        mode === "panel"
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height:         1
            color:          root.colorDivider
            opacity:        0.4
        }

        Column {
            id: col
            anchors {
                left:   parent.left
                right:  parent.right
                top:    parent.top
                leftMargin:  14
                rightMargin: 10
                topMargin:   10
            }
            spacing: 4

            // ── Header: ícone + appName + horário + fechar ─────────────────
            RowLayout {
                width: parent.width
                spacing: 6

                // Ícone do app (fallback para ícone genérico)
                Text {
                    text: {
                        if (root.appIcon === "") return "\uf0f3"
                        // Ícone por nome de app (fallback simples)
                        var icons = {
                            "firefox": "\uf269", "chromium": "\uf268",
                            "discord": "\uf392", "telegram": "\uf2c6",
                            "spotify": "\uf1bc", "vlc": "\uf03d",
                            "code": "\ue70c", "terminal": "\uf120",
                            "nautilus": "\uf07c", "thunar": "\uf07c",
                            "thunderbird": "\uf0e0", "evolution": "\uf0e0",
                            "gimp": "\uf1fc", "inkscape": "\uf1fc",
                        }
                        var lower = root.appName.toLowerCase()
                        for (var k in icons) {
                            if (lower.includes(k)) return icons[k]
                        }
                        return "\uf0f3"
                    }
                    font.family:    "JetBrainsMono Nerd Font"
                    font.pixelSize: 13
                    color:          root.urgencyColor
                }

                // Nome do app
                Text {
                    text:            root.appName || "Notificação"
                    font.pixelSize:  11
                    font.weight:     Font.Medium
                    color:           root.colorTextDim
                    elide:           Text.ElideRight
                    Layout.fillWidth: true
                }

                // Horário relativo
                Text {
                    text:           _relativeTime(root.timestamp)
                    font.pixelSize: 10
                    color:          Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.6)

                    Timer {
                        interval: 30000
                        repeat:   true
                        running:  true
                        onTriggered: parent.text = _relativeTime(root.timestamp)
                    }
                }

                // Botão fechar
                Item {
                    width: 20
                    height: 20

                    Text {
                        anchors.centerIn: parent
                        text:           "\uf00d"
                        font.family:    "JetBrainsMono Nerd Font"
                        font.pixelSize: 10
                        color:          closeArea.containsMouse
                                        ? root.colorText
                                        : Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.5)
                    }

                    MouseArea {
                        id: closeArea
                        anchors.fill:    parent
                        hoverEnabled:    true
                        onClicked:       root.dismissed(root.notifId)
                        cursorShape:     Qt.PointingHandCursor
                    }
                }
            }

            // ── Summary ────────────────────────────────────────────────────
            Text {
                visible:        root.summary !== ""
                width:          parent.width
                text:           root.summary
                font.pixelSize: 13
                font.weight:    Font.DemiBold
                color:          root.colorText
                wrapMode:       Text.WordWrap
                maximumLineCount: mode === "toast" ? 2 : 5
                elide:          Text.ElideRight
            }

            // ── Body ───────────────────────────────────────────────────────
            Text {
                visible:          root.body !== "" && !(mode === "toast" && root.summary !== "" && root.body.length > 120)
                width:            parent.width
                text:             root.body
                font.pixelSize:   12
                color:            root.colorTextDim
                wrapMode:         Text.WordWrap
                maximumLineCount: mode === "toast" ? 3 : 8
                elide:            Text.ElideRight
            }

            // ── Ações ──────────────────────────────────────────────────────
            Row {
                visible:    root.actions.length > 0 && mode === "panel"
                spacing:    6
                topPadding: 2

                Repeater {
                    model: root.actions

                    Rectangle {
                        required property var modelData
                        height:  26
                        width:   Math.min(actionLabel.implicitWidth + 16, 120)
                        radius:  6
                        color:   actionArea.containsMouse
                                 ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.20)
                                 : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.10)

                        Text {
                            id:             actionLabel
                            anchors.centerIn: parent
                            text:           modelData.text || modelData.identifier
                            font.pixelSize: 11
                            font.weight:    Font.Medium
                            color:          root.colorAccent
                            elide:          Text.ElideRight
                            width:          parent.width - 12
                            horizontalAlignment: Text.AlignHCenter
                        }

                        MouseArea {
                            id:          actionArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape:  Qt.PointingHandCursor
                            onClicked:    root.actionInvoked(root.notifId, modelData.identifier)
                        }
                    }
                }
            }

            // Padding inferior
            Item { height: 4; width: 1 }
        }
    }

    // ── Helper: tempo relativo ─────────────────────────────────────────────
    function _relativeTime(ts) {
        if (!ts) return ""
        var diff = Math.floor((Date.now() - ts) / 1000)
        if (diff < 10)  return "agora"
        if (diff < 60)  return diff + "s"
        if (diff < 3600) return Math.floor(diff / 60) + "m"
        if (diff < 86400) return Math.floor(diff / 3600) + "h"
        return Math.floor(diff / 86400) + "d"
    }
}
