import QtQuick

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

  // Tamanho da fonte do número (default 10 — mantém o visual original).
  // Dot indicador e dimensões do item escalam junto, na mesma proporção
  // que tinham com o hardcode antigo (vertical -1px/dot 60%, horizontal dot 50%).
  property int fontSize: 10

  readonly property bool   _active:   modelData ? modelData.active  : false
  readonly property bool   _urgent:   modelData ? modelData.urgent  : false
  readonly property bool   _occupied: modelData
    ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false
  readonly property string _name:     modelData ? modelData.name    : ""

  // Cor de texto/dot sobre fundo ativo (contraste automático)
  readonly property color _onActive: {
    var lum = 0.299 * dotActiveColor.r + 0.587 * dotActiveColor.g + 0.114 * dotActiveColor.b
    return lum > 0.5 ? Qt.rgba(0.08, 0.08, 0.08, 1) : Qt.rgba(0.93, 0.93, 0.93, 1)
  }

  readonly property color _fgColor:
    _active   ? _onActive
    : _urgent   ? dotUrgentColor
    : _occupied ? Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.85)
    :             Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.30)

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

  Behavior on implicitWidth  { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }
  Behavior on implicitHeight { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

  // ── Fundo ─────────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Math.min(width, height) / 2
    clip:   true

    color: _active
      ? Qt.rgba(dotActiveColor.r, dotActiveColor.g, dotActiveColor.b, 0.88)
      : _occupied
        ? Qt.rgba(dotColor.r, dotColor.g, dotColor.b, 0.07)
        : "transparent"

    border.color: _urgent
      ? dotUrgentColor
      : _active
        ? "transparent"
        : Qt.rgba(dotColor.r, dotColor.g, dotColor.b, _occupied ? 0.40 : 0.22)
    border.width: 1

    Behavior on color        { ColorAnimation { duration: 150 } }
    Behavior on border.color { ColorAnimation { duration: 150 } }

    // ── Conteúdo ── posição depende de orientação ─────────────────────
    // Horizontal: dot e label lado a lado, centralizados
    // Vertical:   dot e label empilhados, centralizados
    Column {
      visible:          !root.isHorizontal
      anchors.centerIn: parent
      spacing:          root._active ? 3 : 0

      Behavior on spacing { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

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

      Behavior on spacing { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

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
