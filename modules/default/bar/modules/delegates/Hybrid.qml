import QtQuick

// ── Contrato do delegate "Hybrid" ────────────────────────────────────────
// Pílula com um dot pequeno + label do nome, expande ao ativar. Nomeado
// hybrid* (não dot*) pra não colidir/confundir com Dot.qml na UI, já que
// aqui a cor "ativa" pinta o FUNDO inteiro da pílula, não só um ponto.
//   hybridTint          → cor base (dot + borda + label) quando SEM foco
//   hybridTintOccupied  → cor base (dot + borda + label) quando OCUPADA
//   hybridFillActive    → cor de FUNDO da pílula quando ATIVA (selecionada)
//   hybridUrgent        → cor (borda + dot + label) quando URGENTE
Item {
  id: root

  property var modelData: null
  property bool isHorizontal: true
  property int  barPosition: 2
  property bool showTooltip: true

  property color hybridTint:         "white"
  property color hybridFillActive:   "white"
  property color hybridTintOccupied: Qt.rgba(1, 1, 1, 0.55)
  property color hybridUrgent:       "#f38ba8"

  // Tamanho da fonte do número (default 10 — mantém o visual original).
  // Dot indicador e dimensões do item escalam junto, na mesma proporção
  // que tinham com o hardcode antigo (vertical -1px/dot 60%, horizontal dot 50%).
  property int fontSize: 10

  // ── Animação do indicador (ver Dot.qml pra descrição de cada estilo) ──
  property string animStyle:    "smooth"
  property int    animDuration: 160
  readonly property bool _noTween: root.animStyle === "none"
  readonly property int  _easing:  root.animStyle === "pop" ? Easing.OutBack : Easing.InOutQuad
  readonly property int  _dur:     root.animStyle === "none" ? 0 : root.animDuration

  readonly property bool   _active:   modelData ? modelData.active  : false
  readonly property bool   _urgent:   modelData ? modelData.urgent  : false
  readonly property bool   _occupied: modelData
    ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false
  readonly property string _name:     modelData ? modelData.name    : ""

  // Cor de texto/dot sobre fundo ativo (contraste automático)
  readonly property color _onActive: {
    var lum = 0.299 * hybridFillActive.r + 0.587 * hybridFillActive.g + 0.114 * hybridFillActive.b
    return lum > 0.5 ? Qt.rgba(0.08, 0.08, 0.08, 1) : Qt.rgba(0.93, 0.93, 0.93, 1)
  }

  readonly property color _fgColor:
    _active   ? _onActive
    : _urgent   ? hybridUrgent
    : _occupied ? Qt.rgba(hybridTintOccupied.r, hybridTintOccupied.g, hybridTintOccupied.b, 0.90)
    :             Qt.rgba(hybridTint.r, hybridTint.g, hybridTint.b, 0.30)

  // ── Dimensões ─────────────────────────────────────────────────────────
  // Horizontal: pill expande na largura ao ativar
  // Vertical:   pill expande na altura ao ativar
  readonly property real _padH: isHorizontal ? (_active ? 10 : 7) : 7
  readonly property real _padV: isHorizontal ? 4 : (_active ? 8 : 5)

  implicitWidth:  isHorizontal
    ? dot.width + (_active ? label.implicitWidth + 6 : 0) + _padH * 2
    : root.fontSize + 16
  implicitHeight: isHorizontal
    ? root.fontSize + 12
    : dot.height + (_active ? label.implicitHeight + 4 : 0) + _padV * 2

  Behavior on implicitWidth  { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing; easing.overshoot: 1.6 } }
  Behavior on implicitHeight { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing; easing.overshoot: 1.6 } }

  // ── Fundo ─────────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Math.min(width, height) / 2
    clip:   true

    color: _active
      ? Qt.rgba(hybridFillActive.r, hybridFillActive.g, hybridFillActive.b, 0.88)
      : _occupied
        ? Qt.rgba(hybridTintOccupied.r, hybridTintOccupied.g, hybridTintOccupied.b, 0.10)
        : "transparent"

    border.color: _urgent
      ? hybridUrgent
      : _active
        ? "transparent"
        : _occupied
          ? Qt.rgba(hybridTintOccupied.r, hybridTintOccupied.g, hybridTintOccupied.b, 0.40)
          : Qt.rgba(hybridTint.r, hybridTint.g, hybridTint.b, 0.22)
    border.width: 1

    Behavior on color        { ColorAnimation { duration: root._dur === 0 ? 0 : Math.max(root._dur, 120) } }
    Behavior on border.color { ColorAnimation { duration: root._dur === 0 ? 0 : Math.max(root._dur, 120) } }

    // ── Conteúdo ── posição depende de orientação ─────────────────────
    // Horizontal: dot e label lado a lado, centralizados
    // Vertical:   dot e label empilhados, centralizados
    Column {
      visible:          !root.isHorizontal
      anchors.centerIn: parent
      spacing:          root._active ? 3 : 0

      Behavior on spacing { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing } }

      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width:  root.fontSize * 0.6; height: root.fontSize * 0.6; radius: width / 2
        color: root._fgColor
        Behavior on color { ColorAnimation { duration: 140 } }
      }

      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        text:           root._name
        font.pixelSize: root.fontSize - 1
        font.weight:    Font.Medium
        color:          root._fgColor
        opacity:        root._active ? 1.0 : 0.0
        height:         root._active ? implicitHeight : 0
        clip:           true

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on height  { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }
        Behavior on color   { ColorAnimation  { duration: 140 } }
      }
    }

    Row {
      visible:          root.isHorizontal
      anchors.centerIn: parent
      spacing:          root._active ? 5 : 0

      Behavior on spacing { enabled: !root._noTween; NumberAnimation { duration: root._dur; easing.type: root._easing } }

      Rectangle {
        id: dot
        anchors.verticalCenter: parent.verticalCenter
        width:  root.fontSize * 0.5; height: root.fontSize * 0.5; radius: width / 2
        color: root._fgColor
        Behavior on color { ColorAnimation { duration: 140 } }
      }

      Text {
        id: label
        anchors.verticalCenter: parent.verticalCenter
        text:           root._name
        font.pixelSize: root.fontSize
        font.weight:    Font.Medium
        color:          root._fgColor
        opacity:        root._active ? 1.0 : 0.0
        width:          root._active ? implicitWidth : 0
        clip:           true

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on width   { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }
        Behavior on color   { ColorAnimation  { duration: 140 } }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: root.showTooltip
    onClicked: root.modelData && root.modelData.activate()
    onEntered: if (root.showTooltip) WsTooltip.show(root, root.modelData, root.barPosition)
    onExited:  WsTooltip.hide()
  }
}
