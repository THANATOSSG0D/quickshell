import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── QuickSettingsPopup ───────────────────────────────────────────────────────
// PopupWindow para o Quick Settings, seguindo a mesma estrutura do ClockPopup.

PopupWindow {
    id: popup

    property int popupW: 320
    property int popupH: 540

    property color colorPanelBg:    "#1f1f1f"
    property color colorText:       "#e2e2e2"
    property color colorTextDim:    "#c6c6c6"
    property color colorAccent:     "#ffb4a9"
    property color colorMuted:      "#cf6679"
    property color colorProgressBg: "#474747"
    property color colorDivider:    "#474747"

    color:         "transparent"
    implicitWidth:  popupW
    implicitHeight: popupH

    property bool panelOpen: false
    property real slideProgress: 0.0

    visible: slideProgress > 0.0

    signal closeRequested()

    HyprlandFocusGrab {
        windows:   [ popup ]
        active:    popup.panelOpen
        onCleared: popup.closeRequested()
    }

    Behavior on slideProgress {
        NumberAnimation { duration: 280; easing.type: Easing.OutCubic }
    }
    
    onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

    Rectangle {
        anchors.fill: parent
        radius:  12
        opacity: Math.min(1.0, popup.slideProgress * 2)
        color:   Qt.rgba(popup.colorPanelBg.r, popup.colorPanelBg.g, popup.colorPanelBg.b, 0.95)

        QuickSettingsContent {
            anchors.fill:    parent
            panelOpen:       popup.panelOpen
            colorPanelBg:    popup.colorPanelBg
            colorText:       popup.colorText
            colorTextDim:    popup.colorTextDim
            colorAccent:     popup.colorAccent
            colorMuted:      popup.colorMuted
            colorProgressBg: popup.colorProgressBg
            colorDivider:    popup.colorDivider
            onCloseRequested: popup.closeRequested()
        }
    }
}
