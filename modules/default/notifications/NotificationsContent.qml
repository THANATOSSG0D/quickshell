import Quickshell
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ── NotificationsContent ──────────────────────────────────────────────────────
// Conteúdo completo do centro de notificações (tipo SwayNC).
// Pode ser embutido em PopupWindow, PanelWindow ou qualquer container.

Item {
    id: root

    // ── Injeções obrigatórias ──────────────────────────────────────────────
    property var service: null   // NotificationService

    // ── Cores ──────────────────────────────────────────────────────────────
    property color colorPanelBg:  "#1e1e2e"
    property color colorText:     "#cdd6f4"
    property color colorTextDim:  "#9399b2"
    property color colorAccent:   "#89b4fa"
    property color colorMuted:    "#f38ba8"
    property color colorDivider:  "#313244"

    // ── Sinais ─────────────────────────────────────────────────────────────
    signal closeRequested()

    // ── Filtro de urgência ─────────────────────────────────────────────────
    // 0=todas, 2=somente críticas
    property int urgencyFilter: 0

    // ── Conteúdo ───────────────────────────────────────────────────────────
    Column {
        id: layout
        anchors.fill: parent
        spacing: 0

        // ── Cabeçalho ──────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: 52

            RowLayout {
                anchors {
                    fill:        parent
                    leftMargin:  16
                    rightMargin: 12
                }
                spacing: 8

                // Título + contagem
                Row {
                    spacing: 8
                    Layout.fillWidth: true

                    Text {
                        text:           "\uf0f3"
                        font.family:    "JetBrainsMono Nerd Font"
                        font.pixelSize: 15
                        color:          root.service && root.service.doNotDisturb
                                        ? root.colorMuted : root.colorAccent
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Text {
                        text:           "Notificações"
                        font.pixelSize: 14
                        font.weight:    Font.DemiBold
                        color:          root.colorText
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Badge de não lidas
                    Rectangle {
                        visible:        root.service && root.service.unreadCount > 0
                        width:          Math.max(18, countLabel.implicitWidth + 8)
                        height:         18
                        radius:         9
                        color:          root.colorAccent
                        anchors.verticalCenter: parent.verticalCenter

                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text:           root.service ? root.service.unreadCount : 0
                            font.pixelSize: 10
                            font.weight:    Font.Bold
                            color:          root.colorPanelBg
                        }
                    }
                }

                // ── Botão DND ──────────────────────────────────────────────
                HeaderBtn {
                    icon:    root.service && root.service.doNotDisturb ? "\uf1f6" : "\uf0f3"
                    tooltip: root.service && root.service.doNotDisturb ? "Retomar notificações" : "Não perturbe"
                    active:  root.service && root.service.doNotDisturb
                    colorBg: root.service && root.service.doNotDisturb
                             ? Qt.rgba(root.colorMuted.r, root.colorMuted.g, root.colorMuted.b, 0.18)
                             : Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.10)
                    colorIcon: root.service && root.service.doNotDisturb ? root.colorMuted : root.colorTextDim
                    onClicked:  root.service && root.service.toggleDnd()
                }

                // ── Botão posição ──────────────────────────────────────────
                HeaderBtn {
                    icon:    "\uf108"
                    tooltip: "Posição dos toasts"
                    onClicked: posMenu.visible = !posMenu.visible
                }

                // ── Botão limpar tudo ──────────────────────────────────────
                HeaderBtn {
                    icon:      "\uf1f8"
                    tooltip:   "Limpar todas"
                    colorIcon: root.colorTextDim
                    onClicked: root.service && root.service.clearAll()
                }

                // ── Fechar painel ──────────────────────────────────────────
                HeaderBtn {
                    icon:      "\uf00d"
                    colorIcon: root.colorTextDim
                    onClicked: root.closeRequested()
                }
            }

            // Divider
            Rectangle {
                anchors.bottom: parent.bottom
                width:  parent.width
                height: 1
                color:  root.colorDivider
                opacity: 0.5
            }
        }

        // ── Filtro de prioridade ───────────────────────────────────────────
        Row {
            width:   parent.width
            height:  36
            padding: 8
            spacing: 6

            Repeater {
                model: [
                    { label: "Todas",    filter: 0 },
                    { label: "Normais",  filter: 1 },
                    { label: "Críticas", filter: 2 }
                ]

                delegate: Rectangle {
                    required property var  modelData
                    required property int  index
                    height:  20
                    width:   lbl.implicitWidth + 14
                    radius:  10
                    anchors.verticalCenter: parent.verticalCenter

                    color: root.urgencyFilter === modelData.filter
                           ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.20)
                           : "transparent"

                    Text {
                        id: lbl
                        anchors.centerIn: parent
                        text:           modelData.label
                        font.pixelSize: 11
                        color:          root.urgencyFilter === modelData.filter
                                        ? root.colorAccent : root.colorTextDim
                    }

                    MouseArea {
                        anchors.fill:  parent
                        cursorShape:   Qt.PointingHandCursor
                        onClicked:     root.urgencyFilter = modelData.filter
                    }
                }
            }
        }

        // Divider filtro
        Rectangle {
            width:   parent.width
            height:  1
            color:   root.colorDivider
            opacity: 0.3
        }

        // ── Lista ──────────────────────────────────────────────────────────
        Item {
            width:  parent.width
            height: layout.height - 52 - 36 - 1 - 1   // restante disponível

            // Estado vazio
            Column {
                visible: !root.service || root.service.notifications.count === 0
                anchors.centerIn: parent
                spacing: 10

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "\uf0f3"
                    font.family:    "JetBrainsMono Nerd Font"
                    font.pixelSize: 36
                    color:          Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
                }

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text:           "Nenhuma notificação"
                    font.pixelSize: 13
                    color:          Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.4)
                }
            }

            // Lista com scroll
            ListView {
                id: notifList
                visible:        root.service && root.service.notifications.count > 0
                anchors.fill:   parent
                anchors.topMargin: 4
                clip:           true
                spacing:        0
                model:          root.service ? root.service.notifications : null

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        radius:  3
                        implicitWidth: 4
                        color: Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
                    }
                }

                delegate: Item {
                    id: notifDelegate
                    required property var  modelData
                    required property int  index

                    // Filtro de urgência
                    visible: root.urgencyFilter === 0
                             || modelData.urgency === root.urgencyFilter
                    height:  visible ? item.implicitHeight + 2 : 0

                    width: notifList.width - 16
                    x:     8

                    NotificationItem {
                        id: item
                        width:      parent.width
                        mode:       "panel"
                        notifId:    modelData.id
                        appName:    modelData.appName
                        appIcon:    modelData.appIcon
                        summary:    modelData.summary
                        body:       modelData.body
                        urgency:    modelData.urgency
                        actions:    modelData.actions ?? []
                        timestamp:  modelData.timestamp

                        colorBg:      root.colorPanelBg
                        colorText:    root.colorText
                        colorTextDim: root.colorTextDim
                        colorAccent:  root.colorAccent
                        colorMuted:   root.colorMuted
                        colorDivider: root.colorDivider

                        onDismissed:     (id) => root.service.dismissNotification(id)
                        onActionInvoked: (id, ident) => root.service.dismissNotification(id)
                    }
                }

                // Padding inferior
                footer: Item { height: 8 }
            }
        }
    }

    // ── Menu de posição de toasts ──────────────────────────────────────────
    Rectangle {
        id: posMenu
        visible:  false
        z:        10
        anchors {
            top:   parent.top
            right: parent.right
            topMargin:   52
            rightMargin: 8
        }
        width:  160
        radius: 8
        color:  Qt.rgba(root.colorPanelBg.r, root.colorPanelBg.g, root.colorPanelBg.b, 0.97)

        // Sombra via border
        border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.6)
        border.width: 1

        implicitHeight: posCol.implicitHeight + 12

        Column {
            id: posCol
            anchors { fill: parent; margins: 6 }
            spacing: 2

            Text {
                text:           "Posição dos toasts"
                font.pixelSize: 10
                font.weight:    Font.Medium
                color:          root.colorTextDim
                leftPadding:    6
                topPadding:     2
                bottomPadding:  4
            }

            Repeater {
                model: [
                    { label: "↖  Superior esquerdo",   value: "top-left"      },
                    { label: "↑  Superior centro",      value: "top-center"    },
                    { label: "↗  Superior direito",     value: "top-right"     },
                    { label: "↙  Inferior esquerdo",    value: "bottom-left"   },
                    { label: "↓  Inferior centro",      value: "bottom-center" },
                    { label: "↘  Inferior direito",     value: "bottom-right"  }
                ]

                delegate: Rectangle {
                    required property var  modelData
                    width:   parent.width
                    height:  28
                    radius:  6
                    color: {
                        if (root.service && root.service.toastPosition === modelData.value)
                            return Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                        return hovered.containsMouse
                               ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.08)
                               : "transparent"
                    }

                    Text {
                        anchors { verticalCenter: parent.verticalCenter; left: parent.left; leftMargin: 8 }
                        text:           modelData.label
                        font.pixelSize: 12
                        color:          root.service && root.service.toastPosition === modelData.value
                                        ? root.colorAccent : root.colorText
                    }

                    MouseArea {
                        id:          hovered
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape:  Qt.PointingHandCursor
                        onClicked: {
                            root.service && root.service.setPosition(modelData.value)
                            posMenu.visible = false
                        }
                    }
                }
            }
        }

        // Fechar ao clicar fora
        MouseArea {
            anchors.fill:  parent
            z:             -1
            propagateComposedEvents: true
            onClicked: { posMenu.visible = false; mouse.accepted = false }
        }
    }

    // ── Fechar menu ao perder foco ─────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        z:            -1
        enabled:      posMenu.visible
        propagateComposedEvents: true
        onClicked: { posMenu.visible = false; mouse.accepted = false }
    }

    // ── Componente interno: botão do cabeçalho ─────────────────────────────
    component HeaderBtn: Rectangle {
        id: hbtn
        property string icon:      ""
        property string tooltip:   ""
        property bool   active:    false
        property color  colorBg:   Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.10)
        property color  colorIcon: root.colorTextDim

        signal clicked()

        width:  28
        height: 28
        radius: 8
        color:  hbtnArea.containsMouse
                ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.15)
                : colorBg

        Behavior on color { ColorAnimation { duration: 100 } }

        Text {
            anchors.centerIn: parent
            text:           hbtn.icon
            font.family:    "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color:          hbtn.colorIcon
        }

        MouseArea {
            id:          hbtnArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    hbtn.clicked()
        }

        // Tooltip simples
        Rectangle {
            visible:    hbtnArea.containsMouse && hbtn.tooltip !== ""
            z:          20
            anchors {
                bottom:             parent.top
                horizontalCenter:   parent.horizontalCenter
                bottomMargin:       4
            }
            width:  ttText.implicitWidth + 12
            height: 22
            radius: 6
            color:  Qt.rgba(0.1, 0.1, 0.15, 0.95)

            Text {
                id: ttText
                anchors.centerIn: parent
                text:           hbtn.tooltip
                font.pixelSize: 10
                color:          root.colorText
            }
        }
    }
}
