import QtQuick

Text {
  required property string title
  required property color  colorTextDim

  text:           title
  color:          colorTextDim
  font.pixelSize: 9
  font.weight:    Font.Medium
  font.family:    "JetBrainsMono Nerd Font"
}
