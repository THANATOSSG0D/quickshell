import Quickshell
import Quickshell.Hyprland
import QtQuick

// ── DmenuPanel ────────────────────────────────────────────────────────────────
// PanelWindow layer-shell que exibe o DmenuContent.
// Aparece ao centro do topo do monitor, exatamente como o rofi (north + center).
//
// Uso mínimo:
//   DmenuPanel {
//     id: dmenu
//     screen: Quickshell.screens[0]
//     entries: ["bash", "kitty", "firefox"]
//     prompt: "RUN"
//     onAccepted: (text) => console.log("run:", text)
//   }
//   // abrir:  dmenu.open()
//   // fechar: dmenu.close()

PanelWindow {
  id: panel

  // ── API pública ────────────────────────────────────────────────────────────
  required property var screen

  property var    entries:     []
  property string prompt:      ">"
  property string placeholder: "pesquisar..."
  property int    maxVisible:  12
  property string filterMode:  "internal"

  // ── Cores ─────────────────────────────────────────────────────────────────
  property color colorPanelBg:  "#1f1f1f"
  property color colorText:     "#e2e2e2"
  property color colorTextDim:  "#c6c6c6"
  property color colorAccent:   "#ffb4a9"
  property color colorSelected: "#442926"
  property color colorDivider:  "#474747"
  property color colorInputBg:  "#131313"

  // ── Sinais ─────────────────────────────────────────────────────────────────
  signal accepted(string text)
  signal dismissed()
  signal textChanged(string t)

  // ── Métodos públicos ───────────────────────────────────────────────────────
  function open()  { panelOpen = true  }
  function close() { panelOpen = false }
  function toggle() { panelOpen = !panelOpen }

  // ── Dimensões ─────────────────────────────────────────────────────────────
  // Largura fixa, altura dinâmica conforme maxVisible
  readonly property int  _itemH:   32
  readonly property int  _inputH:  40
  readonly property int  _gap:     6
  readonly property int  _padV:    12
  readonly property int  _panelW:  720
  readonly property int  _panelH:  _inputH + _gap + (_itemH * Math.min(maxVisible, Math.max(entries.length, 1))) + _padV * 2 + 8

  // Offset do topo (equivalente ao y-offset: 65px do rofi)
  property int topOffset: 65

  // ── Posicionamento: topo, centrado horizontalmente ─────────────────────────
  screen: panel.screen
  color:  "transparent"
  exclusionMode: ExclusionMode.Ignore

  anchors.top:   true
  anchors.left:  true
  anchors.right: true

  implicitWidth:  1        // layer-shell horizontal stretch
  implicitHeight: _panelH + topOffset

  // Sem margens — o container interno faz o posicionamento
  margins.top:    0
  margins.left:   0
  margins.right:  0
  margins.bottom: 0

  // ── Estado de abertura ────────────────────────────────────────────────────
  property bool panelOpen: false
  property real slideProgress: 0.0

  visible: slideProgress > 0.0

  Behavior on slideProgress {
    NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
  }
  onPanelOpenChanged: slideProgress = panelOpen ? 1.0 : 0.0

  // ── FocusGrab ─────────────────────────────────────────────────────────────
  HyprlandFocusGrab {
    windows: [ panel ]
    active:  panel.panelOpen
    onCleared: panel.dismissed()
  }

  // ── Container principal ───────────────────────────────────────────────────
  // Centralizado horizontalmente, com topOffset de topo
  Item {
    id: clipContainer
    clip:    true
    opacity: Math.min(1.0, panel.slideProgress * 2.5)

    // Centraliza horizontalmente na largura total do monitor
    x:      Math.round((panel.width  - panel._panelW) / 2)
    y:      panel.topOffset
    width:  panel._panelW
    height: panel._panelH * panel.slideProgress

    // Slide de cima para baixo
    transform: Translate {
      y: -(1.0 - panel.slideProgress) * 20
    }

    // ── Fundo com blur ────────────────────────────────────────────────────
    Rectangle {
      anchors.fill: parent
      radius: 12
      color: Qt.rgba(
        panel.colorPanelBg.r,
        panel.colorPanelBg.g,
        panel.colorPanelBg.b,
        0.92
      )

      // Borda sutil
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.06)
    }

    // ── Conteúdo ──────────────────────────────────────────────────────────
    DmenuContent {
      anchors {
        fill:         parent
        topMargin:    panel._padV
        bottomMargin: panel._padV
        leftMargin:   12
        rightMargin:  12
      }

      entries:     panel.entries
      prompt:      panel.prompt
      placeholder: panel.placeholder
      maxVisible:  panel.maxVisible
      filterMode:  panel.filterMode

      colorPanelBg: panel.colorPanelBg
      colorText:    panel.colorText
      colorTextDim: panel.colorTextDim
      colorAccent:  panel.colorAccent
      colorSelected: panel.colorSelected
      colorDivider: panel.colorDivider
      colorInputBg: panel.colorInputBg

      onAccepted:    (text) => { panel.accepted(text);   panel.close() }
      onDismissed:   { panel.dismissed();  panel.close() }
      onTextChanged: (t) => panel.textChanged(t)
    }
  }
}
