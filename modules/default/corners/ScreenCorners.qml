import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland

// ScreenCorners — máscara decorativa arredondando os 4 cantos físicos do
// monitor. Puramente visual: layer Overlay, exclusiveZone 0, mask vazio
// (nunca captura clique/foco — passa tudo pra baixo).
//
// Config vem do BarConfig da barra principal (bar.configRef):
//   cornersEnabled        : bool
//   cornersRadius         : int
//   cornersMode           : "edge" | "bar" | "dock" | "both"
//   cornersOverFullscreen : bool — false (padrão) esconde os cantos
//                           enquanto há janela em fullscreen; true mantém
//                           sempre visível (a layer Overlay já garante que
//                           renderiza por cima do fullscreen no Hyprland —
//                           isto aqui só decide se QUEREMOS isso ou não).
Variants {
  id: root

  required property var configBar     // bar.configRef
  property var configDock: null       // dockBar.configRef (opcional, p/ modo "dock"/"both")

  // ── Detecção de fullscreen ────────────────────────────────────────────
  // Mesmo mecanismo que BarState.qml usa para autoHide/fullscreen peek:
  // escuta o rawEvent "fullscreen" do Hyprland (evento global, não traz o
  // monitor — por isso é tratado como estado único, igual ao BarState já
  // faz para a Bar/Dock).
  property bool _fullscreenActive: false

  property var _fsConn: Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event.name === "fullscreen")
        root._fullscreenActive = (event.data === "1")
    }
  }

  model: Quickshell.screens

  delegate: PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property bool _enabled: root.configBar ? root.configBar.cornersEnabled === true : false
    readonly property bool _overFs:  root.configBar ? root.configBar.cornersOverFullscreen === true : false

    visible: _enabled && (!root._fullscreenActive || _overFs)
    color:   "transparent"

    WlrLayershell.layer:         WlrLayershell.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.exclusiveZone: 0
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "corners"
    mask: Region {}   // input passthrough total — checar contra NotificationToast.qml
                       // se o projeto já tiver um padrão diferente pra isso

    anchors.top: true; anchors.bottom: true; anchors.left: true; anchors.right: true

    readonly property int    radius: root.configBar ? root.configBar.cornersRadius : 24
    readonly property string mode:   root.configBar ? root.configBar.cornersMode   : "edge"

    // 1=topo 2=direita 3=baixo 4=esquerda (mesma convenção do BarConfig.position)
    function edgeOffset(edgePos) {
      var off = 0
      if ((mode === "bar" || mode === "both") && root.configBar && root.configBar.panelEnabled
          && root.configBar.position === edgePos)
        off = Math.max(off, root.configBar.barSize + root.configBar.barMargin)
      if ((mode === "dock" || mode === "both") && root.configDock && root.configDock.panelEnabled
          && root.configDock.position === edgePos)
        off = Math.max(off, root.configDock.barSize + root.configDock.barMargin)
      return off
    }
    readonly property int offTop:    edgeOffset(1)
    readonly property int offRight:  edgeOffset(2)
    readonly property int offBottom: edgeOffset(3)
    readonly property int offLeft:   edgeOffset(4)

    CornerMask { corner: "topLeft";     size: win.radius; x: win.offLeft;                          y: win.offTop }
    CornerMask { corner: "topRight";    size: win.radius; x: win.width - win.radius - win.offRight; y: win.offTop }
    CornerMask { corner: "bottomLeft";  size: win.radius; x: win.offLeft;                          y: win.height - win.radius - win.offBottom }
    CornerMask { corner: "bottomRight"; size: win.radius; x: win.width - win.radius - win.offRight; y: win.height - win.radius - win.offBottom }
  }
}
