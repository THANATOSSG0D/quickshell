import QtQuick

// ── Contrato do delegate "Dots" ──────────────────────────────────────────
// Ponto que cresce/muda de cor conforme o estado da workspace.
//   modelData, isHorizontal, barPosition, showTooltip  → como os outros
//   dotSize                                            → diâmetro (ativo)
//   animStyle, animDuration                            → ver descrição abaixo
//   dotColor          → cor quando SEM foco (vazia)
//   dotOccupiedColor  → cor quando OCUPADA (tem janelas, não selecionada)
//   dotActiveColor    → cor quando ATIVA (selecionada)
//   dotUrgentColor    → cor quando URGENTE (notificação pedindo atenção)
Item {
  id: root

  property var modelData: null
  property bool isHorizontal: true
  property int  barPosition: 2
  property bool showTooltip: true

  property color dotColor:         "white"
  property color dotActiveColor:   "white"
  property color dotOccupiedColor: Qt.rgba(1, 1, 1, 0.55)
  property color dotUrgentColor:   "#f38ba8"

  // Diâmetro do dot ATIVO (default 8 — mantém o visual original).
  // Ocupado e inativo escalam proporcionalmente (62.5% / 37.5%, igual ao
  // antigo hardcode 8/5/3) para preservar a hierarquia visual ao mudar o tamanho.
  property int dotSize: 8

  // ── Animação do indicador ────────────────────────────────────────────
  // "none"   → sem transição, muda instantaneamente
  // "smooth" → InOutQuad (comportamento original, sempre foi assim)
  // "pop"    → cresce com um leve "overshoot" (Easing.OutBack) — um único
  //            solavanco suave, não fica "pulando" feito o Bounce clássico
  // "pulse"  → tamanho muda na hora, e por cima entra um "kick" de escala
  //            (0.7 → 1.0) só na borda inativo→ativo. É a única opção que
  //            NÃO anima width/height por baixo — evita duas animações
  //            competindo ao mesmo tempo e deixando o movimento "sujo".
  property string animStyle:    "smooth"
  property int    animDuration: 140

  readonly property bool _active:   modelData ? modelData.active : false
  readonly property bool _urgent:   modelData ? modelData.urgent : false
  readonly property bool _occupied: modelData
    ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false

  readonly property real _size:
    _active ? root.dotSize : _occupied ? root.dotSize * 0.625 : root.dotSize * 0.375

  readonly property color _color:
    _active   ? dotActiveColor
    : _urgent   ? dotUrgentColor
    : _occupied ? dotOccupiedColor
    : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.22)

  readonly property bool _noTween: root.animStyle === "none" || root.animStyle === "pulse"
  readonly property int  _easing:  root.animStyle === "pop" ? Easing.OutBack : Easing.InOutQuad
  readonly property int  _dur:     root.animStyle === "none" ? 0 : root.animDuration

  // Container escala com o dot — antes fixo em 16 (= dotSize padrão 8 * 2)
  implicitWidth:  root.dotSize * 2
  implicitHeight: root.dotSize * 2

  Rectangle {
    id: dotRect
    anchors.centerIn: parent
    width:  root._size
    height: root._size
    radius: width / 2
    color:  root._color
    scale:  1.0

    Behavior on width  { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing; easing.overshoot: 1.6 } }
    Behavior on height { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing; easing.overshoot: 1.6 } }
    Behavior on color  { ColorAnimation { duration: root._dur === 0 ? 0 : Math.max(root._dur, 120) } }
  }

  // "pulse" — kick de escala, disparado só na borda false→true do ativo.
  SequentialAnimation {
    id: pulseAnim
    running: false
    NumberAnimation { target: dotRect; property: "scale"; from: 0.7; to: 1.15; duration: Math.max(70, root._dur * 0.5); easing.type: Easing.OutQuad }
    NumberAnimation { target: dotRect; property: "scale"; to: 1.0; duration: Math.max(90, root._dur * 0.5); easing.type: Easing.OutBack }
  }
  Item {
    property bool active: root._active
    onActiveChanged: if (active && root.animStyle === "pulse") pulseAnim.restart()
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: root.showTooltip
    onClicked: root.modelData && root.modelData.activate()
    onEntered: if (root.showTooltip) WsTooltip.show(root, root.modelData, root.barPosition)
    onExited:  WsTooltip.hide()
  }
}
