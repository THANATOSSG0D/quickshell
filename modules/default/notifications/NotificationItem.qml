import QtQuick
import QtQuick.Layouts
import Quickshell
import "../bar/modules/delegates/IconLookup.js" as IconLookup

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
    // Imagem embutida (icon_data) — apps Electron/Chromium como o Vivaldi
    // costumam mandar a imagem assim em vez de um nome de ícone de tema,
    // então appIcon sozinho ficava vazio e o card caía sempre no glyph
    // genérico de sino.
    property string image:    ""
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
    property int   cardRadius:   10

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

    // Hover sutil no card inteiro — antes não havia nenhum feedback visual
    // ao passar o mouse além dos botões individuais, o que deixava o card
    // parecendo um bloco de texto estático em vez de algo interativo.
    property bool _hovered: false

    MouseArea {
        anchors.fill: card
        hoverEnabled: true
        propagateComposedEvents: true
        z: -1
        onContainsMouseChanged: root._hovered = containsMouse
        onPressed: (mouse) => mouse.accepted = false
    }

    // ── Card ───────────────────────────────────────────────────────────────
    Rectangle {
        id: card
        anchors.left:  parent.left
        anchors.right: parent.right
        radius: root.cardRadius
        color:  Qt.rgba(root.colorBg.r, root.colorBg.g, root.colorBg.b,
                         (mode === "toast" ? 0.94 : 0.85) + (root._hovered ? 0.06 : 0))
        border.color: Qt.rgba(1, 1, 1, root._hovered ? 0.10 : 0.0)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 120 } }
        Behavior on border.color { ColorAnimation { duration: 120 } }

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

                // Ícone do app — tenta o appIcon real (path ou nome de tema)
                // entregue pela notificação via DBus; cai para um glyph
                // genérico de sino só se nada resolver. Antes essa lógica
                // adivinhava o ícone por uma lista fixa de ~12 nomes de app,
                // então a maioria ficava sem ícone de verdade.
                Item {
                    width: 26; height: 26
                    anchors.verticalCenter: parent.verticalCenter

                    Rectangle {
                        anchors.fill: parent
                        radius: 7
                        color:  Qt.rgba(root.urgencyColor.r, root.urgencyColor.g, root.urgencyColor.b, 0.12)
                        visible: appIconImg.status !== Image.Ready
                    }

                    Image {
                        id: appIconImg
                        anchors.fill: parent
                        anchors.margins: appIconImg.status === Image.Ready ? 0 : 5
                        visible:      status === Image.Ready
                        fillMode:     Image.PreserveAspectFit
                        smooth:       true
                        asynchronous: true
                        source: {
                            // Prioridade: imagem embutida (icon_data, comum em
                            // apps web/Electron como o Vivaldi) > path direto >
                            // nome de ícone de tema > vazio (cai no glyph).
                            if (root.image !== "")
                                return root.image.startsWith("/") ? IconLookup.toFileUri(root.image) : root.image
                            if (root.appIcon === "") return ""
                            if (root.appIcon.startsWith("/"))
                                return IconLookup.toFileUri(root.appIcon)
                            if (root.appIcon.startsWith("file://") || root.appIcon.startsWith("image://"))
                                return root.appIcon
                            var paths = IconLookup.buildIconPaths(root.appIcon, "")
                            return paths.length > 0 ? paths[0] : ""
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        visible:        appIconImg.status !== Image.Ready
                        text:           "\uf0f3"
                        font.family:    "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                        color:          root.urgencyColor
                    }
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
            // Antes: visible só em mode === "panel" — toasts nunca mostravam
            // nenhum botão de ação, mesmo quando a notificação tinha (ex:
            // "Responder", "Marcar como lida", os botões -A do notify-send).
            Row {
                visible:    root.actions && root.actions.length > 0
                spacing:    6
                topPadding: 2

                Repeater {
                    model: root.actions

                    Rectangle {
                        required property var modelData
                        height:  mode === "toast" ? 24 : 26
                        width:   Math.min(actionLabel.implicitWidth + 16, 130)
                        radius:  6
                        color:   actionArea.containsMouse
                                 ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                                 : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
                        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25)
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 80 } }

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
