import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

// ── NotificationToast ─────────────────────────────────────────────────────────
// PanelWindow que exibe toasts flutuantes empilhados num canto da tela.
// Instanciar via Variants { model: Quickshell.screens } em shell.qml.
//
// Exemplo:
//   Variants {
//     model: Quickshell.screens
//     NotificationToast {
//       required property var modelData
//       screen:  modelData
//       service: notifService
//     }
//   }

PanelWindow {
    id: root

    // ── Obrigatório ────────────────────────────────────────────────────────
    required property var service   // NotificationService

    // ── Configuração ───────────────────────────────────────────────────────
    property int   toastWidth:  340
    property int   toastMargin: 12   // margem da borda da tela
    property int   toastSpacing: 8   // espaço entre toasts

    // Cores — seguem o mesmo padrão injetado do bar
    property color colorBg:      "#1e1e2e"
    property color colorText:    "#cdd6f4"
    property color colorTextDim: "#9399b2"
    property color colorAccent:  "#89b4fa"
    property color colorMuted:   "#f38ba8"
    property color colorDivider: "#313244"

    // ── Posição derivada do service ────────────────────────────────────────
    readonly property string pos:         service.toastPosition
    readonly property bool   atTop:       pos.startsWith("top")
    readonly property bool   atRight:     pos.endsWith("right")
    readonly property bool   atLeft:      pos.endsWith("left")
    readonly property bool   atCenter:    pos.endsWith("center")

    // ── PanelWindow config ─────────────────────────────────────────────────
    color:         "transparent"
    exclusionMode: ExclusionMode.Ignore

    WlrLayershell.layer:    WlrLayershell.Overlay
    WlrLayershell.keyboardFocus: WlrLayershell.None

    anchors.top:    atTop
    anchors.bottom: !atTop
    anchors.left:   atLeft
    anchors.right:  atRight

    // Para top-center / bottom-center ancoramos apenas vertical + margem lateral
    margins.top:    atTop    ? toastMargin : 0
    margins.bottom: !atTop   ? toastMargin : 0
    margins.left:   atLeft   ? toastMargin : atCenter ? (screen.width - toastWidth) / 2 : 0
    margins.right:  atRight  ? toastMargin : atCenter ? (screen.width - toastWidth) / 2 : 0

    implicitWidth:  toastWidth
    // Altura máxima: até 40% da tela para não cobrir tudo
    implicitHeight: Math.min(Math.round(screen.height * 0.4),
                             toastList.contentHeight + 2)

    visible: service.toasts.count > 0

    // ── Lista de toasts via ListView (suporta verticalLayoutDirection) ─────
    ListView {
        id: toastList
        anchors.fill: parent
        model:        root.service.toasts
        spacing:      root.toastSpacing
        clip:         false
        interactive:  false   // sem scroll — os toasts expiram sozinhos

        // Para posições bottom-*: toast mais recente aparece na base
        verticalLayoutDirection: root.atTop
                                 ? ListView.TopToBottom
                                 : ListView.BottomToTop

        delegate: Item {
            id: toastDelegate
            required property var  modelData
            required property int  index

            width:  toastList.width
            height: item.implicitHeight

            // Animação de entrada/saída
            property bool _alive: false
            opacity: _alive ? 1.0 : 0.0
            scale:   _alive ? 1.0 : 0.96

            Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on scale   { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            Component.onCompleted: Qt.callLater(function() { _alive = true })

            Connections {
                target: root.service
                function onToastRemoved(id) {
                    if (id === toastDelegate.modelData.id)
                        toastDelegate._alive = false
                }
            }

            NotificationItem {
                id: item
                width:      parent.width
                mode:       "toast"
                notifId:    modelData.id
                appName:    modelData.appName
                appIcon:    modelData.appIcon
                summary:    modelData.summary
                body:       modelData.body
                urgency:    modelData.urgency
                actions:    modelData.actions ?? []
                timestamp:  modelData.timestamp

                colorBg:      root.colorBg
                colorText:    root.colorText
                colorTextDim: root.colorTextDim
                colorAccent:  root.colorAccent
                colorMuted:   root.colorMuted
                colorDivider: root.colorDivider

                onDismissed:     (id) => root.service.dismissToast(id)
                onActionInvoked: (id, _identifier) => root.service.dismissToast(id)
            }
        }
    }
}
