import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Widgets
import QtQuick
import QtQuick.Layouts

// ── Conteúdo do Volume Panel ───────────────────────────────────────────────
// Pode ser embutido em PanelWindow, PopupWindow ou qualquer outro container.
// O host conecta closeRequested() para fechar a janela.
Item {
  id: root

  // ── Filtros opcionais ──────────────────────────────────────────────────
  property bool showOnlySink:   false
  property bool showOnlySource: false

  // ── Cores injetadas pelo host ──────────────────────────────────────────
  property color colorPanelBg:    "#1f1f1f"
  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorMuted:      "#cf6679"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  // ── Sinal para o host fechar a janela ─────────────────────────────────
  signal closeRequested()

  // ── Aba activa ─────────────────────────────────────────────────────────
  property string activeTab: "devices"

  // ── Pipewire — nós ─────────────────────────────────────────────────────
  readonly property var sink:   Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource

  readonly property var _virtualNodeNames: [
    "easyeffects_sink", "easyeffects_source",
    "easyeffects", "calf-",
    "null-sink", "null-source",
    "pipewire-null",
  ]

  function _isVirtual(node) {
    if (!node) return true
    var cls = (node.properties["media.class"] || "").toLowerCase()
    if (cls.includes("virtual")) return true
    var nm = (node.name || "").toLowerCase()
    for (var i = 0; i < _virtualNodeNames.length; i++) {
      if (nm.includes(_virtualNodeNames[i])) return true
    }
    return false
  }

  readonly property var sinkDevices: {
    var list = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (!n.audio) continue
      if (!n.isSink) continue
      if (n.isStream) continue
      if (_isVirtual(n)) continue
      list.push(n)
    }
    return list
  }

  readonly property var sourceDevices: {
    var list = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (!n.audio) continue
      if (n.isSink) continue
      if (n.isStream) continue
      if (_isVirtual(n)) continue
      list.push(n)
    }
    return list
  }

  // ── Streams de aplicativos ─────────────────────────────────────────────
  // Com EasyEffects, o Spotify cria "Stream/Output/Audio" mas tem isSink=false
  // no grafo PipeWire (flui para easyeffects_sink). Usar media.class evita
  // a confusão — Output = reprodução, Input = captura de microfone.
  readonly property var appSinkStreams: {
    var list = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (!n.audio || !n.isStream) continue
      var cls = (n.properties["media.class"] || "").toLowerCase()
      if (cls.includes("output")) list.push(n)
    }
    return list
  }

  readonly property var appSourceStreams: {
    var list = []
    for (var i = 0; i < Pipewire.nodes.values.length; i++) {
      var n = Pipewire.nodes.values[i]
      if (!n.audio || !n.isStream) continue
      var cls = (n.properties["media.class"] || "").toLowerCase()
      if (cls.includes("input")) list.push(n)
    }
    return list
  }

  // Lista activa para a aba de Aplicativos: depende dos filtros do popup.
  //   showOnlySource → captura (source streams)
  //   showOnlySink   → reprodução (sink streams)
  //   nenhum         → reprodução + captura (painel completo)
  readonly property var activeAppStreams: {
    if (showOnlySource) return appSourceStreams
    if (showOnlySink)   return appSinkStreams
    return appSinkStreams.concat(appSourceStreams)
  }

  PwObjectTracker {
    id: tracker
    // Rastreia todos os nós do PipeWire diretamente.
    // Arrays JS derivados (appSinkStreams, etc.) não são reativos —
    // o tracker não detectaria streams novos se usássemos essas listas.
    objects: Pipewire.nodes.values
  }

  // ── Resolução de nome de dispositivo ──────────────────────────────────
  function deviceName(node) {
    if (!node) return ""
    var p = node.properties || {}

    var nick        = (p["node.nick"]        || "").trim()
    var desc        = (p["node.description"] || "").trim()
    var profile     = (p["device.profile.description"] || "").trim()

    var genericProfiles = [
      "estéreo analógico", "analog stereo", "stereo",
      "estéreo digital (hdmi)", "digital stereo (hdmi)",
      "mono", "surround"
    ]
    var genericNicks = ["usb audio", "usb audio #1", "usb audio #2", "usb audio #3"]

    function isGenericProfile(pr) {
      return !pr || genericProfiles.indexOf(pr.toLowerCase()) !== -1
    }

    function productFromDesc(d, prof) {
      if (!d) return ""
      var suffixes = []
      if (prof) suffixes.push(prof)
      suffixes = suffixes.concat([
        "Estéreo analógico", "Analog Stereo", "Stereo",
        "Estéreo digital (HDMI)", "Digital Stereo (HDMI)", "Mono"
      ])
      for (var i = 0; i < suffixes.length; i++) {
        var s = suffixes[i]
        if (s && d.endsWith(" " + s))
          return d.slice(0, d.length - s.length - 1).trim()
      }
      return d
    }

    var nickIsGeneric = !nick || genericNicks.indexOf(nick.toLowerCase()) !== -1
    var product = productFromDesc(desc, profile)

    if (!nickIsGeneric) {
      if (!isGenericProfile(profile)) return nick + " · " + profile
      return nick
    }

    if (product) {
      if (!isGenericProfile(profile)) return product + " · " + profile
      return product
    }

    if (desc) return desc
    return (node.nickname || node.name || "Dispositivo").trim()
  }

  // ── Conteúdo ───────────────────────────────────────────────────────────
  ColumnLayout {
    anchors.fill:    parent
    anchors.margins: 14
    spacing: 10

    // ── Abas ──────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true
      spacing: 6

      Repeater {
        // "id" é palavra reservada em QML — modelData.id retorna undefined.
        model: [
          { tabId: "devices", label: "\uf028  Dispositivos" },
          { tabId: "apps",    label: "\uf001  Aplicativos"  }
        ]

        Rectangle {
          required property var modelData
          readonly property bool active: root.activeTab === modelData.tabId

          Layout.preferredHeight: 22
          Layout.preferredWidth:  tabLabel.implicitWidth + 14
          radius: height / 2
          color: active
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
            : Qt.rgba(1, 1, 1, 0.05)
          border.color: active ? root.colorAccent : "transparent"
          border.width: 1

          Text {
            id: tabLabel
            anchors.centerIn: parent
            text:           parent.modelData.label
            color:          parent.active ? root.colorAccent : root.colorTextDim
            font.pixelSize: 10
            font.family:    "JetBrainsMono Nerd Font"
          }
          MouseArea {
            anchors.fill: parent
            onClicked:    root.activeTab = parent.modelData.tabId
          }
        }
      }

      Item { Layout.fillWidth: true }
    }

    // ── Aba: Dispositivos ──────────────────────────────────────────────
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 10
      visible: root.activeTab === "devices"

      // Sink principal
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: !root.showOnlySource

        RowLayout {
          Layout.fillWidth: true

          Text {
            text:           root.sink && root.sink.audio && root.sink.audio.muted
                              ? "\uf026" : "\uf028"
            color:          root.sink && root.sink.audio && root.sink.audio.muted
                              ? root.colorMuted : root.colorAccent
            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          Text {
            Layout.fillWidth: true; Layout.leftMargin: 6
            text:           root.sink ? root.deviceName(root.sink) : "Saída"
            color:          root.colorText; font.pixelSize: 11; font.weight: Font.Medium
            elide:          Text.ElideRight
          }

          MuteButton {
            node: root.sink; isSink: true
            textColor: root.colorText; mutedColor: root.colorMuted
          }

          Text {
            text:           root.sink && root.sink.audio ? Math.round(root.sink.audio.volume * 100) + "%" : "–%"
            color:          root.colorTextDim; font.pixelSize: 10
            Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight
          }
        }

        VolumeSlider { Layout.fillWidth: true; node: root.sink
          accentColor: root.colorAccent; bgColor: root.colorProgressBg; mutedColor: root.colorMuted }

        Repeater {
          model: root.sinkDevices
          delegate: DeviceRow {
            required property var modelData
            Layout.fillWidth: true
            node: modelData; isDefault: root.sink === modelData
            textColor: root.colorText; dimColor: root.colorTextDim; accentColor: root.colorAccent
            onSetDefault: Pipewire.preferredDefaultAudioSink = modelData
          }
        }
      }

      // Divisor
      Rectangle {
        Layout.fillWidth: true; height: 1
        color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.4)
        visible: !root.showOnlySink && !root.showOnlySource
      }

      // Source principal
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        visible: !root.showOnlySink

        RowLayout {
          Layout.fillWidth: true

          Text {
            text:           root.source && root.source.audio && root.source.audio.muted
                              ? "\uf131" : "\uf130"
            color:          root.source && root.source.audio && root.source.audio.muted
                              ? root.colorMuted : root.colorAccent
            font.pixelSize: 13; font.family: "JetBrainsMono Nerd Font"
            Behavior on color { ColorAnimation { duration: 150 } }
          }

          Text {
            Layout.fillWidth: true; Layout.leftMargin: 6
            text:           root.source ? root.deviceName(root.source) : "Microfone"
            color:          root.colorText; font.pixelSize: 11; font.weight: Font.Medium
            elide:          Text.ElideRight
          }

          MuteButton {
            node: root.source; isSink: false
            textColor: root.colorText; mutedColor: root.colorMuted
          }

          Text {
            text:           root.source && root.source.audio ? Math.round(root.source.audio.volume * 100) + "%" : "–%"
            color:          root.colorTextDim; font.pixelSize: 10
            Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight
          }
        }

        VolumeSlider { Layout.fillWidth: true; node: root.source
          accentColor: root.colorAccent; bgColor: root.colorProgressBg; mutedColor: root.colorMuted }

        Repeater {
          model: root.sourceDevices
          delegate: DeviceRow {
            required property var modelData
            Layout.fillWidth: true
            node: modelData; isDefault: root.source === modelData
            textColor: root.colorText; dimColor: root.colorTextDim; accentColor: root.colorAccent
            onSetDefault: Pipewire.preferredDefaultAudioSource = modelData
          }
        }
      }
    }

    // ── Aba: Aplicativos ───────────────────────────────────────────────
    ColumnLayout {
      Layout.fillWidth: true
      spacing: 6
      visible: root.activeTab === "apps"

      Text {
        Layout.fillWidth: true
        visible:          root.activeAppStreams.length === 0
        text:             root.showOnlySource
                            ? "Nenhum aplicativo capturando"
                            : "Nenhum aplicativo reproduzindo"
        color:            root.colorTextDim
        font.pixelSize:   11
        horizontalAlignment: Text.AlignHCenter
      }

      Repeater {
        model: root.activeAppStreams

        delegate: ColumnLayout {
          required property var modelData
          Layout.fillWidth: true
          spacing: 4

          RowLayout {
            Layout.fillWidth: true

            Item {
              id: appIconItem
              width: 16; height: 16

              readonly property string appId: {
                var props = modelData.properties
                return (props["application.process.binary"]
                     || props["application.name"]
                     || "").toLowerCase().replace(/\s+/g, "-")
              }
              readonly property var entry: {
                var _l = DesktopEntries.applications.values.length
                if (!appId) return null
                return DesktopEntries.byId(appId)
                    || DesktopEntries.byId(appId.replace(/-/g, ""))
                    || DesktopEntries.heuristicLookup(appId)
                    || null
              }
              readonly property string iconName: {
                if (!entry) return ""
                var icon = entry.icon || ""
                if (!icon || icon.startsWith("/")) return icon
                return icon.replace(/-launcher$/, "").replace(/-client$/, "")
              }
              readonly property var iconPaths: {
                var n = iconName
                if (!n) return []
                if (n.startsWith("/")) return ["file://" + n]
                return [
                  "file:///usr/share/icons/Papirus/16x16/apps/"  + n + ".svg",
                  "file:///usr/share/icons/Papirus/32x32/apps/"  + n + ".svg",
                  "file:///usr/share/icons/hicolor/scalable/apps/" + n + ".svg",
                  "file:///usr/share/icons/hicolor/48x48/apps/"  + n + ".png",
                  "file:///usr/share/pixmaps/" + n + ".png",
                  "file:///usr/share/pixmaps/" + n + ".svg",
                ]
              }
              property int  attempt:   0
              property bool exhausted: false
              onIconPathsChanged: { attempt = 0; exhausted = false }

              Image {
                id: appImg
                anchors.fill: parent
                fillMode:     Image.PreserveAspectFit
                visible:      !appIconItem.exhausted && appIconItem.iconPaths.length > 0
                source:       appIconItem.iconPaths.length > 0
                  ? appIconItem.iconPaths[Math.min(appIconItem.attempt, appIconItem.iconPaths.length - 1)]
                  : ""
                onStatusChanged: {
                  if (status === Image.Error) {
                    if (appIconItem.attempt < appIconItem.iconPaths.length - 1)
                      appIconItem.attempt++
                    else
                      appIconItem.exhausted = true
                  }
                }
              }
              Text {
                anchors.centerIn: parent
                visible:        appIconItem.exhausted || appIconItem.iconPaths.length === 0
                text:           "\uf001"
                color:          root.colorTextDim
                font.pixelSize: 11
                font.family:    "JetBrainsMono Nerd Font"
              }
            }

            Text {
              Layout.fillWidth: true; Layout.leftMargin: 4
              text: {
                var props = modelData.properties
                var name  = props["application.name"]
                         || props["node.nick"]
                         || props["media.name"]
                         || props["application.process.binary"]
                         || modelData.nickname
                         || modelData.name
                         || ""
                // "audio-src" e "audio-sink" são nomes genéricos do PipeWire
                // usados pelo Spotify e outros apps que não exportam application.name.
                // Tenta recuperar o nome pelo binário do processo.
                if (!name || name === "audio-src" || name === "audio-sink") {
                  var bin = props["application.process.binary"] || ""
                  if (bin) name = bin.charAt(0).toUpperCase() + bin.slice(1)
                }
                return name || "App"
              }
              color:          root.colorText
              font.pixelSize: 11
              elide:          Text.ElideRight
            }

            MuteButton {
              node: modelData; isSink: modelData.isSink
              textColor: root.colorText; mutedColor: root.colorMuted
            }

            Text {
              text:           modelData.audio ? Math.round(modelData.audio.volume * 100) + "%" : "–%"
              color:          root.colorTextDim; font.pixelSize: 10
              Layout.preferredWidth: 32; horizontalAlignment: Text.AlignRight
            }
          }

          VolumeSlider {
            Layout.fillWidth: true; node: modelData
            accentColor: root.colorAccent; bgColor: root.colorProgressBg; mutedColor: root.colorMuted
          }
        }
      }
    }

    Item { Layout.fillHeight: true }
  }

  // ── Componentes inline ─────────────────────────────────────────────────

  component MuteButton: Item {
    property var   node
    property bool  isSink:     true
    property color textColor:  "white"
    property color mutedColor: "red"

    width: 24; height: 24

    readonly property bool muted: node && node.audio ? node.audio.muted : false

    Rectangle {
      anchors.fill: parent; radius: width / 2
      color: parent.muted
        ? Qt.rgba(parent.mutedColor.r, parent.mutedColor.g, parent.mutedColor.b, 0.2)
        : Qt.rgba(1, 1, 1, 0.06)
    }
    Text {
      anchors.centerIn: parent
      text: {
        if (parent.isSink) return parent.muted ? "\uf026" : "\uf028"
        return parent.muted ? "\uf131" : "\uf130"
      }
      color:          parent.muted ? parent.mutedColor : parent.textColor
      font.pixelSize: 11; font.family: "JetBrainsMono Nerd Font"
      Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea {
      anchors.fill: parent
      onClicked: { if (parent.node && parent.node.audio) parent.node.audio.muted = !parent.node.audio.muted }
    }
  }

  component VolumeSlider: Item {
    property var   node
    property color accentColor:  "white"
    property color overColor:    Qt.rgba(1, 0.5, 0.2, 1.0)
    property color bgColor:      "#474747"
    property color mutedColor:   "red"
    property real  maxVol:       1.5

    height: 18

    readonly property real vol:     node && node.audio ? node.audio.volume : 0
    readonly property bool muted:   node && node.audio ? node.audio.muted  : false
    readonly property real norm100: Math.min(1.0, vol) / maxVol
    readonly property real over100: Math.max(0, vol - 1.0) / maxVol

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width; height: 4; radius: 2
      color: Qt.rgba(parent.bgColor.r, parent.bgColor.g, parent.bgColor.b, 0.5)
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x:      parent.width * (1.0 / parent.maxVol) - 1
      width:  1; height: 6; color: Qt.rgba(1, 1, 1, 0.2); radius: 1
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      height: 4; radius: 2
      width:  parent.width * parent.norm100
      color:  parent.muted ? parent.mutedColor : parent.accentColor
      Behavior on color { ColorAnimation { duration: 150 } }
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x:      parent.width * (1.0 / parent.maxVol)
      height: 4; radius: 2
      width:  parent.width * parent.over100
      color:  parent.muted ? parent.mutedColor : parent.overColor
      visible: parent.over100 > 0
    }
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x:      Math.min(parent.width - width,
                Math.max(0, (parent.vol / parent.maxVol) * parent.width - width / 2))
      width:  12; height: 12; radius: 6
      color:  parent.muted ? parent.mutedColor
            : parent.vol > 1.0 ? parent.overColor : parent.accentColor
      visible: sliderArea.containsMouse
      scale:   sliderArea.pressed ? 0.85 : 1.0
      Behavior on scale { NumberAnimation { duration: 80 } }
      Behavior on color { ColorAnimation { duration: 150 } }
    }
    MouseArea {
      id: sliderArea
      anchors.fill: parent; hoverEnabled: true
      enabled: parent.node !== null
      onClicked:         (m) => _set(m.x)
      onPositionChanged: (m) => { if (pressed) _set(m.x) }
      function _set(x) {
        var n = parent.node
        if (!n || !n.audio) return
        n.audio.volume = Math.max(0, Math.min(parent.maxVol, x / width * parent.maxVol))
        if (n.audio.volume > 0) n.audio.muted = false
      }
    }
  }

  component DeviceRow: Item {
    property var    node
    property bool   isDefault:   false
    property color  textColor:   "white"
    property color  dimColor:    Qt.rgba(1,1,1,0.5)
    property color  accentColor: "white"
    signal setDefault()

    height: 26; visible: node !== null

    Rectangle {
      anchors.fill: parent; radius: 6
      color: parent.isDefault
        ? Qt.rgba(parent.accentColor.r, parent.accentColor.g, parent.accentColor.b, 0.12)
        : "transparent"
    }
    RowLayout {
      anchors.fill: parent; anchors.leftMargin: 6; anchors.rightMargin: 6; spacing: 6

      Rectangle {
        width: 6; height: 6; radius: 3
        color: parent.parent.isDefault ? parent.parent.accentColor : "transparent"
        border.color: parent.parent.isDefault ? "transparent"
          : Qt.rgba(parent.parent.dimColor.r, parent.parent.dimColor.g, parent.parent.dimColor.b, 0.4)
        border.width: 1
      }
      Text {
        Layout.fillWidth: true
        text:  root.deviceName(parent.parent.node)
        color:          parent.parent.isDefault ? parent.parent.textColor : parent.parent.dimColor
        font.pixelSize: 10; elide: Text.ElideRight
      }
    }
    MouseArea { anchors.fill: parent; onClicked: parent.setDefault() }
  }
}
