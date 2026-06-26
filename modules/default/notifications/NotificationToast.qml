import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import qs

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
    // Antes eram hardcoded aqui (340/12/8), sem nenhuma config exposta na
    // aba. Agora a fonte de verdade é o service (mesmo padrão de toastPosition
    // logo abaixo), assim a aba Notificações controla isso de fato.
    readonly property int toastWidth:   service.toastWidth
    readonly property int toastMargin:  service.toastMargin
    readonly property int toastSpacing: service.toastSpacing

    // Cores — antes eram um esquema Catppuccin hardcoded, totalmente
    // desconectado da paleta matugen (Colors) que move o resto do shell.
    // Agora usam os mesmos tokens que os popups usam por padrão
    // (Colors.surface_container / on_surface / ...), então o toast já
    // nasce no tom certo do tema atual e acompanha a troca de wallpaper.
    // Continuam sendo "property color" comuns — quem instanciar o toast
    // ainda pode sobrescrever via BarSchema/PopupConfig se quiser.
    property color colorBg:      Colors.surface_container
    property color colorText:    Colors.on_surface
    property color colorTextDim: Colors.on_surface_variant
    property color colorAccent:  Colors.primary
    property color colorMuted:   Colors.error
    property color colorDivider: Colors.outline_variant

    // Sombra — lida do PopupConfig.globals (mesma fonte que o BarPopup usa),
    // assim o toast continua combinando com a sombra dos outros popups.
    // O raio do card agora vem de service.cardRadius (ver mais abaixo),
    // não mais de um bgRadius global separado — assim o slider "Raio dos
    // cards" da aba afeta painel E toast com o mesmo valor.
    readonly property bool  _shadowEnabled: PopupConfig.get(null, "shadowEnabled", true)
    readonly property real  _shadowBlur:    PopupConfig.get(null, "shadowBlur",    16)
    readonly property int   _shadowOffX:    PopupConfig.get(null, "shadowOffsetX", 0)
    readonly property int   _shadowOffY:    PopupConfig.get(null, "shadowOffsetY", 4)
    readonly property real  _shadowOpacity: PopupConfig.get(null, "shadowOpacity", 0.45)

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

    visible: service.toasts.count > 0 && !service.silenceMode

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
                image:      modelData.image
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
                cardRadius:   root.service.cardRadius

                onDismissed:     (id) => root.service.dismissToast(id)
                onActionInvoked: (id, identifier) => root.service.invokeAction(id, identifier)

                // Pausa o timeout de expiração enquanto o mouse está sobre
                // o toast — antes ele podia expirar embaixo do cursor
                // enquanto você ainda estava lendo ou prestes a clicar
                // numa ação.
                onHoveredChanged: root.service.setToastPaused(modelData.id, hovered)
            }

            // Sombra — mesma fonte de config (PopupConfig.globals) usada pelos
            // popups via BarPopup, então o toast deixa de ser o único elemento
            // "chapado" sem profundidade quando o resto do shell tem sombra.
            MultiEffect {
                anchors.fill:           item
                source:                 item
                visible:                root._shadowEnabled
                shadowEnabled:          root._shadowEnabled
                shadowBlur:             root._shadowBlur / 64
                shadowHorizontalOffset: root._shadowOffX
                shadowVerticalOffset:   root._shadowOffY
                shadowColor: Qt.rgba(0, 0, 0, root._shadowOpacity)
                z: -1
            }
        }
    }
}
