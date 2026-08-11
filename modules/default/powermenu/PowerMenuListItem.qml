import QtQuick
import QtQuick.Layouts
import "root:/"

// PowerMenuListItem — linha compacta usada pelo menuStyle "list": ícone à
// esquerda, label preenchendo o espaço, keybind badge à direita. Pensado
// pra ficar bom empilhado num popup estreito (modo janela ancorado num
// canto, por exemplo), diferente do PowerMenuButton (card quadrado, feito
// pra grade/tela cheia).

Item {
  id: root

  property var  entry:      ({})
  property bool isFocused:  false
  property bool pending:    false
  property var  config:     null

  signal clicked()
  signal hovered()

  function _c(key, fallback) { return root.config ? root.config.getColor(key) : fallback }
  function _g(key, fallback) { return root.config ? root.config.get(key, fallback) : fallback }

  readonly property color _cAccent:        _c("colorAccent",       Colors.primary)
  readonly property color _cCardBg:        _c("colorCardBg",       Colors.surface_container)
  readonly property color _cCardBgFocused: _c("colorCardBgFocused",Colors.primary_container)
  readonly property color _cBorder:        _c("colorBorder",       Colors.outline_variant)
  readonly property color _cIcon:          _c("colorIcon",         Colors.on_surface_variant)
  readonly property color _cLabel:         _c("colorLabel",        Colors.on_surface_variant)
  readonly property color _cLabelFocused:  _c("colorLabelFocused", Colors.on_primary_container)
  readonly property color _cKeybindBg:     _c("colorKeybindBg",    Colors.surface_container_highest)
  readonly property color _cDanger:        _c("colorDanger",       Colors.error)

  readonly property int  _animMs: _g("hoverAnimMs", 160)
  readonly property bool _showLabels:  _g("showLabels", true)
  readonly property bool _showKeybind: _g("showKeybindBadge", true)
  readonly property bool _hot: pending || (isFocused && entry.danger === true)

  readonly property int _itemH:  _g("listItemHeight", 52)
  readonly property int _radius: _g("listRadius", 14)

  width:  parent ? parent.width : _g("listWidth", 340)
  height: _itemH
  Layout.preferredWidth:  width
  Layout.preferredHeight: _itemH
  Layout.fillWidth: true

  Rectangle {
    id: row
    anchors.fill: parent
    radius: root._radius
    color: root._hot
      ? Qt.rgba(root._cDanger.r, root._cDanger.g, root._cDanger.b, isFocused ? 0.22 : 0.10)
      : (isFocused
        ? Qt.rgba(root._cCardBgFocused.r, root._cCardBgFocused.g, root._cCardBgFocused.b, 0.20)
        : Qt.rgba(root._cCardBg.r, root._cCardBg.g, root._cCardBg.b, 0.85))
    border.color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cBorder)
    border.width: root._hot && isFocused ? 1.5 : 1
    Behavior on color        { ColorAnimation { duration: root._animMs } }
    Behavior on border.color { ColorAnimation { duration: root._animMs } }

    // Barra de acento à esquerda quando focado
    Rectangle {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: 0
      width:  isFocused ? 3 : 0
      height: parent.height * 0.5
      radius: 2
      color:  root._hot ? root._cDanger : root._cAccent
      Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    }

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 16
      anchors.rightMargin: 14
      spacing: 14

      Text {
        text:  root.pending ? "\uf12a" : (entry.text ?? "?")
        color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cIcon)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 22 }
        Behavior on color { ColorAnimation { duration: root._animMs } }

        SequentialAnimation on opacity {
          running: root.pending
          loops: Animation.Infinite
          NumberAnimation { to: 0.4; duration: 420; easing.type: Easing.InOutQuad }
          NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutQuad }
        }
      }

      Text {
        visible: root._showLabels
        Layout.fillWidth: true
        text:  root.pending ? "Confirmar?" : (entry.label ?? "")
        color: root._hot ? root._cDanger : (isFocused ? root._cLabelFocused : root._cLabel)
        font { family: "Fira Sans"; pixelSize: 13; bold: isFocused }
        elide: Text.ElideRight
        Behavior on color { ColorAnimation { duration: root._animMs } }
      }

      Rectangle {
        visible: root.pending || (root._showKeybind && (entry.keybind ?? "") !== "")
        Layout.alignment: Qt.AlignVCenter
        width:  kbLabel.implicitWidth + 12
        height: kbLabel.implicitHeight + 6
        radius: 5
        color: root._hot
          ? Qt.rgba(root._cDanger.r, root._cDanger.g, root._cDanger.b, 0.18)
          : (isFocused
            ? Qt.rgba(root._cAccent.r, root._cAccent.g, root._cAccent.b, 0.18)
            : root._cKeybindBg)
        border.color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cBorder)
        border.width: 1

        Text {
          id: kbLabel
          anchors.centerIn: parent
          text:  root.pending ? "ENTER" : (entry.keybind ?? "").toUpperCase()
          color: root._hot ? root._cDanger : (isFocused ? root._cAccent : Colors.outline)
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true }
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape:  Qt.PointingHandCursor
    onEntered:    root.hovered()
    onClicked:    root.clicked()
  }
}
