import Quickshell
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import 'delegates' as Comp

Item {
  id: root

  required property string monitorName
  property string style:       "dots"
  property string orientation: "horizontal"
  property string iconsSort:   "position"

  // ícones
  property bool  iconMonochrome:      false
  property color iconMonoColor:       "white"
  property color iconMonoColorActive: "red"
  property int   iconSpacing:         3

  // fundo global (container de todos os workspaces)
  property color bgColor:       "transparent"
  property real  bgOpacity:     0.0
  property color bgBorderColor: "transparent"
  property real  bgBorderWidth: 0
  property real  bgPaddingH:    12
  property real  bgPaddingV:    4

  // fundo individual da workspace ATIVA
  // bgColorActive.a == 0 (transparent) → sem fundo individual
  property color bgColorActive:       "transparent"
  property real  bgOpacityActive:     0.8
  property color bgBorderColorActive: "transparent"
  property real  bgBorderWidthActive: 0
  property real  bgPaddingHActive:    6
  property real  bgPaddingVActive:    2
  property real  bgRadiusActive:      99   // 99=pill, 4=rounded rect, 0=square

  // cores dos dots/números
  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.6)
  property color dotUrgentColor:   "#f38ba8"

  property bool showAddButton: true

  readonly property bool isHorizontal: orientation === "horizontal"

  implicitWidth:  isHorizontal ? bg.width  : bg.height
  implicitHeight: isHorizontal ? bg.height : bg.width

  // ── Lista de workspaces do monitor ───────────────────────────────────
  property var workspaces: {
    var result = []
    for (var i = 0; i < Hyprland.workspaces.values.length; i++) {
      var ws = Hyprland.workspaces.values[i]
      if (ws.id < 0) continue
      if (!ws.monitor || ws.monitor.name !== root.monitorName) continue
      result.push(ws)
    }
    result.sort(function(a, b) { return a.id - b.id })
    return result
  }

  // ── Wrapper por workspace ─────────────────────────────────────────────
  //
  // Cada workspace é envolvida por um Item que:
  //  • renderiza o fundo da workspace ativa (pill destacado)
  //  • dimensiona-se ao delegate + padding conforme estado ativo/inativo
  //  • carrega o delegate correto via Loader
  //
  // IMPORTANTE — modelData e required:
  //  O Repeater instancia o wsWrapper Component e seta 'required property var modelData'
  //  automaticamente via contexto. O Loader dentro do wrapper instancia o delegate
  //  (Dot/Number/Hybrid/Icons) e injeta modelData + cores no onLoaded, pois o contexto
  //  do Repeater não é propagado automaticamente pelo Loader.
  //  Os delegates têm 'property var modelData: null' (sem required) para permitir
  //  esse assignment pós-criação.
  Component {
    id: wsWrapper

    Item {
      id: wrapper
      required property var modelData

      readonly property bool isActive: modelData.active

      // pH/pV: padding extra quando ativa (animado via Behavior abaixo)
      readonly property real pH: isActive ? root.bgPaddingHActive : 0
      readonly property real pV: isActive ? root.bgPaddingVActive : 0

      // Dimensões reativas ao delegate E ao estado ativo.
      // Usa delegateLoader.item diretamente (prop do Loader com notify)
      // para que mudanças em implicitWidth do delegate (ex: Icons add/remove)
      // disparem reavaliação.
      implicitWidth: {
        var dw = delegateLoader.item ? delegateLoader.item.implicitWidth  : 0
        return isHorizontal ? dw + pH * 2 : dw
      }
      implicitHeight: {
        var dh = delegateLoader.item ? delegateLoader.item.implicitHeight : 0
        return isHorizontal ? dh : dh + pV * 2
      }

      // Fundo da workspace ativa
      Rectangle {
        anchors.fill: parent
        visible:      wrapper.isActive && root.bgColorActive.a > 0.001
        radius:       root.bgRadiusActive
        color:        Qt.rgba(
                        root.bgColorActive.r,
                        root.bgColorActive.g,
                        root.bgColorActive.b,
                        root.bgOpacityActive)
        border.color: root.bgBorderColorActive
        border.width: root.bgBorderWidthActive

        Behavior on color { ColorAnimation { duration: 150 } }
      }

      // Delegate do workspace (Dot / Number / Hybrid / Icons)
      Loader {
        id: delegateLoader
        anchors.centerIn: parent

        sourceComponent: root.style === "dots"   ? dotComp
                       : root.style === "hybrid" ? hybridComp
                       : root.style === "icons"  ? iconsComp
                       : numberComp

        onLoaded: {
          // modelData — necessário para todos os delegates
          if ("modelData"       in item) item.modelData       = wrapper.modelData
          // cores — Dot / Number / Hybrid
          if ("dotColor"         in item) item.dotColor         = root.dotColor
          if ("dotActiveColor"   in item) item.dotActiveColor   = root.dotActiveColor
          if ("dotOccupiedColor" in item) item.dotOccupiedColor = root.dotOccupiedColor
          if ("dotUrgentColor"   in item) item.dotUrgentColor   = root.dotUrgentColor
          // Icons
          if ("sortOrder"       in item) item.sortOrder       = root.iconsSort
          if ("isHorizontal"    in item) item.isHorizontal    = root.isHorizontal
          if ("monochrome"      in item) item.monochrome      = root.iconMonochrome
          if ("monoColor"       in item) item.monoColor       = root.iconMonoColor
          if ("monoColorActive" in item) item.monoColorActive = root.iconMonoColorActive
          if ("iconSpacing"     in item) item.iconSpacing     = root.iconSpacing
        }
      }

      // Anima a transição de tamanho ativo ↔ inativo
      Behavior on implicitWidth  { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
      Behavior on implicitHeight { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    }
  }

  // ── Componentes de delegate ───────────────────────────────────────────
  // Props de cor são setadas no onLoaded do Loader acima.
  // Os Components abaixo são instanciados sem props (o Loader injeta tudo).
  Component { id: dotComp;    Comp.Dot    {} }
  Component { id: numberComp; Comp.Number {} }
  Component { id: hybridComp; Comp.Hybrid {} }
  Component { id: iconsComp;  Comp.Icons  {} }

  // ── Fundo global (agrupa todos os workspaces) ─────────────────────────
  Rectangle {
    id: bg
    anchors.centerIn: parent
    width:  layout.implicitWidth  + (root.isHorizontal ? root.bgPaddingH : root.bgPaddingV) * 2
    height: layout.implicitHeight + (root.isHorizontal ? root.bgPaddingV : root.bgPaddingH) * 2
    radius: Math.min(width, height) / 2
    color:  Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, root.bgOpacity)
    border.color: root.bgBorderColor
    border.width: root.bgBorderWidth

    GridLayout {
      id: layout
      anchors.centerIn: parent
      columns:       root.isHorizontal ? -1 : 1
      rows:          root.isHorizontal ? 1  : -1
      columnSpacing: root.isHorizontal ? root.iconSpacing : 0
      rowSpacing:    root.isHorizontal ? 0 : root.iconSpacing

      Repeater {
        model: root.workspaces
        delegate: wsWrapper
      }

      // Botão "+"
      Rectangle {
        visible:      root.showAddButton
        width:        24
        height:       24
        radius:       width / 2
        color:        "transparent"
        border.color: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.4)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text:           "+"
          color:          Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.4)
          font.pixelSize: 14
        }

        MouseArea {
          anchors.fill: parent
          onClicked:    Hyprland.dispatch("workspace emptynm")
        }
      }
    }
  }
}
