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

  // Posição da barra — necessário para o WsTooltip saltar do lado certo
  property int barPosition: 2   // 1=top, 2=right(default), 3=bottom, 4=left
  property bool showTooltip: true

  // ícones
  property bool  iconMonochrome:      false
  property color iconMonoColor:       "white"
  property color iconMonoColorActive: "red"
  property int   iconSpacing:         3
  property int   iconSize:            18
  property bool  showNumber:          false

  // número da workspace (estilo "icons") — cor do texto e fundo opcional
  property color numberColor:         "white"
  property color numberColorActive:   "red"
  property bool  numberBgEnabled:     false
  property color numberBgColor:       "transparent"
  property color numberBgColorActive: "transparent"
  property int   numberBgRadius:      4
  property int   numberBgPaddingH:    4
  property int   numberBgPaddingV:    2
  property int   numberSpacing:       4

  // tamanho dos itens — dots (diâmetro do dot ativo) / number e hybrid
  // (tamanho da fonte do número). Não tem efeito no estilo "icons" (ver iconSize acima).
  property int   dotSize:  8
  property int   fontSize: 10

  // espaçamento entre workspaces no GridLayout
  property int wsSpacing: 2

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

  // ── Tamanho implícito ─────────────────────────────────────────────────
  //
  // ANTES (bugado):
  //   implicitWidth  = isHorizontal ? bg.width  : bg.height   ← swap
  //   implicitHeight = isHorizontal ? bg.height : bg.width    ← swap
  //
  // O swap fazia sentido conceptualmente ("roda 90° para barra vertical"),
  // mas estava errado na prática:
  //
  //   • O Column do verticalComp usa Loader.height para layout vertical.
  //     Loader.height = modItem.implicitHeight = Workspaces.implicitHeight.
  //     Com o swap, implicitHeight = bg.width (pequeno, ~30px).
  //     → módulo ocupa só ~30px na coluna mas renderiza bg.height (~200px)
  //     → workspaces transborda sobre os outros módulos (clock, volume).
  //
  //   • O Row do horizontalComp usa Loader.width = modItem.implicitWidth.
  //     Com o swap para vertical, implicitWidth = bg.height (grande) numa
  //     barra horizontal — esse caso não se aplica (orientation="horizontal"
  //     quando isHorizontal=true, logo swap não actua na horizontal).
  //
  // AGORA (correcto):
  //   implicitWidth  = bg.width   ← dimensão HORIZONTAL do widget
  //   implicitHeight = bg.height  ← dimensão VERTICAL do widget
  //
  // Para barra HORIZONTAL: Row usa implicitWidth = bg.width (extensão total
  //   dos workspaces na horizontal). ✓
  // Para barra VERTICAL: Column usa implicitHeight = bg.height (extensão
  //   total dos workspaces na vertical, pode ser ~200px com 6 workspaces). ✓
  //
  // O `bg` já calcula width e height correctamente para cada orientação:
  //   bg.width  = layout.implicitWidth  + padding_h
  //   bg.height = layout.implicitHeight + padding_v
  // e o GridLayout usa columns=-1 (row único) ou rows=-1 (column única)
  // conforme isHorizontal, então implicitWidth/Height já reflectem o eixo certo.
  implicitWidth:  bg.width
  implicitHeight: bg.height

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
  Component {
    id: wsWrapper

    Item {
      id: wrapper
      required property var modelData

      readonly property bool isActive: modelData.active

      readonly property real pH: isActive ? root.bgPaddingHActive : 0
      readonly property real pV: isActive ? root.bgPaddingVActive : 0

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
                       : root.style === "focus"  ? focusComp
                       : numberComp

        // ── modelData (todos) ────────────────────────────────────────────
        Binding { target: delegateLoader.item; property: "modelData"; value: wrapper.modelData; when: delegateLoader.item !== null }

        // ── posição da barra (todos) — necessário para o WsTooltip ───────
        Binding { target: delegateLoader.item; property: "barPosition"; value: root.barPosition; when: delegateLoader.item !== null }

        // ── habilitar/desabilitar tooltip (todos) ─────────────────────────
        Binding { target: delegateLoader.item; property: "showTooltip"; value: root.showTooltip; when: delegateLoader.item !== null }

        // ── cores Dot / Number / Hybrid ─────────────────────────────────
        // (Focus NÃO declara essas props — reaproveita numberColor/
        // numberColorActive/urgentColor próprios; por isso fica de fora
        // daqui, senão o binding tenta escrever em propriedade inexistente)
        Binding { target: delegateLoader.item; property: "dotColor";         value: root.dotColor;         when: delegateLoader.item !== null && (root.style === "dots" || root.style === "number" || root.style === "hybrid") }
        Binding { target: delegateLoader.item; property: "dotActiveColor";   value: root.dotActiveColor;   when: delegateLoader.item !== null && (root.style === "dots" || root.style === "number" || root.style === "hybrid") }
        Binding { target: delegateLoader.item; property: "dotOccupiedColor"; value: root.dotOccupiedColor; when: delegateLoader.item !== null && (root.style === "dots" || root.style === "number" || root.style === "hybrid") }
        Binding { target: delegateLoader.item; property: "dotUrgentColor";   value: root.dotUrgentColor;   when: delegateLoader.item !== null && (root.style === "dots" || root.style === "number" || root.style === "hybrid") }

        // ── orientação (Dot) ─────────────────────────────────────────────
        Binding { target: delegateLoader.item; property: "isHorizontal"; value: root.isHorizontal; when: delegateLoader.item !== null && (root.style === "dots" || root.style === "hybrid") }

        // ── props Icons ─────────────────────────────────────────────────
        Binding { target: delegateLoader.item; property: "sortOrder";       value: root.iconsSort;           when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "isHorizontal";    value: root.isHorizontal;        when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "monochrome";      value: root.iconMonochrome;      when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "monoColor";       value: root.iconMonoColor;       when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "monoColorActive"; value: root.iconMonoColorActive; when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "iconSpacing";     value: root.iconSpacing;         when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "iconSize";       value: root.iconSize;            when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "showNumber";    value: root.showNumber;          when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberColor";         value: root.numberColor;         when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberColorActive";   value: root.numberColorActive;   when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberBgEnabled";     value: root.numberBgEnabled;     when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberBgColor";       value: root.numberBgColor;       when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberBgColorActive"; value: root.numberBgColorActive; when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberBgRadius";      value: root.numberBgRadius;      when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberBgPaddingH";    value: root.numberBgPaddingH;    when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberBgPaddingV";    value: root.numberBgPaddingV;    when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "numberSpacing";       value: root.numberSpacing;       when: delegateLoader.item !== null && root.style === "icons" }
        Binding { target: delegateLoader.item; property: "urgentColor";   value: root.dotUrgentColor;      when: delegateLoader.item !== null && root.style === "icons" }

        // ── tamanho dot/número (Dot / Number / Hybrid) ───────────────────
        Binding { target: delegateLoader.item; property: "dotSize";  value: root.dotSize;  when: delegateLoader.item !== null && root.style === "dots" }
        Binding { target: delegateLoader.item; property: "fontSize"; value: root.fontSize; when: delegateLoader.item !== null && (root.style === "number" || root.style === "hybrid" || root.style === "focus") }

        // ── props Focus (ativa=ícones, inativa=número que revela ícones no hover) ──
        Binding { target: delegateLoader.item; property: "sortOrder";           value: root.iconsSort;           when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "isHorizontal";        value: root.isHorizontal;        when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "monochrome";         value: root.iconMonochrome;      when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "monoColor";          value: root.iconMonoColor;       when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "monoColorActive";    value: root.iconMonoColorActive; when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "iconSpacing";        value: root.iconSpacing;         when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "iconSize";           value: root.iconSize;            when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberColor";        value: root.numberColor;         when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberColorActive";  value: root.numberColorActive;   when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberBgEnabled";    value: root.numberBgEnabled;     when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberBgColor";      value: root.numberBgColor;       when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberBgColorActive"; value: root.numberBgColorActive; when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberBgRadius";     value: root.numberBgRadius;      when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberBgPaddingH";   value: root.numberBgPaddingH;    when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "numberBgPaddingV";   value: root.numberBgPaddingV;    when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "urgentColor";        value: root.dotUrgentColor;      when: delegateLoader.item !== null && root.style === "focus" }
      }

      // Focus já anima o próprio implicitWidth/Height internamente (ver
      // Focus.qml) para o efeito de expandir no hover — animar de novo
      // aqui em cima causava um "filtro sobre filtro" (easing composto),
      // deixando os ícones aparecerem atrasados/com salto visual.
      Behavior on implicitWidth  { enabled: root.visible && root.style !== "focus"; NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
      Behavior on implicitHeight { enabled: root.visible && root.style !== "focus"; NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    }
  }

  Component { id: dotComp;    Comp.Dot    {} }
  Component { id: numberComp; Comp.Number {} }
  Component { id: hybridComp; Comp.Hybrid {} }
  Component { id: iconsComp;  Comp.Icons  {} }
  Component { id: focusComp;  Comp.Focus  {} }

  // ── Fundo global ─────────────────────────────────────────────────────
  Rectangle {
    id: bg
    anchors.centerIn: parent
    width:  layout.implicitWidth  + (root.isHorizontal ? root.bgPaddingH : root.bgPaddingV) * 2
    height: layout.implicitHeight + (root.isHorizontal ? root.bgPaddingV : root.bgPaddingH) * 2
    radius: Math.min(width, height) / 2
    color:  Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, root.bgOpacity)
    border.color: root.bgBorderColor
    border.width: root.bgBorderWidth

    Behavior on color        { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    GridLayout {
      id: layout
      anchors.centerIn: parent
      columns:       root.isHorizontal ? -1 : 1
      rows:          root.isHorizontal ? 1  : -1
      // Separa workspace-spacing de icon-spacing para não confundir os dois conceitos
      columnSpacing: root.isHorizontal ? root.wsSpacing : 0
      rowSpacing:    root.isHorizontal ? 0 : root.wsSpacing

      Repeater {
        model: root.workspaces
        delegate: wsWrapper
      }

      // ── Botão "+" ───────────────────────────────────────────────────
      Rectangle {
        visible:      root.showAddButton
        implicitWidth:  isAddHovered ? 26 : 22
        implicitHeight: isAddHovered ? 26 : 22
        radius:         width / 2
        color:          isAddHovered
          ? Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, 0.12)
          : "transparent"
        border.color: Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, isAddHovered ? 0.55 : 0.30)
        border.width: 1

        property bool isAddHovered: false

        Behavior on implicitWidth  { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on color          { ColorAnimation  { duration: 120 } }
        Behavior on border.color   { ColorAnimation  { duration: 120 } }

        Text {
          anchors.centerIn: parent
          text:           "+"
          font.pixelSize: 13
          color:          Qt.rgba(root.dotColor.r, root.dotColor.g, root.dotColor.b, parent.isAddHovered ? 0.80 : 0.40)
          Behavior on color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered:    parent.isAddHovered = true
          onExited:     parent.isAddHovered = false
          onClicked:    Hyprland.dispatch("hl.dsp.focus({ workspace = 'emptynm'})")
        }
      }
    }
  }
}
