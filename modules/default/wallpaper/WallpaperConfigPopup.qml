import Quickshell
import QtQuick
import "../bar" as Bar

// ── WallpaperConfigPopup ──────────────────────────────────────────────────────
// Popup de configuração de wallpaper — herda Bar.BarPopup.
// barRef injetado por Bar.qml (mesmo padrão do QuickSettingsPopup).
//
// Uso em Bar.qml:
//   WallpaperConfigPopup {
//     id: wallpaperConfigPopup
//     barRef:     barWindow
//     panelOpen:  barState.wallpaperConfigOpen
//     colorText:  barColors.text
//     colorAccent: barColors.accent
//     ...
//     onCloseRequested: barState.wallpaperConfigOpen = false
//   }

Bar.BarPopup {
  id: popup

  popupW:      480
  popupH:      620
  bgRadius:    14
  animDuration: 220

  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#888888"
  property color colorAccent:     "#ffb4a9"
  property color colorDivider:    "#333333"

  // Aba inicial (pode ser sobrescrito pelo caller)
  property string initialTab: "wallpaper"

  onPanelOpenChanged: {
    if (panelOpen) content.activeTab = initialTab
  }

  WallpaperConfigContent {
    id: content
    anchors.fill:  parent
    panelOpen:     popup.panelOpen
    colorPanelBg:  popup.colorPanelBg
    colorText:     popup.colorText
    colorTextDim:  popup.colorTextDim
    colorAccent:   popup.colorAccent
    colorDivider:  popup.colorDivider
    onCloseRequested: popup.closeRequested()
  }
}
