import QtQuick
import QtQuick.Layouts

// ── OsdContent ────────────────────────────────────────────────────────────
// UI pura do OSD.
//
// Modos:
//  value < 0  → modo media   (horizontal 280×72) — label + ícone grande
//  value >= 0 → modo volume  (vertical 72×240)   — barra + ícone
//  timerMode  → modo timer   (horizontal 320×96) — label + botões ação
//
// Sinais emitidos no modo timer (conectados pelo Osd.qml ao ClockContent):
//   timerToggle, timerAddMin, timerAddInterval, timerNext (pomodoro), timerDismiss

Item {
  id: root

  // ── Props de dados ─────────────────────────────────────────────────────
  property string icon:      "\uf028"
  property real   value:     0.75      // 0.0–1.0 (< 0 = modo media)
  property string label:     "75%"
  property bool   muted:     false

  // ── Modo timer ─────────────────────────────────────────────────────────
  property bool   timerMode:       false
  property string timerLabel:      ""     // ex: "25:00"
  property string timerPhase:      ""     // ex: "Foco · 1º ciclo"
  property bool   timerIsPomodoro: false  // mostra botão "próxima fase"
  property bool   timerRunning:    false
  property int    timerPhaseDuration: 0  // segundos — usado no label do botão +intervalo

  signal timerToggle()
  signal timerAddMin()
  signal timerAddInterval()
  signal timerNext()
  signal timerDismiss()

  // ── Cores ──────────────────────────────────────────────────────────────
  property color colorBg:     Qt.rgba(0.08, 0.08, 0.08, 0.92)
  property color colorAccent: "#ffb4a9"
  property color colorMuted:  Qt.rgba(1, 1, 1, 0.22)
  property color colorTrack:  Qt.rgba(1, 1, 1, 0.12)
  property color colorText:   Qt.rgba(1, 1, 1, 0.55)
  property color colorIcon:   Qt.rgba(1, 1, 1, 0.90)

  readonly property bool mediaMode: !timerMode && value < 0

  // Tamanhos por modo
  implicitWidth: {
    if (timerMode)  return 380
    if (mediaMode)  return 280
    return 72
  }
  implicitHeight: {
    if (timerMode)  return 100
    if (mediaMode)  return 72
    return 240
  }

  Behavior on implicitWidth  { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
  Behavior on implicitHeight { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

  // ── Fundo pill ─────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Math.min(width, height) / 2
    color:  root.colorBg

    // Borda sutil
    Rectangle {
      anchors.fill: parent; radius: parent.radius
      color: "transparent"
      border.color: Qt.rgba(1, 1, 1, 0.07)
      border.width: 1
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MODO VOLUME / SOURCE
  // ══════════════════════════════════════════════════════════════════════
  ColumnLayout {
    visible:              !root.mediaMode && !root.timerMode
    anchors.fill:         parent
    anchors.topMargin:    18
    anchors.bottomMargin: 18
    spacing: 12

    Text {
      Layout.alignment: Qt.AlignHCenter
      text:             root.icon
      color:            root.muted ? Qt.rgba(1,1,1,0.28) : root.colorIcon
      font.pixelSize:   22
      font.family:      "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    Item {
      Layout.alignment:  Qt.AlignHCenter
      Layout.fillHeight: true
      implicitWidth:     28

      // Trilha
      Rectangle { anchors.fill: parent; radius: width/2; color: root.colorTrack }

      // Fill com brilho
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        radius: parent.width / 2
        height: parent.height * Math.max(0, Math.min(1, root.value))
        color:  root.muted ? root.colorMuted : root.colorAccent
        Behavior on height { NumberAnimation { duration: 100; easing.type: Easing.OutCubic } }
        Behavior on color  { ColorAnimation  { duration: 150 } }

        // Brilho no topo
        Rectangle {
          anchors.top:   parent.top
          anchors.left:  parent.left
          anchors.right: parent.right
          height:  Math.min(10, parent.height)
          radius:  parent.radius
          color:   Qt.rgba(1, 1, 1, 0.20)
          visible: parent.height > 4
        }
      }

      // Percentual / "mudo"
      Text {
        anchors.centerIn: parent
        text:    root.label
        color:   Qt.rgba(1, 1, 1, 0.90)
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font"
        visible: root.label !== "" && !root.muted
      }
      Text {
        anchors.centerIn: parent
        text:    "mudo"
        color:   Qt.rgba(1, 1, 1, 0.40)
        font.pixelSize: 7; font.family: "JetBrainsMono Nerd Font"
        visible: root.muted
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MODO MEDIA
  // ══════════════════════════════════════════════════════════════════════
  RowLayout {
    visible:             root.mediaMode
    anchors.fill:        parent
    anchors.leftMargin:  20
    anchors.rightMargin: 20
    spacing: 14

    Text {
      Layout.alignment: Qt.AlignVCenter
      text:             root.icon
      color:            root.colorIcon
      font.pixelSize:   24
      font.family:      "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 150 } }
    }

    Text {
      Layout.fillWidth: true; Layout.alignment: Qt.AlignVCenter
      text:             root.label
      color:            root.colorText
      font.pixelSize:   11; font.family: "JetBrainsMono Nerd Font"
      wrapMode:         Text.WordWrap; maximumLineCount: 2
      elide:            Text.ElideRight; lineHeight: 1.25
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MODO TIMER — pill horizontal com botões de ação
  // ══════════════════════════════════════════════════════════════════════
  RowLayout {
    visible:             root.timerMode
    anchors.fill:        parent
    anchors.leftMargin:  20
    anchors.rightMargin: 20
    spacing: 12

    // Ícone + info textual
    Column {
      Layout.alignment: Qt.AlignVCenter
      spacing: 3

      Row {
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text:           "\uf017"
          color:          root.colorAccent
          font.pixelSize: 14; font.family: "JetBrainsMono Nerd Font"
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text:           root.timerLabel
          color:          Qt.rgba(1, 1, 1, 0.95)
          font.pixelSize: 22; font.weight: Font.Light; font.family: "JetBrainsMono Nerd Font"
        }
      }

      Text {
        text:           root.timerPhase
        color:          root.colorText
        font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
        visible:        root.timerPhase !== ""
      }
    }

    Item { Layout.fillWidth: true }

    // Botões de ação
    Row {
      Layout.alignment: Qt.AlignVCenter
      spacing: 6

      // Play/Pause
      OsdButton {
        icon:       root.timerRunning ? "\uf04c" : "\uf04b"
        accent:     true
        accentColor: root.colorAccent
        onActivated: root.timerToggle()
      }

      // +1 min
      OsdButton {
        icon: "+1"
        isText: true
        onActivated: root.timerAddMin()
      }

      // +intervalo completo (ex: "+25m", "+5m")
      OsdButton {
        visible: root.timerPhaseDuration > 0
        icon:    "+" + Math.round(root.timerPhaseDuration / 60) + "m"
        isText:  true
        onActivated: root.timerAddInterval()
      }

      // Próxima fase (pomodoro)
      OsdButton {
        visible: root.timerIsPomodoro
        icon:    "\uf051"
        onActivated: root.timerNext()
      }

      // Dispensar
      OsdButton {
        icon:    "\uf00d"
        onActivated: root.timerDismiss()
      }
    }
  }

  // ── Componente botão reutilizável ──────────────────────────────────────
  component OsdButton: Item {
    property string icon:        "\uf04b"
    property bool   isText:      false
    property bool   accent:      false
    property color  accentColor: "#ffb4a9"

    signal activated()

    width: 32; height: 32

    Rectangle {
      anchors.fill: parent; radius: width / 2
      color: parent.accent
        ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, btnArea.pressed ? 0.5 : 0.25)
        : (btnArea.containsMouse ? Qt.rgba(1,1,1,0.12) : Qt.rgba(1,1,1,0.07))
      border.color: parent.accent ? parent.accentColor : "transparent"
      border.width: parent.accent ? 1 : 0
      Behavior on color { ColorAnimation { duration: 100 } }
    }

    Text {
      anchors.centerIn: parent
      text:           parent.icon
      color:          parent.accent ? parent.accentColor : Qt.rgba(1,1,1,0.80)
      font.pixelSize: parent.isText ? 10 : 13
      font.weight:    parent.isText ? Font.Medium : Font.Normal
      font.family:    "JetBrainsMono Nerd Font"
    }

    MouseArea {
      id: btnArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked:    parent.activated()
    }
  }
}
