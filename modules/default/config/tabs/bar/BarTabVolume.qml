import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import Quickshell.Services.Pipewire
import '../../components' as C

C.CfgScroll {
  id: root

  required property var   config
  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg
  // colorError: opcional — o ConfigWindow atual não passa; usa fallback do tema
  property color colorError: "#f38ba8"

  signal changed(var opts)
  function g(key) { return config ? config.get("volume", key) : undefined }

  // ── EasyEffects state ─────────────────────────────────────────────────
  property bool   eeRunning:        false
  property bool   eeBypassed:       false
  property string eeActiveOutput:   ""
  property string eeActiveInput:    ""
  property var    eeOutputProfiles: []
  property var    eeInputProfiles:  []

  Process {
    id: eeStatusProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => eeStatusProc._buf += l + "\n" }
    onRunningChanged: {
      if (running) return
      var out = eeStatusProc._buf.trim(); eeStatusProc._buf = ""
      root.eeRunning = out !== "" && !out.includes("not running")
      var lines = out.split("\n")
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i].trim()
        if (l.startsWith("output:")) root.eeActiveOutput = l.replace("output:", "").trim()
        if (l.startsWith("input:"))  root.eeActiveInput  = l.replace("input:",  "").trim()
      }
    }
  }

  Process {
    id: eeListProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => eeListProc._buf += l + "\n" }
    onRunningChanged: {
      if (running) return
      var raw = eeListProc._buf.trim(); eeListProc._buf = ""
      var lines = raw.split("\n")
      var outputs = []; var inputs = []; var inInput = false
      for (var i = 0; i < lines.length; i++) {
        var l = lines[i]
        if (l.includes("saída") || l.toLowerCase().includes("output")) { inInput = false; continue }
        if (l.includes("entrada") || l.toLowerCase().includes("input")) { inInput = true;  continue }
        var m = l.match(/^\s*\d+\s+(.+)$/)
        if (m) {
          var name = m[1].trim()
          if (inInput) inputs.push(name)
          else         outputs.push(name)
        }
      }
      root.eeOutputProfiles = outputs
      root.eeInputProfiles  = inputs
    }
  }

  Process { id: eeApplyProc }
  Process { id: eeBypassProc }
  Process { id: setDefaultSink }
  Process { id: setDefaultSource }

  function refresh() {
    if (!eeStatusProc.running) { eeStatusProc.command = ["easyeffects", "-s"]; eeStatusProc.running = true }
    if (!eeListProc.running)   { eeListProc.command   = ["easyeffects", "-p"]; eeListProc.running   = true }
  }

  function applyPreset(type, name) {
    eeApplyProc.command = ["easyeffects", "-l", name]; eeApplyProc.running = true
    if (type === "output") root.eeActiveOutput = name
    else                   root.eeActiveInput  = name
  }

  function toggleBypass() {
    eeBypassProc.command = ["easyeffects", "--bypass-toggle"]; eeBypassProc.running = true
    root.eeBypassed = !root.eeBypassed
  }

  Component.onCompleted: refresh()

  // ── Rastreio PipeWire ─────────────────────────────────────────────────
  PwObjectTracker {
    id: pwTrack
    objects: {
      var arr = [], nodes = Pipewire.nodes.values
      for (var i = 0; i < nodes.length; i++)
        if (nodes[i].audio) arr.push(nodes[i])
      return arr
    }
  }

  // ── GERAL (configuração) ──────────────────────────────────────────────
  C.CfgSection { title: "GERAL"; colorTextDim: root.colorTextDim }
  C.CfgToggle {
    label: "Mostrar saída"; checked: root.g("showSink") !== false
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "volume", key: "showSink", value: !(root.g("showSink") !== false) })
  }
  C.CfgToggle {
    label: "Mostrar entrada"; checked: root.g("showSource") !== false
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ moduleId: "volume", key: "showSource", value: !(root.g("showSource") !== false) })
  }
  C.CfgSlider {
    label: "Volume máximo"; value: Math.round((root.g("maxVol") || 1.5) * 10) / 10
    from: 1.0; to: 2.0; step: 0.1; unit: "×"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ moduleId: "volume", key: "maxVol", value: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── MIXER — Saída ─────────────────────────────────────────────────────
  C.CfgSection { title: "SAÍDA (SINKS)"; colorTextDim: root.colorTextDim }

  PwDevicePanel {
    width: parent.width
    isSink:          true
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorError:      root.colorError
    colorSidebar:    root.colorSidebar
    colorDivider:    root.colorDivider
    colorProgressBg: root.colorProgressBg
    onSetDefault: (node) => {
      setDefaultSink.command = ["pactl", "set-default-sink", node.name]
      setDefaultSink.running = true
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── MIXER — Entrada ───────────────────────────────────────────────────
  C.CfgSection { title: "ENTRADA (SOURCES / MICROFONES)"; colorTextDim: root.colorTextDim }

  PwDevicePanel {
    width: parent.width
    isSink:          false
    colorAccent:     root.colorAccent
    colorTextDim:    root.colorTextDim
    colorText:       root.colorText
    colorError:      root.colorError
    colorSidebar:    root.colorSidebar
    colorDivider:    root.colorDivider
    colorProgressBg: root.colorProgressBg
    onSetDefault: (node) => {
      setDefaultSource.command = ["pactl", "set-default-source", node.name]
      setDefaultSource.running = true
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── EasyEffects ───────────────────────────────────────────────────────
  C.CfgSection { title: "EASYEFFECTS"; colorTextDim: root.colorTextDim }

  Rectangle {
    width: parent.width; height: 38; radius: 8
    color: Qt.rgba(1,1,1,0.03); border.color: Qt.rgba(1,1,1,0.07); border.width: 1

    RowLayout {
      anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
      spacing: 8

      Rectangle {
        width: 8; height: 8; radius: 4
        color: root.eeRunning ? "#a6e3a1" : "#6c7086"
        Behavior on color { ColorAnimation { duration: 200 } }
      }
      Text {
        text: root.eeRunning
          ? (root.eeBypassed ? "EasyEffects (bypass ativo)" : "EasyEffects ativo")
          : "EasyEffects não detectado"
        color: root.colorTextDim; font.pixelSize: 10; Layout.fillWidth: true
      }

      Rectangle {
        visible: root.eeRunning
        height: 26; width: bypassLbl.implicitWidth + 14; radius: 5
        color: bypassHov.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
        border.color: root.eeBypassed
          ? Qt.rgba(root.colorError.r, root.colorError.g, root.colorError.b, 0.5)
          : Qt.rgba(1,1,1,0.1)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
        Text {
          id: bypassLbl; anchors.centerIn: parent
          text: root.eeBypassed ? "\uf074  Bypass ON" : "\uf074  Bypass OFF"
          color: root.eeBypassed ? root.colorError : root.colorTextDim
          font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
        }
        MouseArea { id: bypassHov; anchors.fill: parent; hoverEnabled: true
          onClicked: root.toggleBypass() }
      }

      Rectangle {
        height: 26; width: 26; radius: 5
        color: refreshHov.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
        Behavior on color { ColorAnimation { duration: 80 } }
        Text { anchors.centerIn: parent; text: "\uf021"
          color: root.colorTextDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
        MouseArea { id: refreshHov; anchors.fill: parent; hoverEnabled: true
          onClicked: root.refresh() }
      }
    }
  }

  C.CfgSection { title: "PRESET SAÍDA"; colorTextDim: root.colorTextDim }
  PresetList {
    width: parent.width
    profiles:      root.eeOutputProfiles
    activeProfile: root.eeActiveOutput
    colorAccent:   root.colorAccent
    colorTextDim:  root.colorTextDim
    colorText:     root.colorText
    onSelected: (name) => root.applyPreset("output", name)
  }

  C.CfgSection { title: "PRESET ENTRADA"; colorTextDim: root.colorTextDim }
  PresetList {
    width: parent.width
    profiles:      root.eeInputProfiles
    activeProfile: root.eeActiveInput
    colorAccent:   root.colorAccent
    colorTextDim:  root.colorTextDim
    colorText:     root.colorText
    onSelected: (name) => root.applyPreset("input", name)
  }

  C.CfgDiv { colorDivider: root.colorDivider }

  // ── CORES ─────────────────────────────────────────────────────────────
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }
  C.CfgPalette {
    label: "Texto"; value: root.g("textColor") || "on_surface"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "volume", key: "textColor", value: v })
  }
  C.CfgPalette {
    label: "Dim"; value: root.g("dimColor") || "on_surface_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "volume", key: "dimColor", value: v })
  }
  C.CfgPalette {
    label: "Acento"; value: root.g("accentColor") || "primary"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "volume", key: "accentColor", value: v })
  }
  C.CfgPalette {
    label: "Mutado"; value: root.g("mutedColor") || "error"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "volume", key: "mutedColor", value: v })
  }
  C.CfgPalette {
    label: "Fundo slider"; value: root.g("progressBg") || "outline_variant"
    colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => root.changed({ moduleId: "volume", key: "progressBg", value: v })
  }

  // ══════════════════════════════════════════════════════════════════════
  // Componente: painel de dispositivos PipeWire (sink ou source)
  // ══════════════════════════════════════════════════════════════════════
  component PwDevicePanel: Column {
    id: panel

    required property bool  isSink
    required property color colorAccent
    required property color colorTextDim
    required property color colorText
    required property color colorError
    required property color colorSidebar
    required property color colorDivider
    required property color colorProgressBg

    signal setDefault(var node)

    spacing: 6

    readonly property var allDevices: {
      var arr = [], nodes = Pipewire.nodes.values
      for (var i = 0; i < nodes.length; i++) {
        var n = nodes[i]
        if (!n.audio) continue
        if (panel.isSink && n.isSink) { arr.push(n); continue }
        if (!panel.isSink && n.isSource && !(n.name || "").includes("monitor")) arr.push(n)
      }
      return arr
    }

    readonly property var defaultDevice: panel.isSink
      ? Pipewire.defaultAudioSink
      : Pipewire.defaultAudioSource

    readonly property var otherDevices: {
      var arr = []
      for (var i = 0; i < panel.allDevices.length; i++)
        if (panel.allDevices[i] !== panel.defaultDevice) arr.push(panel.allDevices[i])
      return arr
    }

    property bool _othersOpen: false

    // Card do dispositivo padrão
    Rectangle {
      width:  parent.width
      height: defaultCol.implicitHeight + 16
      radius: 8
      color:  Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.07)
      border.color: Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.35)
      border.width: 1

      Column {
        id: defaultCol
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8

        Row {
          width: parent.width; spacing: 8
          Column {
            width: parent.width - padraoBadge.width - 8; spacing: 2
            Text {
              width: parent.width
              text: panel.defaultDevice
                ? (panel.defaultDevice.nickname || panel.defaultDevice.description || panel.defaultDevice.name || "Desconhecido")
                : (panel.isSink ? "(nenhuma saída)" : "(nenhuma entrada)")
              color: panel.colorText; font.pixelSize: 11; elide: Text.ElideRight
            }
            Text {
              width: parent.width
              text: panel.defaultDevice ? (panel.defaultDevice.name || "") : ""
              color: panel.colorTextDim; font.pixelSize: 9
              font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight
            }
          }
          Rectangle {
            id: padraoBadge
            height: 18; width: padLbl.implicitWidth + 10; radius: 4
            color: Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.2)
            Text { id: padLbl; anchors.centerIn: parent; text: "padrão"
              color: panel.colorAccent; font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
          }
        }

        VolumeRow {
          width:   parent.width
          visible: panel.defaultDevice !== null && panel.defaultDevice !== undefined
          node:    panel.defaultDevice
          colorAccent:     panel.colorAccent
          colorTextDim:    panel.colorTextDim
          colorText:       panel.colorText
          colorError:      panel.colorError
          colorProgressBg: panel.colorProgressBg
        }
      }
    }

    // Botão "outros dispositivos"
    Rectangle {
      visible: panel.otherDevices.length > 0
      width: parent.width; height: 28; radius: 6
      color: othersBtn.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.03)
      border.color: Qt.rgba(1,1,1,0.09); border.width: 1
      Behavior on color { ColorAnimation { duration: 60 } }

      Row {
        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
        spacing: 6
        Text { anchors.verticalCenter: parent.verticalCenter
          text:           panel._othersOpen ? "\uf0d8" : "\uf0d7"
          color:          panel.colorTextDim
          font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }
        Text { anchors.verticalCenter: parent.verticalCenter
          text: panel._othersOpen
            ? "Ocultar outros dispositivos"
            : ("Outros dispositivos (" + panel.otherDevices.length + ")")
          color: panel.colorTextDim; font.pixelSize: 10 }
      }
      MouseArea { id: othersBtn; anchors.fill: parent; hoverEnabled: true
        onClicked: panel._othersOpen = !panel._othersOpen }
    }

    // Lista expansível dos outros dispositivos
    Column {
      visible: panel._othersOpen && panel.otherDevices.length > 0
      width:   parent.width; spacing: 5

      Repeater {
        model: panel.otherDevices
        delegate: Rectangle {
          required property var modelData
          required property int index
          width:  parent.width; height: otherCol.implicitHeight + 14; radius: 7
          color:  Qt.rgba(1,1,1,0.03); border.color: Qt.rgba(1,1,1,0.07); border.width: 1

          Column {
            id: otherCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 6

            Row {
              width: parent.width; spacing: 8
              Column {
                width: parent.width - setDefaultBtn.width - 8; spacing: 2
                Text {
                  width: parent.width
                  text: modelData.nickname || modelData.description || modelData.name || "Desconhecido"
                  color: panel.colorText; font.pixelSize: 10; elide: Text.ElideRight
                }
                Text {
                  width: parent.width
                  text: modelData.name || ""
                  color: panel.colorTextDim; font.pixelSize: 8
                  font.family: "JetBrainsMono Nerd Font"; elide: Text.ElideRight
                }
              }
              Rectangle {
                id: setDefaultBtn
                height: 20; width: setLbl.implicitWidth + 10; radius: 4
                color: setHov.containsMouse
                  ? Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.2)
                  : Qt.rgba(1,1,1,0.06)
                border.color: Qt.rgba(panel.colorAccent.r, panel.colorAccent.g, panel.colorAccent.b, 0.3)
                border.width: 1
                Behavior on color { ColorAnimation { duration: 60 } }
                Text { id: setLbl; anchors.centerIn: parent; text: "\uf0ec  definir padrão"
                  color: panel.colorAccent; font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
                MouseArea { id: setHov; anchors.fill: parent; hoverEnabled: true
                  onClicked: panel.setDefault(modelData) }
              }
            }

            VolumeRow {
              width:           parent.width
              node:            modelData
              colorAccent:     panel.colorAccent
              colorTextDim:    panel.colorTextDim
              colorText:       panel.colorText
              colorError:      panel.colorError
              colorProgressBg: panel.colorProgressBg
            }
          }
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Componente: linha de volume (mute + track 0–150% + valor)
  // ══════════════════════════════════════════════════════════════════════
  component VolumeRow: Row {
    id: vr

    required property var   node
    required property color colorAccent
    required property color colorTextDim
    required property color colorText
    required property color colorError
    required property color colorProgressBg

    spacing: 8; height: 20

    readonly property real vol:   (node && node.audio) ? node.audio.volume : 0
    readonly property bool muted: (node && node.audio) ? node.audio.muted  : false

    Rectangle {
      width: 22; height: 22; radius: 4
      color: muteHov.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
      Behavior on color { ColorAnimation { duration: 60 } }
      Text {
        anchors.centerIn: parent
        text: vr.muted ? "\uf026"
            : (vr.vol > 0.66 ? "\uf028" : (vr.vol > 0.33 ? "\uf027" : "\uf026"))
        color: vr.muted ? vr.colorError : vr.colorTextDim
        font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
      }
      MouseArea { id: muteHov; anchors.fill: parent; hoverEnabled: true
        onClicked: { if (vr.node && vr.node.audio) vr.node.audio.muted = !vr.node.audio.muted } }
    }

    Item {
      width:  parent.width - 22 - 40 - 16
      height: 20
      readonly property real ratio: Math.min(1.5, Math.max(0, vr.vol)) / 1.5

      Rectangle {
        id: track
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
        height: 5; radius: 3; color: Qt.rgba(1,1,1,0.1)

        Rectangle {
          anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
          radius: 3; width: parent.parent.ratio * parent.width
          color: vr.vol > 1.0
            ? Qt.rgba(vr.colorError.r, vr.colorError.g, vr.colorError.b, 0.85)
            : (vr.muted ? Qt.rgba(1,1,1,0.2) : vr.colorAccent)
          Behavior on color { ColorAnimation { duration: 100 } }
        }
      }

      Rectangle {
        anchors.verticalCenter: track.verticalCenter
        x: (2/3) * parent.width - 1; width: 2; height: 10; radius: 1
        color: Qt.rgba(1,1,1,0.3)
      }
      Text {
        anchors { top: track.bottom; topMargin: 2 }
        x: (2/3) * parent.width - width/2
        text: "100%"; font.pixelSize: 7; font.family: "JetBrainsMono Nerd Font"
        color: Qt.rgba(vr.colorTextDim.r, vr.colorTextDim.g, vr.colorTextDim.b, 0.5)
      }

      Rectangle {
        id: thumb
        anchors.verticalCenter: parent.verticalCenter
        x: parent.ratio * (parent.width - width)
        width: 14; height: 14; radius: 7
        color: vr.muted ? Qt.rgba(1,1,1,0.35) : "white"
        Behavior on x { enabled: !sma.pressed; NumberAnimation { duration: 60 } }
      }

      MouseArea {
        id: sma; anchors.fill: parent
        function apply(mx) {
          var r = Math.max(0, Math.min(1, mx / parent.width))
          if (vr.node && vr.node.audio) vr.node.audio.volume = r * 1.5
        }
        onPositionChanged: (m) => { if (pressed) apply(m.x) }
        onClicked:         (m) => apply(m.x)
      }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      width: 40; text: Math.round(vr.vol * 100) + "%"
      color: vr.vol > 1.0 ? vr.colorError : vr.colorText
      font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font"
      horizontalAlignment: Text.AlignRight
      Behavior on color { ColorAnimation { duration: 100 } }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // Componente: lista de presets EasyEffects
  // ══════════════════════════════════════════════════════════════════════
  component PresetList: Rectangle {
    id: presetList

    required property var    profiles
    required property string activeProfile
    required property color  colorAccent
    required property color  colorTextDim
    required property color  colorText

    signal selected(string name)

    height: Math.max(40, pCol.implicitHeight + 16)
    radius: 8; color: Qt.rgba(1,1,1,0.03)
    border.color: Qt.rgba(1,1,1,0.07); border.width: 1

    Column {
      id: pCol
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
      spacing: 3

      Repeater {
        model: presetList.profiles.length > 0 ? presetList.profiles : ["(nenhum preset encontrado)"]
        delegate: Rectangle {
          required property string modelData
          required property int    index
          readonly property bool isActive:      presetList.activeProfile === modelData
          readonly property bool isPlaceholder: presetList.profiles.length === 0
          width: parent.width; height: 30; radius: 5
          color: isActive
            ? Qt.rgba(presetList.colorAccent.r, presetList.colorAccent.g, presetList.colorAccent.b, 0.15)
            : (pH.containsMouse && !isPlaceholder ? Qt.rgba(1,1,1,0.06) : "transparent")
          border.color: isActive
            ? Qt.rgba(presetList.colorAccent.r, presetList.colorAccent.g, presetList.colorAccent.b, 0.4)
            : "transparent"
          border.width: 1
          Behavior on color { ColorAnimation { duration: 80 } }
          Row {
            anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
            spacing: 6
            Text { anchors.verticalCenter: parent.verticalCenter
              text: isActive ? "\uf111" : "\uf10c"
              color: isActive ? presetList.colorAccent : presetList.colorTextDim
              font.pixelSize: 8; font.family: "JetBrainsMono Nerd Font" }
            Text { anchors.verticalCenter: parent.verticalCenter; text: modelData
              color: isPlaceholder ? presetList.colorTextDim : presetList.colorText
              font.pixelSize: 10; elide: Text.ElideRight }
          }
          MouseArea { id: pH; anchors.fill: parent; hoverEnabled: true
            enabled: !parent.isPlaceholder
            onClicked: presetList.selected(modelData) }
        }
      }
    }
  }
}
