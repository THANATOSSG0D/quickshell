import QtQuick

// ── Contrato do delegate "Número" ────────────────────────────────────────
// Badge circular/pílula mostrando o número da workspace. NÃO tem ponto —
// nomeado de forma própria (num*) pra não ser confundido com Dot.qml na UI.
//   modelData, isHorizontal*, barPosition, showTooltip  → como os outros
//   fontSize                                            → tamanho da fonte
//   animStyle, animDuration                             → ver Dot.qml
//   numTint          → cor base (borda + texto) quando SEM foco
//   numTintOccupied  → cor base (borda + texto) quando OCUPADA (tem janelas)
//   numFillActive    → cor de FUNDO do badge quando ATIVA (selecionada)
//   numUrgent        → cor (borda + texto) quando URGENTE
// (*isHorizontal não é usado aqui — badge é sempre circular — mantido só
//  por compatibilidade de assinatura com o Loader do Workspaces.qml)
Rectangle {
  id: root

  property var modelData: null
  property int  barPosition: 2
  property bool showTooltip: true

  property color numTint:         "white"
  property color numTintOccupied: Qt.rgba(1, 1, 1, 0.6)
  property color numFillActive:   "white"
  property color numUrgent:       "#f38ba8"

  // Tamanho da fonte do número (default 10 — mantém o visual original).
  property int fontSize: 10

  // ── Animação do indicador (ver Dot.qml pra descrição de cada estilo) ──
  property string animStyle:    "smooth"
  property int    animDuration: 150

  readonly property bool   _active:   modelData ? modelData.active : false
  readonly property bool   _urgent:   modelData ? modelData.urgent : false
  readonly property bool   _occupied: modelData ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false
  readonly property string _name:     modelData ? modelData.name   : ""

  readonly property bool _noTween: root.animStyle === "none" || root.animStyle === "pulse"
  readonly property int  _easing:  root.animStyle === "pop" ? Easing.OutBack : Easing.InOutQuad
  readonly property int  _dur:     root.animStyle === "none" ? 0 : root.animDuration

  // Círculo adapta ao número de dígitos — ws "10" cabe sem truncar
  // _minSize escala com fontSize (10px → 22, igual ao hardcode original)
  readonly property real _minSize: root.fontSize * 2.2
  readonly property real _textPad: 10
  implicitWidth:  Math.max(_minSize, labelText.implicitWidth + _textPad)
  implicitHeight: _minSize

  width:  implicitWidth
  height: implicitHeight
  radius: height / 2
  scale:  1.0

  color: _active
    ? Qt.rgba(numFillActive.r, numFillActive.g, numFillActive.b, 0.90)
    : _occupied
      ? Qt.rgba(numTintOccupied.r, numTintOccupied.g, numTintOccupied.b, 0.14)
      : "transparent"

  border.color: _urgent
    ? numUrgent
    : _active
      ? "transparent"
      : _occupied
        ? Qt.rgba(numTintOccupied.r, numTintOccupied.g, numTintOccupied.b, 0.45)
        : Qt.rgba(numTint.r, numTint.g, numTint.b, 0.30)
  border.width: _urgent ? 1.5 : 1

  Behavior on color         { ColorAnimation { duration: root._dur === 0 ? 0 : Math.max(root._dur, 120) } }
  Behavior on border.color  { ColorAnimation { duration: root._dur === 0 ? 0 : Math.max(root._dur, 120) } }
  Behavior on implicitWidth { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing; easing.overshoot: 1.6 } }

  // "pulse" — kick de escala, disparado só na borda false→true do ativo.
  SequentialAnimation {
    id: pulseAnim
    running: false
    NumberAnimation { target: root; property: "scale"; from: 0.82; to: 1.1; duration: Math.max(70, root._dur * 0.5); easing.type: Easing.OutQuad }
    NumberAnimation { target: root; property: "scale"; to: 1.0; duration: Math.max(90, root._dur * 0.5); easing.type: Easing.OutBack }
  }
  Item {
    property bool active: root._active
    onActiveChanged: if (active && root.animStyle === "pulse") pulseAnim.restart()
  }

  Text {
    id: labelText
    anchors.centerIn: parent
    text:           root._name
    font.pixelSize: root.fontSize
    font.weight:    root._active ? Font.Medium : Font.Normal

    color: root._active ? root._contrastColor()
         : root._urgent ? root.numUrgent
         : root._occupied
           ? Qt.rgba(root.numTintOccupied.r, root.numTintOccupied.g, root.numTintOccupied.b, 0.95)
           : Qt.rgba(root.numTint.r, root.numTint.g, root.numTint.b, 0.45)

    Behavior on color { ColorAnimation { duration: root._dur === 0 ? 0 : Math.max(root._dur, 120) } }
  }

  function _contrastColor() {
    var lum = 0.299 * numFillActive.r + 0.587 * numFillActive.g + 0.114 * numFillActive.b
    return lum > 0.5 ? "#1a1a1a" : "#f0f0f0"
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: root.showTooltip
    onClicked: root.modelData && root.modelData.activate()
    onEntered: if (root.showTooltip) WsTooltip.show(root, root.modelData, root.barPosition)
    onExited:  WsTooltip.hide()
  }
}
