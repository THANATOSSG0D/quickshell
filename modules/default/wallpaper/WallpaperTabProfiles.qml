import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// ── WallpaperTabProfiles ──────────────────────────────────────────────────────
// Lista de perfis com thumbnail, info, carregar/deletar.
// Salvar abre input inline (Enter confirma, Esc cancela).

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

  signal refreshState()

  // ── Dados ─────────────────────────────────────────────────────────────────
  property var    entries:          []
  property string _saveInputActive: ""   // "" = oculto, " " = visível

  // ── Processos ─────────────────────────────────────────────────────────────

  Process {
    id: loadProc
    command: ["bash", "-c",
      "python3 " + root.mlScripts +
      "/../quickshell/modules/default/wallpaper/wp-dmenu-entries profiles 2>/dev/null || " +
      "python3 " + root.mlScripts + "/wp-dmenu-entries profiles 2>/dev/null"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: (l) => loadProc._buf += l + "\n" }
    onRunningChanged: {
      if (!running) {
        var raw = loadProc._buf.trim(); loadProc._buf = ""
        if (!raw) return
        try { root.entries = JSON.parse(raw) } catch(e) {}
      }
    }
  }

  Process {
    id: actionProc; property string _buf: ""
    stdout: SplitParser { onRead: (l) => actionProc._buf += l }
    onRunningChanged: {
      if (!running) {
        actionProc._buf = ""
        if (!loadProc.running) loadProc.running = true
        root.refreshState()
      }
    }
  }

  Process {
    id: saveProc; property string _buf: ""
    stdout: SplitParser { onRead: (l) => saveProc._buf += l }
    onRunningChanged: {
      if (!running) {
        saveProc._buf = ""
        root._saveInputActive = ""
        if (!loadProc.running) loadProc.running = true
      }
    }
  }

  function _load(value) {
    var name = value.replace(/^profile:/, "")
    actionProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && " +
      "src=$(python3 -m wp profile apply '" + name + "') && " +
      "exec '" + root.wpRun + "' --quiet \"$src\""
    ]
    if (!actionProc.running) actionProc.running = true
  }

  function _delete(value) {
    var name = value.replace(/^profile:/, "")
    actionProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && python3 -m wp profile delete '" + name + "'"
    ]
    if (!actionProc.running) actionProc.running = true
  }

  function _save(name) {
    if (!name || name.trim() === "") return
    saveProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && python3 -m wp profile save '" + name.trim() + "'"
    ]
    if (!saveProc.running) saveProc.running = true
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

    // ── Botão salvar / input ─────────────────────────────────────────────────
    Item {
      Layout.fillWidth: true; height: 38

      // Botão "Salvar estado atual"
      Rectangle {
        anchors.fill: parent; radius: 8; visible: root._saveInputActive === ""
        color: sma.containsMouse
          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
          : Qt.rgba(1,1,1,0.05)
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.35)
        border.width: 1
        Behavior on color { ColorAnimation { duration: 100 } }

        RowLayout { anchors.centerIn: parent; spacing: 6
          Text { text: "\uf0c7"; font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                 color: root.colorAccent }
          Text { text: "Salvar estado atual como perfil"
                 font.pixelSize: 10; color: root.colorText }
        }
        MouseArea { id: sma; anchors.fill: parent; hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root._saveInputActive = " " }
      }

      // Input de nome
      Rectangle {
        anchors.fill: parent; radius: 8; visible: root._saveInputActive !== ""
        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.08)
        border.color: root.colorAccent; border.width: 1

        RowLayout {
          anchors { fill: parent; leftMargin: 10; rightMargin: 6 }
          spacing: 6

          TextInput {
            id: nameInput
            Layout.fillWidth: true; font.pixelSize: 11
            color: root.colorText; selectedTextColor: "#1f1f1f"
            selectionColor: root.colorAccent
            focus: visible
            onVisibleChanged: if (visible) { text = ""; forceActiveFocus() }
            Keys.onReturnPressed: root._save(text)
            Keys.onEscapePressed: root._saveInputActive = ""

            Text { anchors.fill: parent; verticalAlignment: Text.AlignVCenter
                   text: "nome do perfil..."
                   color: root.colorTextDim; font: parent.font
                   visible: parent.text.length === 0 && !parent.activeFocus }
          }

          // Confirmar
          Item { width: 28; height: 28
            Rectangle { anchors.fill: parent; radius: 6
              color: okma.containsMouse
                ? Qt.rgba(root.colorAccent.r,root.colorAccent.g,root.colorAccent.b,0.3)
                : "transparent"
              Text { anchors.centerIn: parent; text: "\uf00c"
                     font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                     color: root.colorAccent }
            }
            MouseArea { id: okma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root._save(nameInput.text) }
          }

          // Cancelar
          Item { width: 28; height: 28
            Rectangle { anchors.fill: parent; radius: 6
              color: xma.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
              Text { anchors.centerIn: parent; text: "\uf00d"
                     font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                     color: root.colorTextDim }
            }
            MouseArea { id: xma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: root._saveInputActive = "" }
          }
        }
      }
    }

    Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.4 }

    // ── Lista de perfis ──────────────────────────────────────────────────────
    ListView {
      id: lv; Layout.fillWidth: true; Layout.fillHeight: true
      clip: true; spacing: 6
      model: root.entries
      property int delIdx: -1

      delegate: Item {
        width: lv.width; height: 60
        readonly property bool isDel: lv.delIdx === index

        Rectangle {
          anchors.fill: parent; radius: 8
          color: hma.containsMouse ? Qt.rgba(1,1,1,0.06) : Qt.rgba(1,1,1,0.03)
          border.color: isDel ? Qt.rgba(1,0.3,0.3,0.5) : Qt.rgba(1,1,1,0.07)
          border.width: 1
          Behavior on color { ColorAnimation { duration: 100 } }

          RowLayout {
            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
            spacing: 10

            // Thumbnail
            Rectangle { width: 74; height: 42; radius: 6; clip: true
                         color: Qt.rgba(1,1,1,0.04)
              Image { anchors.fill: parent; fillMode: Image.PreserveAspectCrop
                      source: (modelData.thumb && modelData.thumb !== "")
                        ? "file://" + modelData.thumb : ""
                      asynchronous: true; cache: true; smooth: true }
            }

            // Info
            ColumnLayout { Layout.fillWidth: true; spacing: 3
              Text { text: (modelData.label || "").split("  ·  ")[0]
                     font.pixelSize: 11; color: root.colorText
                     elide: Text.ElideRight; Layout.fillWidth: true }
              Text { text: modelData.sub || ""
                     font.pixelSize: 9; color: root.colorTextDim
                     elide: Text.ElideRight; Layout.fillWidth: true }
            }

            // Botões normais
            RowLayout { spacing: 4; visible: !isDel

              Item { width: 30; height: 30
                Rectangle { anchors.fill: parent; radius: 7
                  color: ldma.containsMouse
                    ? Qt.rgba(root.colorAccent.r,root.colorAccent.g,root.colorAccent.b,0.22)
                    : Qt.rgba(1,1,1,0.05)
                  Text { anchors.centerIn: parent; text: "\uf144"
                         font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                         color: root.colorAccent }
                }
                MouseArea { id: ldma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: root._load(modelData.value) }
              }

              Item { width: 30; height: 30
                Rectangle { anchors.fill: parent; radius: 7
                  color: dlma.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : Qt.rgba(1,1,1,0.05)
                  Text { anchors.centerIn: parent; text: "\uf1f8"
                         font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                         color: "#cf6679" }
                }
                MouseArea { id: dlma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: lv.delIdx = index }
              }
            }

            // Confirmação de deleção
            RowLayout { spacing: 6; visible: isDel
              Text { text: "confirmar?"; font.pixelSize: 9; color: "#cf6679" }
              Item { width: 30; height: 30
                Rectangle { anchors.fill: parent; radius: 7
                  color: yma.containsMouse ? Qt.rgba(1,0.3,0.3,0.3) : Qt.rgba(1,0.3,0.3,0.15)
                  Text { anchors.centerIn: parent; text: "\uf00c"
                         font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                         color: "#cf6679" }
                }
                MouseArea { id: yma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: { root._delete(modelData.value); lv.delIdx = -1 } }
              }
              Item { width: 30; height: 30
                Rectangle { anchors.fill: parent; radius: 7
                  color: nma.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
                  Text { anchors.centerIn: parent; text: "\uf00d"
                         font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                         color: root.colorTextDim }
                }
                MouseArea { id: nma; anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: lv.delIdx = -1 }
              }
            }
          }
        }

        MouseArea { id: hma; anchors.fill: parent; hoverEnabled: true; z: -1 }
      }

      Text { anchors.centerIn: parent
             visible: root.entries.length === 0 && !loadProc.running
             text: "Nenhum perfil salvo ainda."
             font.pixelSize: 11; color: root.colorTextDim; opacity: 0.5 }

      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    }
  }
}
