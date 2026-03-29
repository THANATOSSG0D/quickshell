import QtQuick 

Item {
  property int position: 1 
  property int barSize: 30
  property int barMargin: 8
  property bool pill: false
  property int pillWidth: 800

  property string monitorName: ""

  Rectangle {
    anchors.fill: parent
    color: "red"
    radius: barSize / 2
  }

  Text {
    anchors.centerIn: parent 
    text: "Default"
    color: "white"
  }
}
