import QtQuick
import QtQuick.Layouts
import "../../.." // Colors singleton

// ── OsdContent ────────────────────────────────────────────────────────────
// Modos:
//  value < 0  → media   (horizontal 300×76)
//  value >= 0 → volume  (vertical 76×252)
//  timerMode  → timer   (horizontal 360×100)
//
// Volume >100%: barra fica vermelha + glow externo no pill.
// Percentual exibido abaixo da barra, legível.

Item {
  id: root

  // ── Props de dados ─────────────────────────────────────────────────────
  property string icon:      "\uf028"
  property real   value:     0.75   // fração: 0.0–1.5+  (< 0 = modo media)
  property string label:     "75%"
  property bool   muted:     false

  // ── Modo timer ─────────────────────────────────────────────────────────
  property bool   timerMode:          false
  property string timerLabel:         ""
  property string timerPhase:         ""
  property bool   timerIsPomodoro:    false
  property bool   timerRunning:       false
  property int    timerPhaseDuration: 0

  signal timerToggle()
  signal timerAddMin()
  signal timerAddInterval()
  signal timerNext()
  signal timerDismiss()

  // ── Cores via Colors singleton ─────────────────────────────────────────
  property color colorBg:     Colors.surface_container_low
  property color colorAccent: Colors.primary
  property color colorMuted:  Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.22)
  property color colorTrack:  Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.10)
  property color colorText:   Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.55)
  property color colorIcon:   Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.90)

  // ── Estado derivado ────────────────────────────────────────────────────
  readonly property bool mediaMode: !timerMode && value < 0
  readonly property bool overload:  !mediaMode && !timerMode && value > 1.0
  readonly property bool glowOn:    overload && !muted

  // Tamanhos por modo
  implicitWidth: {
    if (timerMode) return 360
    if (mediaMode) return 300
    return 76
  }
  implicitHeight: {
    if (timerMode) return 100
    if (mediaMode) return 76
    return 252
  }

  Behavior on implicitWidth  { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
  Behavior on implicitHeight { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

  // ── Glow externo (atrás do pill, z:-1) ────────────────────────────────
  Rectangle {
    anchors.fill: parent; anchors.margins: -7
    radius: Math.min(width, height) / 2
    color: "transparent"
    border.width: 6
    border.color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b,
                          root.glowOn ? 0.28 : 0)
    z: -1
    Behavior on border.color { ColorAnimation { duration: 250 } }
  }
  Rectangle {
    anchors.fill: parent; anchors.margins: -3
    radius: Math.min(width, height) / 2
    color: "transparent"
    border.width: 2
    border.color: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b,
                          root.glowOn ? 0.55 : 0)
    z: -1
    Behavior on border.color { ColorAnimation { duration: 200 } }
  }

  // ── Fundo pill ─────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    radius: Math.min(width, height) / 2
    color:  root.colorBg

    Rectangle {
      anchors.fill: parent; radius: parent.radius
      color: "transparent"
      border.color: Qt.rgba(Colors.outline_variant.r, Colors.outline_variant.g,
                            Colors.outline_variant.b, 0.30)
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
    anchors.bottomMargin: 16
    spacing:              10

    // Ícone
    Text {
      Layout.alignment: Qt.AlignHCenter
      text:           root.icon
      font.pixelSize: 22
      font.family:    "JetBrainsMono Nerd Font"
      color: root.muted
        ? Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.28)
        : (root.overload ? Colors.error : root.colorIcon)
      Behavior on color { ColorAnimation { duration: 200 } }
    }

    // Barra
    Item {
      Layout.alignment:  Qt.AlignHCenter
      Layout.fillHeight: true
      implicitWidth:     28

      // Trilha
      Rectangle {
        anchors.fill: parent
        radius:       width / 2
        color:        root.colorTrack
      }

      // Fill único — clamp em 100% visualmente, cor muda quando overload
      Rectangle {
        anchors.bottom: parent.bottom
        anchors.left:   parent.left
        anchors.right:  parent.right
        radius:         parent.width / 2
        height:         parent.height * Math.min(1.0, Math.max(0, root.value))
        color:          root.muted ? root.colorMuted
                      : root.overload ? Colors.error
                      : root.colorAccent
        Behavior on height { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
        Behavior on color  { ColorAnimation  { duration: 200 } }
      }
    }

    // Percentual / "mudo" — abaixo da barra
    Text {
      Layout.alignment: Qt.AlignHCenter
      text:           root.muted ? "mudo" : root.label
      font.pixelSize: 12
      font.weight:    Font.Medium
      font.family:    "JetBrainsMono Nerd Font"
      visible:        root.label !== "" || root.muted
      color: root.muted
        ? Qt.rgba(1, 1, 1, 0.35)
        : (root.overload ? Colors.error : Qt.rgba(1, 1, 1, 0.82))
      Behavior on color { ColorAnimation { duration: 200 } }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MODO MEDIA
  // ══════════════════════════════════════════════════════════════════════
  RowLayout {
    visible:             root.mediaMode
    anchors.fill:        parent
    anchors.leftMargin:  18
    anchors.rightMargin: 18
    spacing:             0

    Item {
      Layout.alignment: Qt.AlignVCenter
      implicitWidth:    44
      implicitHeight:   44

      Rectangle {
        anchors.centerIn: parent
        width: 40; height: 40; radius: 12
        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
      }
      Text {
        anchors.centerIn: parent
        text:           root.icon
        color:          root.colorAccent
        font.pixelSize: 20
        font.family:    "JetBrainsMono Nerd Font"
      }
    }

    Rectangle {
      Layout.alignment:   Qt.AlignVCenter
      Layout.leftMargin:  10
      Layout.rightMargin: 10
      width: 1; height: 32
      color: Qt.rgba(Colors.outline_variant.r, Colors.outline_variant.g,
                     Colors.outline_variant.b, 0.25)
    }

    Text {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignVCenter
      text:             root.label
      color:            root.colorText
      font.pixelSize:   11
      font.family:      "JetBrainsMono Nerd Font"
      wrapMode:         Text.WordWrap
      maximumLineCount: 2
      elide:            Text.ElideRight
      lineHeight:       1.30
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // MODO TIMER
  // ══════════════════════════════════════════════════════════════════════
  Rectangle {
    visible:      root.timerMode && root.timerPhaseDuration > 0
    anchors.fill: parent
    radius:       Math.min(width, height) / 2
    color:        "transparent"
    clip:         true

    readonly property real phaseProgress: {
      if (root.timerPhaseDuration <= 0) return 0
      var parts = root.timerLabel.split(":")
      if (parts.length < 2) return 0
      var remaining = parseInt(parts[0]) * 60 + parseInt(parts[1])
      return 1.0 - (remaining / root.timerPhaseDuration)
    }

    Rectangle {
      anchors.left:   parent.left
      anchors.top:    parent.top
      anchors.bottom: parent.bottom
      width:  parent.width * parent.phaseProgress
      radius: Math.min(parent.width, parent.height) / 2
      color:  Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.10)
      Behavior on width { NumberAnimation { duration: 500; easing.type: Easing.Linear } }
    }
  }

  RowLayout {
    visible:             root.timerMode
    anchors.fill:        parent
    anchors.leftMargin:  20
    anchors.rightMargin: 20
    spacing:             12

    Column {
      Layout.alignment: Qt.AlignVCenter
      spacing: 4

      Row {
        spacing: 6
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text:           "\uf017"
          color:          root.colorAccent
          font.pixelSize: 13
          font.family:    "JetBrainsMono Nerd Font"
        }
        Text {
          anchors.verticalCenter: parent.verticalCenter
          text:           root.timerLabel
          color:          Colors.on_surface
          font.pixelSize: 24
          font.weight:    Font.Light
          font.family:    "JetBrainsMono Nerd Font"
        }
      }

      Text {
        visible:        root.timerPhase !== ""
        text:           root.timerPhase
        color:          root.colorText
        font.pixelSize: 10
        font.family:    "JetBrainsMono Nerd Font"
      }
    }

    Item { Layout.fillWidth: true }

    Row {
      Layout.alignment: Qt.AlignVCenter
      spacing: 6

      OsdButton {
        icon:        root.timerRunning ? "\uf04c" : "\uf04b"
        accent:      true
        accentColor: root.colorAccent
        onActivated: root.timerToggle()
      }
      OsdButton {
        icon:        "+1"
        isText:      true
        accentColor: root.colorAccent
        onActivated: root.timerAddMin()
      }
      OsdButton {
        visible:     root.timerPhaseDuration > 0
        icon:        "+" + Math.round(root.timerPhaseDuration / 60) + "m"
        isText:      true
        accentColor: root.colorAccent
        onActivated: root.timerAddInterval()
      }
      OsdButton {
        visible:     root.timerIsPomodoro
        icon:        "\uf051"
        accentColor: root.colorAccent
        onActivated: root.timerNext()
      }
      OsdButton {
        icon:        "\uf00d"
        accentColor: root.colorAccent
        onActivated: root.timerDismiss()
      }
    }
  }

  // ── Botão reutilizável ─────────────────────────────────────────────────
  component OsdButton: Item {
    property string icon:        "\uf04b"
    property bool   isText:      false
    property bool   accent:      false
    property color  accentColor: Colors.primary

    signal activated()

    width: 32; height: 32

    Rectangle {
      anchors.fill: parent
      radius:       width / 2
      color: parent.accent
        ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b,
                  btnArea.pressed ? 0.55 : (btnArea.containsMouse ? 0.32 : 0.22))
        : (btnArea.pressed
            ? Qt.rgba(1, 1, 1, 0.16)
            : (btnArea.containsMouse
                ? Qt.rgba(1, 1, 1, 0.13)
                : Qt.rgba(Colors.on_surface.r, Colors.on_surface.g,
                          Colors.on_surface.b, 0.07)))
      border.color: parent.accent
        ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.60)
        : "transparent"
      border.width: parent.accent ? 1 : 0
      Behavior on color { ColorAnimation { duration: 100 } }
    }

    Text {
      anchors.centerIn: parent
      text:           parent.icon
      font.pixelSize: parent.isText ? 10 : 13
      font.weight:    parent.isText ? Font.Medium : Font.Normal
      font.family:    "JetBrainsMono Nerd Font"
      color: parent.accent
        ? parent.accentColor
        : Qt.rgba(Colors.on_surface.r, Colors.on_surface.g, Colors.on_surface.b, 0.80)
    }

    MouseArea {
      id:           btnArea
      anchors.fill: parent
      hoverEnabled: true
      onClicked:    parent.activated()
    }
  }
}
