import QtQuick
import '../../../wallpaper'

// TabWallpaper — wrapper para o módulo Wallpaper no ConfigWindow.
//
// Delega para WallpaperContent com showTabBar: false, pois o ConfigWindow
// já renderiza as subtabs na sua barra superior.
//
// activeSubtab (int) → activeTab (string):
//   0 → "wallpaper" | 1 → "matugen" | 2 → "profiles"
//   3 → "history"   | 4 → "schedule"

Item {
  id: root

  required property bool  panelOpen
  required property int   activeSubtab
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider

  readonly property var _tabIds: [
    "wallpaper", "matugen", "profiles", "history", "schedule"
  ]

  WallpaperContent {
    anchors.fill: parent
    panelOpen:    root.panelOpen
    colorText:    root.colorText
    colorTextDim: root.colorTextDim
    colorAccent:  root.colorAccent
    colorDivider: root.colorDivider
    activeTab:    root._tabIds[root.activeSubtab] ?? "wallpaper"
    showTabBar:   false
  }
}
