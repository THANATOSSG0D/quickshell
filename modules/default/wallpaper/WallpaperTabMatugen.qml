import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string mlScripts:    ""
  property string wallSh:       ""
  property string wpRun:        ""
  property string effectsDir:   ""
  property string previewDir:   ""

  property string currentEffect:  "off"
  property string currentPalette: "scheme-fidelity"
  property string currentSource:  "base"
  property int    currentIndex:   0

  signal effectSelected(string e)
  signal paletteSelected(string p)
  signal matugenSourceSelected(string s)
  signal indexSelected(int i)
  signal refreshState()

  property var    effectList:         []
  property var    swatchColors:       []
  property bool   loadingSwatches:    false
  property bool   generatingPreviews: false
  property int    previewVersion:     0

  readonly property var allPalettes: [
    "scheme-content",     "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow",     "scheme-tonal-spot"
  ]

  // ── Processos ─────────────────────────────────────────────────────────────

  Process {
    id: effectsListProc
    command: ["bash", "-c", "echo off; ls '" + root.effectsDir + "/' 2>/dev/null | sort"]
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { effectsListProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        var raw = effectsListProc._buf.trim(); effectsListProc._buf = ""
        var list = []
        raw.split("\n").forEach(function(l) { var t = l.trim(); if (t) list.push(t) })
        root.effectList = list
        _generatePreviews()
      }
    }
  }

  Process {
    id: previewGenProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { previewGenProc._buf += l } }
    onRunningChanged: {
      if (!running) {
        previewGenProc._buf = ""
        root.generatingPreviews = false
        root.previewVersion++
      }
    }
  }

  function _generatePreviews() {
    if (previewGenProc.running) return
    root.generatingPreviews = true
    previewGenProc.command = ["bash", "-c",
      "\"" + root.mlScripts + "/wp-effect-previews-refresh\" 2>/dev/null; true"]
    previewGenProc.running = true
  }

  function _previewPath(effectName) {
    return root.previewDir + "/" + effectName + ".png"
  }

  Process {
    id: swatchProc
    command: ["bash", "-c",
      "cd '" + root.mlScripts + "' && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -m wp matugen colors 2>/dev/null"]
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { swatchProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        root.loadingSwatches = false
        var raw = swatchProc._buf.trim(); swatchProc._buf = ""
        var colors = []
        raw.split("\n").forEach(function(l) {
          var c = l.trim()
          if (/^#[0-9a-fA-F]{6}$/.test(c)) colors.push(c)
        })
        root.swatchColors = colors
      }
    }
  }

  Process {
    id: effectSetProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { effectSetProc._buf += l } }
    onRunningChanged: {
      if (!running) {
        effectSetProc._buf = ""; root.refreshState()
        Qt.callLater(function() { _generatePreviews() })
      }
    }
  }

  Process {
    id: paletteSetProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { paletteSetProc._buf += l } }
    onRunningChanged: {
      if (!running) { paletteSetProc._buf = ""; root.refreshState() }
    }
  }

  Process {
    id: sourceSetProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { sourceSetProc._buf += l } }
    onRunningChanged: {
      if (!running) { sourceSetProc._buf = ""; root.refreshState() }
    }
  }

  Process {
    id: matugenApplyProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { matugenApplyProc._buf += l } }
    onRunningChanged: {
      if (!running) { matugenApplyProc._buf = ""; root.refreshState() }
    }
  }

  function _setEffect(e) {
    root.currentEffect = e; root.effectSelected(e)
    effectSetProc.command = ["bash", "-c",
      "echo '" + e + "' > ~/.config/ml4w/settings/wallpaper-effect.sh && exec '" + root.wpRun + "' --quiet"]
    if (!effectSetProc.running) effectSetProc.running = true
  }

  function _setPalette(p) {
    root.currentPalette = p; root.paletteSelected(p)
    paletteSetProc.command = ["bash", "-c",
      "echo '" + p + "' > ~/.config/ml4w/settings/matugen-pallete.sh && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -m wp matugen apply --quiet 2>/dev/null && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -c \"" +
        "import sys; sys.path.insert(0,'" + root.mlScripts + "'); " +
        "from wp import state as S; d=S.read_all(); d['palette']='" + p + "'; S.write(d)" +
      "\" 2>/dev/null || true"]
    if (!paletteSetProc.running) paletteSetProc.running = true
  }

  function _setSource(s) {
    root.currentSource = s; root.matugenSourceSelected(s)
    sourceSetProc.command = ["bash", "-c",
      "echo '" + s + "' > ~/.config/ml4w/cache/matugen-source && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -m wp matugen apply --quiet 2>/dev/null && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -c \"" +
        "import sys; sys.path.insert(0,'" + root.mlScripts + "'); " +
        "from wp import state as S; d=S.read_all(); d['matugen_source']='" + s + "'; S.write(d)" +
      "\" 2>/dev/null || true"]
    if (!sourceSetProc.running) sourceSetProc.running = true
  }

  function _applyIndex(i) {
    root.currentIndex = i; root.indexSelected(i)
    matugenApplyProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && PYTHONPATH='" + root.mlScripts + "' " +
      "python3 -m wp matugen apply --index " + i + " 2>/dev/null && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -c \"" +
        "import sys; sys.path.insert(0,'" + root.mlScripts + "'); " +
        "from wp import state as S; d=S.read_all(); d['matugen_index']=" + i + "; S.write(d)" +
      "\" 2>/dev/null || true"]
    if (!matugenApplyProc.running) matugenApplyProc.running = true
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      if (!effectsListProc.running) effectsListProc.running = true
      if (swatchColors.length === 0 && !loadingSwatches) {
        loadingSwatches = true
        if (!swatchProc.running) swatchProc.running = true
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  Flickable {
    anchors.fill: parent; clip: true
    contentWidth: width
    contentHeight: mainCol.implicitHeight + 32
    boundsMovement: Flickable.StopAtBounds

    Column {
      id: mainCol
      x: 14; y: 16
      width: parent.width - 28
      spacing: 0

      // ── SEÇÃO EFEITO ───────────────────────────────────────────────────────
      Item { width: 1; height: 4 }

      // Cabeçalho
      Item {
        width: parent.width; height: 32

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "EFEITO"
          font.pixelSize: 9; font.letterSpacing: 1.8
          color: root.colorAccent; opacity: 0.75
        }

        Row {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          spacing: 8; visible: root.generatingPreviews
          Text {
            text: "↻"; font.pixelSize: 13
            color: root.colorTextDim; opacity: 0.6
            anchors.verticalCenter: parent.verticalCenter
            RotationAnimator on rotation { from: 0; to: 360; duration: 1000; loops: Animation.Infinite; running: root.generatingPreviews }
          }
          Text {
            text: "gerando..."; font.pixelSize: 9
            color: root.colorTextDim; opacity: 0.45
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Text {
          anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
          visible: !root.generatingPreviews
          text: "↻"; font.pixelSize: 13
          color: root.colorTextDim; opacity: 0.45
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: _generatePreviews() }
        }
      }

      Item { width: 1; height: 8 }

      // Grade de efeitos
      Flow {
        width: parent.width; spacing: 8

        Repeater {
          model: root.effectList
          delegate: Item {
            id: ed
            width: 110; height: 82
            readonly property bool isAct: root.currentEffect === modelData
            readonly property string pvPath: root.previewDir + "/" + modelData + ".png"

            Rectangle {
              anchors.fill: parent; radius: 10; clip: true
              color: isAct
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                : (ema.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.04))
              border.color: isAct ? root.colorAccent : (ema.containsMouse ? Qt.rgba(1,1,1,0.18) : Qt.rgba(1,1,1,0.08))
              border.width: isAct ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 120 } }
              Behavior on border.color { ColorAnimation { duration: 120 } }

              Image {
                id: pvImg
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 60
                fillMode: Image.PreserveAspectCrop
                asynchronous: true; cache: false; smooth: true
                source: root.previewVersion >= 0 ? ("file://" + ed.pvPath) : ""

                Rectangle {
                  anchors.fill: parent
                  visible: pvImg.status !== Image.Ready
                  color: Qt.rgba(1,1,1,0.04)
                  Text {
                    anchors.centerIn: parent; text: "🖼"
                    font.pixelSize: 12
                    color: root.colorTextDim; opacity: 0.25
                  }
                }

                // Badge ativo
                Rectangle {
                  visible: isAct
                  anchors { top: parent.top; right: parent.right; margins: 4 }
                  width: 18; height: 18; radius: 9; color: root.colorAccent
                  Text { anchors.centerIn: parent; text: "✓"; font.pixelSize: 10; color: "#1a1a1a" }
                }
              }

              Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left; anchors.right: parent.right
                height: 22
                color: isAct ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25) : Qt.rgba(0,0,0,0.5)
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                  anchors.centerIn: parent
                  text: modelData === "off" ? "desligado" : modelData
                  font.pixelSize: 9; elide: Text.ElideRight
                  color: isAct ? root.colorAccent : root.colorText
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
              }
            }

            MouseArea {
              id: ema; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root._setEffect(modelData)
            }
          }
        }
      }

      Item { width: 1; height: 20 }
      Rectangle { width: parent.width; height: 1; color: root.colorDivider; opacity: 0.3 }
      Item { width: 1; height: 20 }

      // ── SEÇÃO PALETTE ──────────────────────────────────────────────────────
      Text {
        text: "PALETTE"
        font.pixelSize: 9; font.letterSpacing: 1.8
        color: root.colorAccent; opacity: 0.75
      }

      Item { width: 1; height: 10 }

      Flow {
        width: parent.width; spacing: 6

        Repeater {
          model: root.allPalettes
          delegate: Item {
            width: pc.implicitWidth; height: 30
            readonly property bool isAct: root.currentPalette === modelData

            Rectangle {
              id: pc; anchors.fill: parent; radius: 15
              implicitWidth: pt.implicitWidth + 26
              color: isAct
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                : (pcMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05))
              border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.1)
              border.width: isAct ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                id: pt; anchors.centerIn: parent
                text: modelData.replace("scheme-", ""); font.pixelSize: 10
                color: isAct ? root.colorAccent : root.colorText
                Behavior on color { ColorAnimation { duration: 100 } }
              }
            }
            MouseArea {
              id: pcMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root._setPalette(modelData)
            }
          }
        }
      }

      Item { width: 1; height: 20 }
      Rectangle { width: parent.width; height: 1; color: root.colorDivider; opacity: 0.3 }
      Item { width: 1; height: 20 }

      // ── SEÇÃO FONTE MATUGEN ────────────────────────────────────────────────
      Row {
        width: parent.width; spacing: 12

        Text {
          text: "FONTE MATUGEN"
          font.pixelSize: 9; font.letterSpacing: 1.8
          color: root.colorAccent; opacity: 0.75
          anchors.verticalCenter: parent.verticalCenter
        }

        Repeater {
          model: [{ id: "base", label: "base" }, { id: "final", label: "final" }]
          delegate: Item {
            width: sc.implicitWidth; height: 30
            readonly property bool isAct: root.currentSource === modelData.id
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              id: sc; anchors.fill: parent; radius: 15
              implicitWidth: sl.implicitWidth + 26
              color: isAct
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                : (scMA.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.05))
              border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.1)
              border.width: isAct ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                id: sl; anchors.centerIn: parent
                text: modelData.label; font.pixelSize: 10
                color: isAct ? root.colorAccent : root.colorText
                Behavior on color { ColorAnimation { duration: 100 } }
              }
            }
            MouseArea {
              id: scMA; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root._setSource(modelData.id)
            }
          }
        }
      }

      Item { width: 1; height: 20 }
      Rectangle { width: parent.width; height: 1; color: root.colorDivider; opacity: 0.3 }
      Item { width: 1; height: 20 }

      // ── SEÇÃO COR DA FONTE ─────────────────────────────────────────────────
      Row {
        width: parent.width
        spacing: 10

        Text {
          text: "COR DA FONTE"
          font.pixelSize: 9; font.letterSpacing: 1.8
          color: root.colorAccent; opacity: 0.75
          anchors.verticalCenter: parent.verticalCenter
        }

        Item {
          width: 24; height: 24
          anchors.verticalCenter: parent.verticalCenter
          Text {
            anchors.centerIn: parent; text: "↻"; font.pixelSize: 15
            color: root.loadingSwatches
              ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
              : root.colorTextDim
            opacity: 0.65
            RotationAnimator on rotation { from: 0; to: 360; duration: 900; loops: Animation.Infinite; running: root.loadingSwatches }
          }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (!swatchProc.running) {
                root.swatchColors = []; root.loadingSwatches = true
                swatchProc.running = true
              }
            }
          }
        }
      }

      Item { width: 1; height: 10 }

      Text {
        visible: root.loadingSwatches
        text: "gerando paleta..."
        font.pixelSize: 10; color: root.colorTextDim; opacity: 0.5
      }

      Text {
        visible: !root.loadingSwatches && root.swatchColors.length === 0
        text: "Abra a aba e aguarde a paleta carregar."
        font.pixelSize: 10; color: root.colorTextDim; opacity: 0.45
      }

      Flow {
        width: parent.width; spacing: 6
        visible: !root.loadingSwatches && root.swatchColors.length > 0

        Repeater {
          model: root.swatchColors
          delegate: Item {
            width: 36; height: 36
            readonly property bool isAct: root.currentIndex === index

            Rectangle {
              anchors.fill: parent; radius: 8; color: modelData
              border.color: isAct ? "white" : Qt.rgba(0,0,0,0.3)
              border.width: isAct ? 2.5 : 1

              Text {
                anchors { bottom: parent.bottom; right: parent.right; margins: 3 }
                text: index; font.pixelSize: 7; color: "white"
                style: Text.Outline; styleColor: "#80000000"
              }
              Text {
                anchors.centerIn: parent; visible: isAct; text: "✓"
                font.pixelSize: 15; color: "white"
                style: Text.Outline; styleColor: "#80000000"
              }
              scale: swma.containsMouse ? 1.1 : 1.0
              Behavior on scale { NumberAnimation { duration: 90 } }
            }

            MouseArea {
              id: swma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root._applyIndex(index)
            }
          }
        }
      }

      Item { width: 1; height: 16 }
    }
  }
}
