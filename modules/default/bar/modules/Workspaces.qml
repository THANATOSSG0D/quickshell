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

  // ── Focus: modo de revelação e delay de auto-colapso ─────────────────
  property string revealMode:           "hover"  // "hover" | "click"
  property int    hoverRevealDelayMs:   0        // ms; delay pra abrir no hover (0 = instantâneo)
  property string clickCollapseMode:    "exit"   // "exit" | "delay" — só usado no modo "click"
  property int    clickRevealTimeoutMs: 2500     // ms; usado só quando clickCollapseMode === "delay"

  // ── Scroll no módulo inteiro (troca workspace ou cicla janela) ───────
  property bool   scrollEnabled: false
  property string scrollAction:  "workspace"  // "workspace" | "window"
  property bool   scrollInvert:  false

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

  // fundo global (container de todos os workspaces) — toggle explícito
  // além da opacidade, pra ligar/desligar sem perder os valores configurados
  property bool  bgGroupEnabled: false
  property color bgColor:       "transparent"
  property real  bgOpacity:     0.0
  property color bgBorderColor: "transparent"
  property real  bgBorderWidth: 0
  property real  bgPaddingH:    12
  property real  bgPaddingV:    4

  // fundo individual da workspace ATIVA
  // toggle explícito — quando desligado, ignora bgColorActive mesmo que
  // tenha alfa > 0 (facilita testar/alternar sem perder as cores configuradas)
  property bool  bgActiveEnabled:     true
  property color bgColorActive:       "transparent"
  property real  bgOpacityActive:     0.8
  property color bgBorderColorActive: "transparent"
  property real  bgBorderWidthActive: 0
  property real  bgPaddingHActive:    6
  property real  bgPaddingVActive:    2
  property real  bgRadiusActive:      99   // 99=pill, 4=rounded rect, 0=square

  // fundo individual das workspaces INATIVAS (vazias ou ocupadas, não
  // selecionadas) — espelha as props "Active" acima. Desligado por padrão.
  property bool  bgInactiveEnabled:     false
  property color bgColorInactive:       "transparent"
  property real  bgOpacityInactive:     0.4
  property color bgBorderColorInactive: "transparent"
  property real  bgBorderWidthInactive: 0
  property real  bgPaddingHInactive:    6
  property real  bgPaddingVInactive:    2
  property real  bgRadiusInactive:      99

  // cores dos dots/números
  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.6)
  property color dotUrgentColor:   "#f38ba8"

  // ── Animação do indicador ativo (dots/número/hybrid) ─────────────────
  // "none" | "smooth" | "pop" | "pulse" — ver Dot.qml pra detalhe de cada
  // curva. Não afeta os estilos "icons"/"focus"/"current".
  property string indicatorAnimStyle:    "smooth"
  property int    indicatorAnimDuration: 140

  // ── Botão "+" (criar nova workspace) ─────────────────────────────────
  property bool  showAddButton:        true
  property bool  addButtonBorderEnabled: true
  property bool  addButtonBgEnabled:     false
  property color addButtonColor:         dotColor        // base p/ borda, texto e hover
  property color addButtonBgColor:       Qt.rgba(1, 1, 1, 0.08)
  property real  addButtonBgOpacity:     1.0
  // Tamanho da FONTE do glifo "+" (não mais o diâmetro do botão — ver
  // addButtonPaddingH/V abaixo). Termina em "Size" de propósito: é o que
  // faz o Bar.qml (bar._isScalable()) reconhecer e multiplicar
  // automaticamente pelo moduleScale global, igual iconSize/dotSize/fontSize.
  property int   addButtonSize:        13
  // Padding do glifo até a borda do círculo — mesmo padrão de
  // numberBgPaddingH/V (Icons.qml): o botão se AUTO-DIMENSIONA a partir do
  // tamanho da fonte + padding, em vez de um diâmetro fixo. Terminam em
  // "PaddingH"/"PaddingV" de propósito, então também escalam com
  // moduleScale (mesma convenção do resto do módulo).
  property int   addButtonPaddingH:    5
  property int   addButtonPaddingV:    5

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

      readonly property bool _showActiveBg:
        wrapper.isActive && root.bgActiveEnabled && root.bgColorActive.a > 0.001
      readonly property bool _showInactiveBg:
        !wrapper.isActive && root.bgInactiveEnabled && root.bgColorInactive.a > 0.001

      readonly property real pH: _showActiveBg ? root.bgPaddingHActive : _showInactiveBg ? root.bgPaddingHInactive : 0
      readonly property real pV: _showActiveBg ? root.bgPaddingVActive : _showInactiveBg ? root.bgPaddingVInactive : 0

      implicitWidth: {
        var dw = delegateLoader.item ? delegateLoader.item.implicitWidth  : 0
        return isHorizontal ? dw + pH * 2 : dw
      }
      implicitHeight: {
        var dh = delegateLoader.item ? delegateLoader.item.implicitHeight : 0
        return isHorizontal ? dh : dh + pV * 2
      }

      // Fundo da workspace ATIVA
      Rectangle {
        anchors.fill: parent
        visible:      wrapper._showActiveBg
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

      // Fundo das workspaces INATIVAS (vazias ou ocupadas, sem foco)
      Rectangle {
        anchors.fill: parent
        visible:      wrapper._showInactiveBg
        radius:       root.bgRadiusInactive
        color:        Qt.rgba(
                        root.bgColorInactive.r,
                        root.bgColorInactive.g,
                        root.bgColorInactive.b,
                        root.bgOpacityInactive)
        border.color: root.bgBorderColorInactive
        border.width: root.bgBorderWidthInactive

        Behavior on color { ColorAnimation { duration: 150 } }
      }

      // Delegate do workspace (Dot / Number / Hybrid / Icons)
      Loader {
        id: delegateLoader
        anchors.centerIn: parent

        sourceComponent: root.style === "dots"    ? dotComp
                       : root.style === "hybrid"  ? hybridComp
                       : root.style === "icons"   ? iconsComp
                       : root.style === "focus"   ? focusComp
                       : root.style === "current" ? currentComp
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
        // ── Cores — cada delegate tem seu próprio "contrato" de nomes ────
        // (ver comentário no topo de Dot.qml / Number.qml / Hybrid.qml).
        // Todas as três recebem os MESMOS 4 valores de origem (root.dotColor
        // etc — já isolados por estilo lá na config/tema), só o nome da
        // propriedade de DESTINO muda pra bater com o que cada delegate espera.
        Binding { target: delegateLoader.item; property: "dotColor";         value: root.dotColor;         when: delegateLoader.item !== null && root.style === "dots" }
        Binding { target: delegateLoader.item; property: "dotActiveColor";   value: root.dotActiveColor;   when: delegateLoader.item !== null && root.style === "dots" }
        Binding { target: delegateLoader.item; property: "dotOccupiedColor"; value: root.dotOccupiedColor; when: delegateLoader.item !== null && root.style === "dots" }
        Binding { target: delegateLoader.item; property: "dotUrgentColor";   value: root.dotUrgentColor;   when: delegateLoader.item !== null && root.style === "dots" }

        Binding { target: delegateLoader.item; property: "numTint";         value: root.dotColor;         when: delegateLoader.item !== null && root.style === "number" }
        Binding { target: delegateLoader.item; property: "numFillActive";   value: root.dotActiveColor;   when: delegateLoader.item !== null && root.style === "number" }
        Binding { target: delegateLoader.item; property: "numTintOccupied"; value: root.dotOccupiedColor; when: delegateLoader.item !== null && root.style === "number" }
        Binding { target: delegateLoader.item; property: "numUrgent";       value: root.dotUrgentColor;   when: delegateLoader.item !== null && root.style === "number" }

        Binding { target: delegateLoader.item; property: "hybridTint";         value: root.dotColor;         when: delegateLoader.item !== null && root.style === "hybrid" }
        Binding { target: delegateLoader.item; property: "hybridFillActive";   value: root.dotActiveColor;   when: delegateLoader.item !== null && root.style === "hybrid" }
        Binding { target: delegateLoader.item; property: "hybridTintOccupied"; value: root.dotOccupiedColor; when: delegateLoader.item !== null && root.style === "hybrid" }
        Binding { target: delegateLoader.item; property: "hybridUrgent";       value: root.dotUrgentColor;   when: delegateLoader.item !== null && root.style === "hybrid" }

        // ── animação do indicador (Dot / Number / Hybrid) ────────────────
        Binding { target: delegateLoader.item; property: "animStyle";    value: root.indicatorAnimStyle;    when: delegateLoader.item !== null && (root.style === "dots" || root.style === "number" || root.style === "hybrid") }
        Binding { target: delegateLoader.item; property: "animDuration"; value: root.indicatorAnimDuration; when: delegateLoader.item !== null && (root.style === "dots" || root.style === "number" || root.style === "hybrid") }

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

        // ── props Focus: modo de revelação por clique ────────────────────
        Binding { target: delegateLoader.item; property: "revealMode";           value: root.revealMode;           when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "hoverRevealDelayMs";   value: root.hoverRevealDelayMs;   when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "clickCollapseMode";    value: root.clickCollapseMode;    when: delegateLoader.item !== null && root.style === "focus" }
        Binding { target: delegateLoader.item; property: "clickRevealTimeoutMs"; value: root.clickRevealTimeoutMs; when: delegateLoader.item !== null && root.style === "focus" }

        // ── props Current Only (só ícones da workspace ativa) ────────────
        Binding { target: delegateLoader.item; property: "sortOrder";       value: root.iconsSort;           when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "isHorizontal";    value: root.isHorizontal;        when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "monochrome";      value: root.iconMonochrome;      when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "monoColor";       value: root.iconMonoColor;       when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "monoColorActive"; value: root.iconMonoColorActive; when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "iconSpacing";     value: root.iconSpacing;         when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "iconSize";        value: root.iconSize;            when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "showTooltip";     value: root.showTooltip;         when: delegateLoader.item !== null && root.style === "current" }
        Binding { target: delegateLoader.item; property: "urgentColor";     value: root.dotUrgentColor;      when: delegateLoader.item !== null && root.style === "current" }
      }

      // Focus já anima o próprio implicitWidth/Height internamente (ver
      // Focus.qml) para o efeito de expandir no hover — animar de novo
      // aqui em cima causava um "filtro sobre filtro" (easing composto),
      // deixando os ícones aparecerem atrasados/com salto visual.
      Behavior on implicitWidth  { enabled: root.visible && root.style !== "focus"; NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
      Behavior on implicitHeight { enabled: root.visible && root.style !== "focus"; NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
    }
  }

  Component { id: dotComp;     Comp.Dot         {} }
  Component { id: numberComp;  Comp.Number      {} }
  Component { id: hybridComp;  Comp.Hybrid      {} }
  Component { id: iconsComp;   Comp.Icons       {} }
  Component { id: focusComp;   Comp.Focus       {} }
  Component { id: currentComp; Comp.CurrentOnly {} }

  // ── Fundo global ─────────────────────────────────────────────────────
  Rectangle {
    id: bg
    anchors.centerIn: parent
    width:  layout.implicitWidth  + (root.isHorizontal ? root.bgPaddingH : root.bgPaddingV) * 2
    height: layout.implicitHeight + (root.isHorizontal ? root.bgPaddingV : root.bgPaddingH) * 2
    radius: Math.min(width, height) / 2
    color:  root.bgGroupEnabled
      ? Qt.rgba(root.bgColor.r, root.bgColor.g, root.bgColor.b, root.bgOpacity)
      : "transparent"
    border.color: root.bgGroupEnabled ? root.bgBorderColor : "transparent"
    border.width: root.bgGroupEnabled ? root.bgBorderWidth : 0

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
      // Borda e fundo agora são independentes e configuráveis.
      // Diâmetro deixou de ser fixo: agora nasce do TAMANHO DA FONTE do
      // glifo "+" + padding ajustável, mesmo espírito do numberBg em
      // Icons.qml. Importante: usa root.addButtonSize (número) na conta,
      // NÃO addBtnLabel.implicitWidth/implicitHeight — o implicitHeight de
      // um Text inclui o ascent/descent inteiro da fonte (espaço extra
      // assimétrico acima/abaixo do glifo visível), o que fazia o "+"
      // parecer descentralizado no círculo. Com a conta numérica, a caixa
      // fica sempre simétrica ao redor do glifo — igual ao Number.qml
      // (_minSize: fontSize * 2.2), então o anchors.centerIn abaixo
      // centraliza de verdade, como nos delegates de número.
      Rectangle {
        id: addBtn
        visible:      root.showAddButton

        property bool isAddHovered: false

        readonly property real _baseDiameter: Math.max(
          root.addButtonSize + root.addButtonPaddingH * 2,
          root.addButtonSize + root.addButtonPaddingV * 2)

        implicitWidth:  isAddHovered ? _baseDiameter + 4 : _baseDiameter
        implicitHeight: isAddHovered ? _baseDiameter + 4 : _baseDiameter
        radius:         width / 2

        readonly property color _bgBase: Qt.rgba(
          root.addButtonBgColor.r, root.addButtonBgColor.g, root.addButtonBgColor.b,
          root.addButtonBgColor.a * root.addButtonBgOpacity)
        readonly property color _bgHover: Qt.rgba(
          root.addButtonColor.r, root.addButtonColor.g, root.addButtonColor.b, 0.12)

        color: root.addButtonBgEnabled
          ? (isAddHovered ? _bgHover : _bgBase)
          : (isAddHovered ? _bgHover : "transparent")

        border.color: root.addButtonBorderEnabled
          ? Qt.rgba(root.addButtonColor.r, root.addButtonColor.g, root.addButtonColor.b, isAddHovered ? 0.55 : 0.30)
          : "transparent"
        border.width: root.addButtonBorderEnabled ? 1 : 0

        Behavior on implicitWidth  { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on implicitHeight { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
        Behavior on color          { ColorAnimation  { duration: 120 } }
        Behavior on border.color   { ColorAnimation  { duration: 120 } }
        Behavior on border.width   { NumberAnimation { duration: 120 } }

        Text {
          id: addBtnLabel
          anchors.centerIn: parent
          text:           "+"
          font.pixelSize: root.addButtonSize
          // Sem negrito — mais opacidade em vez de mais peso pra destacar
          // o glifo (0.55/0.95 em vez do 0.40/0.80 original).
          color:          Qt.rgba(root.addButtonColor.r, root.addButtonColor.g, root.addButtonColor.b, parent.isAddHovered ? 0.95 : 0.55)
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

  // ── Scroll no módulo inteiro — troca workspace ou cicla janela ────────
  // Um MouseArea comum, não um WheelHandler: na prática o WheelHandler
  // perdia o evento de wheel pros MouseAreas de hover/clique de cada
  // delegate (Dot/Number/Focus/etc — todos cobrem a área inteira do
  // próprio item e ficam "na frente" na árvore de eventos).
  //
  // A saída: acceptedButtons: Qt.NoButton faz esse MouseArea NUNCA
  // interceptar clique/press — eles passam direto pros delegates por
  // baixo, normalmente. Só o wheel é pego aqui, porque size real
  // (anchors.fill: bg, não "parent" — `root` só tem implicitWidth/Height,
  // nunca um width/height real, então usar `parent` aqui de novo ia
  // voltar a ter uma área de hit-test 0x0).
// ── Throttle do scroll — evita spam de dispatch IPC ───────────────────
  // hyprctl dispatch é síncrono no compositor: disparar uma chamada nova
  // antes da anterior terminar de processar acumula fila e trava/atrasa
  // (mais perceptível em touchpad, que manda vários eventos fracionados
  // por "gesto", em vez de 1 notch = 1 evento como no mouse com catraca).
  //
  // Acumula o delta e só dispara quando cruza o threshold de um notch
  // (120), guardando o resto — e um cooldown curto trava novos disparos
  // até o anterior ter tempo de ser processado. Se o próximo evento vier
  // com sinal OPOSTO ao acumulado (usuário inverteu o gesto no meio),
  // zera o acumulador em vez de subtrair — evita o "não volta direito"
  // quando a rajada mistura direções.
  property bool _wheelCooldown: false

  Timer {
    id: wheelCooldownTimer
    interval: 60   // ms — ajuste fino se ainda sentir travamento
    repeat:   false
    onTriggered: root._wheelCooldown = false
  }

  MouseArea {
    id: scrollArea
    anchors.fill: bg
    enabled:         root.scrollEnabled
    acceptedButtons: Qt.NoButton
    hoverEnabled:    false
    onWheel: (wheel) => {
      if (root._wheelCooldown) return

      var delta = wheel.angleDelta.y
      if (root.scrollInvert) delta = -delta
      var dir = delta > 0 ? 1 : -1

      root._wheelCooldown = true
      wheelCooldownTimer.restart()

      if (root.scrollAction === "window") {
        Hyprland.dispatch(dir > 0
          ? "hl.dsp.layout('focus r')"
          : "hl.dsp.layout('focus l')")
      } else {
        Hyprland.dispatch(dir > 0
          ? "hl.dsp.focus({ workspace = 'e+1' })"
          : "hl.dsp.focus({ workspace = 'e-1' })")
      }
    }
  }
}
