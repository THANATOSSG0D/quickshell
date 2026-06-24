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

  // Diâmetro do dot ATIVO (default 8 — mantém o visual original).
  // Ocupado e inativo escalam proporcionalmente (62.5% / 37.5%, igual ao
  // antigo hardcode 8/5/3) para preservar a hierarquia visual ao mudar o tamanho.
  property int dotSize: 8

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

  // Container escala com o dot — antes fixo em 16 (= dotSize padrão 8 * 2)
  implicitWidth:  root.dotSize * 2
  implicitHeight: root.dotSize * 2

  Rectangle {
    anchors.centerIn: parent
    width:  root._size
    height: root._size
    radius: width / 2
    color:  root._color

    Behavior on width  { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
    Behavior on height { NumberAnimation { duration: 140; easing.type: Easing.InOutQuad } }
    Behavior on color  { ColorAnimation  { duration: 140 } }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: root.showTooltip
    onClicked: root.modelData && root.modelData.activate()
    onEntered: if (root.showTooltip) WsTooltip.show(root, root.modelData, root.barPosition)
    onExited:  WsTooltip.hide()
  }
}
