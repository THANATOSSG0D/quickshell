import QtQuick

// LockPowerButton — botão circular de energia (apagar tela/suspender/
// reiniciar/desligar) usado na barra inferior do lock screen.
// Arquivo próprio em vez de inline `component` (ver PmField.qml no
// PowerMenu pra mais contexto sobre por que isso importa aqui).

Item {
  id: btn

  property string icon:      ""
  property string label:     ""
  property color  iconColor: "#cacaca"
  property color  bgColor:   "#333333"
  property color  errorColor: "#f38ba8"
  property real   size:      44

  // true quando esse botão está aguardando confirmação (ação destrutiva,
  // primeiro clique já foi dado — precisa de um segundo pra executar).
  property bool pending: false

  signal clicked()

  width:  size
  height: size

  Rectangle {
    anchors.fill: parent
    radius: btn.size / 2
    color:  btn.pending ? btn.errorColor : btn.bgColor
    opacity: btn.pending ? 0.28 : (ma.containsMouse ? 0.75 : 0.32)
    border.color: btn.pending ? btn.errorColor : "transparent"
    border.width: btn.pending ? 1.5 : 0
    Behavior on opacity      { NumberAnimation { duration: 150 } }
    Behavior on color        { ColorAnimation  { duration: 150 } }
    Behavior on border.color { ColorAnimation  { duration: 150 } }

    SequentialAnimation on opacity {
      running: btn.pending
      loops: Animation.Infinite
      NumberAnimation { to: 0.16; duration: 420; easing.type: Easing.InOutQuad }
      NumberAnimation { to: 0.36; duration: 420; easing.type: Easing.InOutQuad }
    }
  }

  Text {
    anchors.centerIn: parent
    text:  btn.icon
    font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 18
    color: btn.pending ? btn.errorColor : (ma.containsMouse ? "#f0f0f0" : btn.iconColor)
    Behavior on color { ColorAnimation { duration: 150 } }
  }

  Rectangle {
    anchors.bottom: parent.top; anchors.bottomMargin: 6
    anchors.horizontalCenter: parent.horizontalCenter
    visible: (ma.containsMouse || btn.pending) && (btn.label !== "" || btn.pending)
    width: ttText.implicitWidth + 16; height: 24; radius: 6
    color: btn.pending ? Qt.rgba(btn.errorColor.r, btn.errorColor.g, btn.errorColor.b, 0.9) : "#26262d"
    Text {
      id: ttText
      anchors.centerIn: parent
      text: btn.pending ? "Confirmar?" : btn.label
      font.family: "Fira Sans"; font.pixelSize: 11
      font.letterSpacing: 1.2
      color: btn.pending ? "#1a1a1a" : "#cacaca"
    }
  }

  MouseArea {
    id: ma
    anchors.fill: parent
    hoverEnabled: true; cursorShape: Qt.PointingHandCursor
    onClicked: btn.clicked()
  }
}
