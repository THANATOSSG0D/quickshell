import QtQuick

// PmField — campo de texto simples usado nas linhas de "Entradas" do
// PowerMenuTab (label, ícone, keybind, comando). Arquivo próprio (em vez de
// inline component dentro de PowerMenuTab.qml) porque a sintaxe `component
// Foo: Bar {}` deu erro de parse no motor QML deste projeto.

Rectangle {
  id: fld

  property alias  text:        input.text
  property string placeholder: ""
  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#9e9e9e"
  property color  colorDivider: "#313244"
  property color  colorAccent:  "#cba6f7"
  property color  colorBg:      "#181825"

  signal committed(string value)

  height: 34
  radius: 8
  color:  Qt.darker(colorBg, 0.92)
  border.color: input.activeFocus ? colorAccent : colorDivider
  border.width: 1
  Behavior on border.color { ColorAnimation { duration: 120 } }

  TextInput {
    id: input
    anchors.fill: parent
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    verticalAlignment: TextInput.AlignVCenter
    color: fld.colorText
    font { family: "Fira Sans"; pixelSize: 12 }
    selectByMouse: true
    clip: true
    onEditingFinished: fld.committed(text)

    Text {
      visible: input.text.length === 0 && !input.activeFocus
      text: fld.placeholder
      color: fld.colorTextDim
      opacity: 0.5
      font: input.font
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
