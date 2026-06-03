import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ── WallpaperTabHistory ───────────────────────────────────────────────────────
// Lista do histórico de wallpapers com thumbnail, info e restaurar/limpar.

Item {
  id: root

  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string mlScripts:    ""
  property string wpRun:        ""

  signal refreshState()

  // ── Dados ──────────────────────────────────────────────────────────────────
  property var entries:    []
  property bool clearing:  false

  // ── Processos ──────────────────────────────────────────────────────────────

  Process {
    id: loadProc
    command: ["bash", "-c",
      "python3 '" + root.mlScripts + "/wp-dmenu-entries' history 2>/dev/null"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => loadProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        var raw = loadProc._buf.trim(); loadProc._buf = ""
        if (!raw) { root.entries = []; return }
        try { root.entries = JSON.parse(raw) } catch(e) { root.entries = [] }
      }
    }
  }

  // Restaurar wallpaper do histórico
  Process {
    id: applyProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => applyProc._buf += l }
    onRunningChanged: {
      if (!running) {
        applyProc._buf = ""
        root.refreshState()
        stateTimer.restart()
      }
    }
  }

  // Limpar histórico
  Process {
    id: clearProc
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => clearProc._buf += l }
    onRunningChanged: {
      if (!running) {
        clearProc._buf = ""
        root.clearing = false
        if (!loadProc.running) loadProc.running = true
      }
    }
  }

  Timer {
    id: stateTimer; interval: 3000; repeat: false
    onTriggered: root.refreshState()
  }

  function _apply(value) {
    if (applyProc.running) return
    // value = "history:N" — extrai índice e chama wp history apply
    var idx = value.replace(/^history:/, "")
    applyProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && " +
      "src=$(python3 -m wp history apply '" + idx + "' 2>/dev/null) && " +
      "[ -n \"$src\" ] && exec '" + root.wpRun + "' --quiet \"$src\""
    ]
    applyProc.running = true
  }

  function _clearHistory() {
    if (clearProc.running) return
    root.clearing = true
    clearProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && python3 -m wp history clear 2>/dev/null"
    ]
    clearProc.running = true
  }

  onPanelOpenChanged: {
    if (panelOpen && !loadProc.running) loadProc.running = true
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  ColumnLayout {
    anchors { fill: parent; margins: 12 }
    spacing: 8

    // ── Toolbar ──────────────────────────────────────────────────────────────
    RowLayout {
      Layout.fillWidth: true; spacing: 8

      Text {
        text: root.entries.length + " entradas"
        font.pixelSize: 10; color: root.colorTextDim; opacity: 0.7
        Layout.fillWidth: true
      }

      // Recarregar
      Item {
        width: 28; height: 28
        Rectangle {
          anchors.fill: parent; radius: 7
          color: rma.containsMouse ? Qt.rgba(1,1,1,0.09) : "transparent"
          Text {
            anchors.centerIn: parent; text: "\uf021"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            color: loadProc.running ? root.colorTextDim : root.colorAccent
            opacity: loadProc.running ? 0.4 : 0.8
            RotationAnimator on rotation {
              from: 0; to: 360; duration: 900
              loops: Animation.Infinite; running: loadProc.running
            }
          }
        }
        MouseArea {
          id: rma; anchors.fill: parent; hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: { if (!loadProc.running) loadProc.running = true }
        }
      }

      // Limpar histórico
      Item {
        width: 28; height: 28
        Rectangle {
          anchors.fill: parent; radius: 7
          color: clma.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : "transparent"
          Text {
            anchors.centerIn: parent; text: "\uf1f8"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            color: "#cf6679"
            opacity: root.clearing ? 0.4 : (root.entries.length === 0 ? 0.3 : 0.8)
          }
        }
        MouseArea {
          id: clma; anchors.fill: parent; hoverEnabled: true
          cursorShape: root.entries.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: { if (root.entries.length > 0) confirmClear.visible = true }
        }
      }
    }

    // Confirmação de limpeza
    Rectangle {
      id: confirmClear
      Layout.fillWidth: true; height: 36; radius: 8; visible: false
      color: Qt.rgba(0.8,0.2,0.2,0.12)
      border.color: Qt.rgba(0.8,0.2,0.2,0.4); border.width: 1

      RowLayout {
        anchors { fill: parent; leftMargin: 10; rightMargin: 8 }
        spacing: 8
        Text {
          text: "\uf071  Limpar todo o histórico?"
          font.pixelSize: 10; color: "#cf6679"
          Layout.fillWidth: true
        }
        Item { width: 56; height: 26
          RowLayout { anchors.fill: parent; spacing: 4
            Rectangle {
              width: 26; height: 26; radius: 6
              color: yesma.containsMouse ? Qt.rgba(0.8,0.2,0.2,0.4) : Qt.rgba(0.8,0.2,0.2,0.2)
              Text { anchors.centerIn: parent; text: "\uf00c"
                     font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                     color: "#cf6679" }
              MouseArea { id: yesma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: { confirmClear.visible = false; root._clearHistory() } }
            }
            Rectangle {
              width: 26; height: 26; radius: 6
              color: noma.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
              Text { anchors.centerIn: parent; text: "\uf00d"
                     font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
                     color: root.colorTextDim }
              MouseArea { id: noma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: confirmClear.visible = false }
            }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.35 }

    // ── Lista ─────────────────────────────────────────────────────────────────
    ListView {
      id: lv; Layout.fillWidth: true; Layout.fillHeight: true
      clip: true; spacing: 5
      model: root.entries

      delegate: Item {
        width: lv.width; height: 58
        readonly property string entryValue: modelData.value || ""
        readonly property string thumb:      modelData.thumb || ""
        readonly property string label:      modelData.label || ""
        readonly property string sub:        modelData.sub   || ""

        Rectangle {
          anchors.fill: parent; radius: 8
          color: hma.containsMouse ? Qt.rgba(1,1,1,0.07) : Qt.rgba(1,1,1,0.03)
          border.color: Qt.rgba(1,1,1,0.07); border.width: 1
          Behavior on color { ColorAnimation { duration: 100 } }

          RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 10

            // Thumbnail
            Rectangle {
              width: 72; height: 41; radius: 6; clip: true
              color: Qt.rgba(1,1,1,0.04)
              Image {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: thumb !== "" ? "file://" + thumb : ""
                asynchronous: true; cache: true; smooth: true
              }
              // Placeholder quando sem thumb
              Text {
                anchors.centerIn: parent
                visible: thumb === ""
                text: "\uf03e"
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                color: root.colorTextDim; opacity: 0.25
              }
            }

            // Info
            ColumnLayout {
              Layout.fillWidth: true; spacing: 3
              Text {
                text: label; font.pixelSize: 10; color: root.colorText
                elide: Text.ElideRight; Layout.fillWidth: true
              }
              Text {
                text: sub; font.pixelSize: 9; color: root.colorTextDim
                elide: Text.ElideRight; Layout.fillWidth: true
              }
            }

            // Botão restaurar
            Item {
              width: 30; height: 30
              Rectangle {
                anchors.fill: parent; radius: 7
                color: ldma.containsMouse
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
                  : Qt.rgba(1,1,1,0.05)
                Text {
                  anchors.centerIn: parent; text: "\uf01e"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                  color: root.colorAccent
                }
              }
              MouseArea {
                id: ldma; anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: root._apply(entryValue)
              }
            }
          }
        }

        MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; z: -1 }
      }

      // Estado vazio
      Column {
        anchors.centerIn: parent
        spacing: 8
        visible: root.entries.length === 0 && !loadProc.running

        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "\uf1da"
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 28 }
          color: root.colorTextDim; opacity: 0.2
        }
        Text {
          anchors.horizontalCenter: parent.horizontalCenter
          text: "Nenhum histórico ainda."
          font.pixelSize: 11; color: root.colorTextDim; opacity: 0.4
        }
      }

      // Loading spinner
      Text {
        anchors.centerIn: parent
        visible: loadProc.running
        text: "\uf110"
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 20 }
        color: root.colorTextDim; opacity: 0.4
        RotationAnimator on rotation {
          from: 0; to: 360; duration: 900
          loops: Animation.Infinite; running: loadProc.running
        }
      }

      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
  }
}
