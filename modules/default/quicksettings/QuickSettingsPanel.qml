import Quickshell
import Quickshell.Hyprland
import QtQuick
import "./components" as QsComp

// ── QuickSettingsPanel ───────────────────────────────────────────────────────
// PanelWindow que hospeda o QuickSettingsContent.
// Segue exatamente os padrões de animação, ancoragem e cores do VolumePanel.
//
// Propriedades obrigatórias do host:
//   barScreen, barPosition (1=top 2=right 3=bottom 4=left), barSize, barMargin
//
// Controle: defina panelOpen = true/false para abrir/fechar.
// Conecte onCloseRequested() para reagir ao fechamento por perda de foco.
PanelWindow {
    id: panel

    // ── Propriedades obrigatórias ──────────────────────────────────────────
    required property var barScreen
    required property int barPosition   // 1=top 2=right 3=bottom 4=left
    required property int barSize       // espessura da barra em px
    required property int barMargin     // margem entre barra e painel

    // ── Cores injetadas ────────────────────────────────────────────────────
    property color colorPanelBg:    "#1f1f1f"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    // ── Dimensões fixas do painel ──────────────────────────────────────────
    readonly property int panelW: 320
    readonly property int panelH: 620

    // ── Configuração da janela ─────────────────────────────────────────────
    screen:        barScreen
    color:         "transparent"
    exclusionMode: ExclusionMode.Ignore

    readonly property bool barIsHorizontal: barPosition === 1 || barPosition === 3

    // Ancoragem: o painel aparece no lado oposto à barra (ex.: barra no topo → painel no topo)
    anchors.top:    barPosition === 1
    anchors.bottom: barPosition === 3
    anchors.left:   barPosition === 4
    anchors.right:  barPosition === 2

    implicitWidth:  barIsHorizontal ? panelW : 1
    implicitHeight: barIsHorizontal ? 1      : panelH

    // Padding lateral para centralizar o painel na tela
    property int sidePad: barIsHorizontal
        ? Math.max(0, Math.floor((barScreen.width  - panelW) / 2))
        : Math.max(0, Math.floor((barScreen.height - panelH) / 2))

    margins.top:    barPosition === 1 ? barMargin + barSize : sidePad
    margins.bottom: barPosition === 3 ? barMargin + barSize : sidePad
    margins.left:   barPosition === 4 ? barMargin + barSize : sidePad
    margins.right:  barPosition === 2 ? barMargin + barSize : sidePad

    // ── Estado de abertura ─────────────────────────────────────────────────
    property bool panelOpen: false
    property real slideProgress: 0.0

    signal closeRequested()

    // ── Animação de abertura (idêntica ao VolumePanel) ─────────────────────
    visible: slideProgress > 0.0

    Behavior on slideProgress {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }
    onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

    // ── Foco Hyprland ──────────────────────────────────────────────────────
    HyprlandFocusGrab {
        windows:   [ panel ]
        active:    panel.panelOpen && !qsPanelContent.trayMenuOpen
        onCleared: if (!qsPanelContent.trayMenuOpen) panel.closeRequested()
    }

    // ── Container com clip e animação de slide ─────────────────────────────
    Item {
        id: clipContainer
        clip:    true
        opacity: Math.min(1.0, panel.slideProgress * 2)

        // Ancora no lado da barra para que o slide cresça a partir dela
        anchors.top:    barPosition === 1 ? parent.top    : undefined
        anchors.bottom: barPosition === 3 ? parent.bottom : undefined
        anchors.left:   barPosition === 4 ? parent.left   : undefined
        anchors.right:  barPosition === 2 ? parent.right  : undefined

        width: {
            if (barPosition === 2 || barPosition === 4)
                return parent.width * panel.slideProgress
            return parent.width
        }
        height: {
            if (barPosition === 1 || barPosition === 3)
                return parent.height * panel.slideProgress
            return parent.height
        }

        // ── Fundo arredondado ──────────────────────────────────────────
        Rectangle {
            anchors.fill: parent
            radius: 12
            color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g,
                           panel.colorPanelBg.b, 0.95)
        }

        // ── Retângulo sem radius no lado que encosta na barra ──────────
        // Evita a borda arredondada que ficaria visível colada à barra.
        Rectangle {
            color: Qt.rgba(panel.colorPanelBg.r, panel.colorPanelBg.g,
                           panel.colorPanelBg.b, 0.95)
            anchors.top:    barPosition === 1 ? parent.top
                          : panel.barIsHorizontal ? parent.top : undefined
            anchors.bottom: barPosition === 3 ? parent.bottom
                          : panel.barIsHorizontal ? parent.bottom : undefined
            anchors.left:   barPosition === 4 ? parent.left
                          : !panel.barIsHorizontal ? parent.left : undefined
            anchors.right:  barPosition === 2 ? parent.right
                          : !panel.barIsHorizontal ? parent.right : undefined
            width:  barPosition === 2 || barPosition === 4 ? 12 : parent.width
            height: barPosition === 1 || barPosition === 3 ? 12 : parent.height
        }

        // ── Conteúdo ───────────────────────────────────────────────────
        QuickSettingsContent {
            id: qsPanelContent
            anchors.fill:    parent
            panelOpen:       panel.panelOpen
            parentWindow:    panel
            colorPanelBg:    panel.colorPanelBg
            colorText:       panel.colorText
            colorTextDim:    panel.colorTextDim
            colorAccent:     panel.colorAccent
            colorMuted:      panel.colorMuted
            colorProgressBg: panel.colorProgressBg
            colorDivider:    panel.colorDivider
            onCloseRequested: panel.closeRequested()
        }
    }
}
