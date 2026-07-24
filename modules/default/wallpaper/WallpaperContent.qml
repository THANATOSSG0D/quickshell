import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

Item {
  id: root

  property color  colorBg:      "#1e1e2e"
  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string activeTab:    "wallpaper"
  property bool   showTabBar:   true

  signal closeRequested()

  property string mlScripts: "/home/antonio/.config/ml4w/scripts"
  property string wallSh:    mlScripts + "/wallpaper.sh"
  property string wpRun:     mlScripts + "/wp-run"
  readonly property string effectsDir: "/home/antonio/.config/hypr/effects/wallpaper"
  readonly property string previewDir: "/home/antonio/.config/ml4w/cache/effect-previews"

  property string currentEffect:    "off"
  property string currentPalette:   "scheme-fidelity"
  property string currentSource:    "base"
  property int    currentIndex:     0
  property string currentWallpaper: ""
  property string currentEngine:    "swww"

  readonly property var tabs: [
    { id: "wallpaper", icon: "\uf03e", label: "Wallpaper" },
    { id: "matugen",   icon: "\uf53f", label: "Matugen"   },
    { id: "profiles",  icon: "\uf097", label: "Perfis"    },
    { id: "history",   icon: "\uf1da", label: "Histórico" },
    { id: "schedule",  icon: "\uf017", label: "Schedule"  }
  ]

  // ── Slots para o menu de contexto ─────────────────────────────────────────
  // Carregados independentemente de a aba Schedule ter sido visitada.
  property var    _menuSlots: []
  property string _pendingWallpaperPath: ""

  // Processo que lê o JSON de schedule diretamente
  Process {
    id: slotsLoadProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { slotsLoadProc._buf += l + "\n" } }
    onRunningChanged: {
      if (running) return
      var raw = slotsLoadProc._buf.trim(); slotsLoadProc._buf = ""
      if (!raw) return
      try {
        var d = JSON.parse(raw)
        root._menuSlots = d.slots || []
        // Sincroniza com schedTab se já estiver instanciado
        if (schedTab.slots.length === 0 && root._menuSlots.length > 0)
          schedTab.slots = root._menuSlots
      } catch(e) {}
    }
  }

  function _loadMenuSlots() {
    if (slotsLoadProc.running) return
    slotsLoadProc.command = ["bash", "-c",
      "cat ~/.config/ml4w/settings/wallpaper-schedule.json 2>/dev/null || echo '{}'"
    ]
    slotsLoadProc.running = true
  }

  // ── Menu de contexto (clique direito na grade de wallpapers) ──────────────
  Menu {
    id: slotContextMenu

    // Cabeçalho — nome do arquivo
    MenuItem {
      enabled: false
      contentItem: Text {
        text: "📁  " + (root._pendingWallpaperPath !== ""
          ? root._pendingWallpaperPath.split("/").pop() : "wallpaper")
        font.pixelSize: 9
        color: root.colorAccent
        leftPadding: 8
        verticalAlignment: Text.AlignVCenter
      }
    }

    MenuSeparator {}

    // Slots — usa _menuSlots (sempre carregado) em vez de schedTab.slots
    Repeater {
      model: root._menuSlots
      delegate: MenuItem {
        contentItem: Text {
          text: {
            var s = modelData
            var h = (s.start !== undefined ? s.start.toString().padStart(2,"0") : "??") + "h"
            return "⏰  " + h + "  " + (s.name || "(sem nome)")
          }
          font.pixelSize: 10
          color: root.colorText
          leftPadding: 8
          verticalAlignment: Text.AlignVCenter
        }
        onTriggered: {
          // Atribui via schedTab se disponível, senão via processo direto
          if (schedTab.visible || true) {
            schedTab.assignWallpaperToSlot(index, root._pendingWallpaperPath)
          }
        }
      }
    }

    MenuItem {
      visible: root._menuSlots.length === 0
      enabled: false
      contentItem: Text {
        text: "(nenhum slot cadastrado)"
        font.pixelSize: 9
        color: root.colorTextDim
        opacity: 0.7
        leftPadding: 8
        verticalAlignment: Text.AlignVCenter
      }
    }

    MenuSeparator {}

    MenuItem {
      contentItem: Text {
        text: "＋  Criar novo slot…"
        font.pixelSize: 10
        color: root.colorAccent
        leftPadding: 8
        verticalAlignment: Text.AlignVCenter
      }
      onTriggered: {
        newSlotPopup.newSlotName = ""
        newSlotPopup.newSlotHour = 0
        newSlotPopup.open()
      }
    }
  }

  // ── Popup: criar slot e atribuir wallpaper ────────────────────────────────
  Popup {
    id: newSlotPopup

    property string newSlotName: ""
    property int    newSlotHour: 0

    anchors.centerIn: parent
    width: 280
    height: nsCol.implicitHeight + 32
    modal: true
    focus: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: Rectangle {
      radius: 12
      color: Qt.rgba(0.13, 0.13, 0.18, 0.97)
      border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.4)
      border.width: 1
    }

    ColumnLayout {
      id: nsCol
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.leftMargin: 16
      anchors.rightMargin: 16
      anchors.topMargin: 16
      spacing: 12

      // Título
      RowLayout {
        Layout.fillWidth: true
        spacing: 8
        Text { text: "⏰"; font.pixelSize: 14; color: root.colorAccent }
        Text {
          Layout.fillWidth: true
          text: "Novo slot de schedule"
          font.pixelSize: 11
          color: root.colorText
        }
      }

      // Preview do wallpaper
      Rectangle {
        Layout.fillWidth: true
        height: 36; radius: 8
        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.07)
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
        border.width: 1
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10; anchors.rightMargin: 10
          spacing: 6
          Text { text: "🖼"; font.pixelSize: 10; color: root.colorAccent }
          Text {
            Layout.fillWidth: true
            text: root._pendingWallpaperPath.split("/").pop()
            font.pixelSize: 9; color: root.colorTextDim; elide: Text.ElideLeft
          }
        }
      }

      // Campo nome
      Rectangle {
        Layout.fillWidth: true
        height: 32; radius: 7
        color: Qt.rgba(1,1,1,0.05)
        border.color: nsNameIn.activeFocus ? root.colorAccent : Qt.rgba(1,1,1,0.12)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 120 } }
        TextInput {
          id: nsNameIn
          anchors.fill: parent
          anchors.leftMargin: 10; anchors.rightMargin: 10
          verticalAlignment: TextInput.AlignVCenter
          font.pixelSize: 11; color: root.colorText
          text: newSlotPopup.newSlotName
          onTextChanged: newSlotPopup.newSlotName = text
          Text {
            anchors.fill: parent; verticalAlignment: Text.AlignVCenter
            text: "Nome do slot"; font: parent.font
            color: root.colorTextDim; opacity: 0.45
            visible: parent.text.length === 0 && !parent.activeFocus
          }
        }
      }

      // Seletor de hora
      RowLayout {
        Layout.fillWidth: true; spacing: 8
        Text { text: "Hora:"; font.pixelSize: 10; color: root.colorTextDim }
        Rectangle {
          width: 80; height: 32; radius: 7
          color: Qt.rgba(1,1,1,0.05)
          border.color: Qt.rgba(1,1,1,0.12); border.width: 1
          RowLayout {
            anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 0
            Text {
              Layout.fillWidth: true
              text: newSlotPopup.newSlotHour.toString().padStart(2,"0") + ":00"
              font.pixelSize: 12; color: root.colorText; horizontalAlignment: Text.AlignHCenter
            }
            ColumnLayout {
              spacing: 1
              Text {
                text: "▲"; font.pixelSize: 8; color: root.colorTextDim
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: newSlotPopup.newSlotHour = (newSlotPopup.newSlotHour + 1) % 24
                }
              }
              Text {
                text: "▼"; font.pixelSize: 8; color: root.colorTextDim
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: newSlotPopup.newSlotHour = (newSlotPopup.newSlotHour + 23) % 24
                }
              }
            }
          }
        }
        Item { Layout.fillWidth: true }
      }

      // Botões
      RowLayout {
        Layout.fillWidth: true; spacing: 8
        Item { Layout.fillWidth: true }
        Rectangle {
          width: 72; height: 30; radius: 8
          color: nsCancelHov.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
          border.color: Qt.rgba(1,1,1,0.1); border.width: 1
          Behavior on color { ColorAnimation { duration: 100 } }
          Text { anchors.centerIn: parent; text: "Cancelar"; font.pixelSize: 10; color: root.colorTextDim }
          MouseArea {
            id: nsCancelHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: newSlotPopup.close()
          }
        }
        Rectangle {
          width: 108; height: 30; radius: 8
          opacity: newSlotPopup.newSlotName.trim() === "" ? 0.4 : 1.0
          Behavior on opacity { NumberAnimation { duration: 120 } }
          color: nsConfirmHov.containsMouse
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.38)
            : Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.22)
          border.color: root.colorAccent; border.width: 1
          Behavior on color { ColorAnimation { duration: 100 } }
          Text { anchors.centerIn: parent; text: "Criar e atribuir"; font.pixelSize: 10; color: root.colorAccent }
          MouseArea {
            id: nsConfirmHov; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: {
              var name = newSlotPopup.newSlotName.trim()
              if (name === "") return
              schedTab._addSlotWithWallpaper(name, newSlotPopup.newSlotHour, root._pendingWallpaperPath)
              newSlotPopup.close()
              // Recarrega a lista do menu após criar
              Qt.callLater(function() { root._loadMenuSlots() })
            }
          }
        }
      }
    }
  }

  // ── Layout principal ──────────────────────────────────────────────────────
  ColumnLayout {
    anchors.fill: parent; spacing: 0

    // Barra de abas
    Item {
      Layout.fillWidth: true; height: root.showTabBar ? 50 : 0
      visible: root.showTabBar

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16; anchors.rightMargin: 12
        spacing: 0

        Text {
          text: "Wallpaper"
          font.pixelSize: 13
          color: root.colorAccent; opacity: 0.9
        }

        Item { Layout.fillWidth: true }

        Repeater {
          model: root.tabs
          delegate: Item {
            width: tabRow.implicitWidth + 24; height: 34
            readonly property bool isActive: root.activeTab === modelData.id

            Rectangle {
              anchors.fill: parent; radius: 8
              color: isActive
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
                : (tma.containsMouse ? Qt.rgba(1,1,1,0.06) : "transparent")
              Behavior on color { ColorAnimation { duration: 120 } }
              scale: tma.pressed ? 0.96 : 1.0
              Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            }

            RowLayout {
              id: tabRow; anchors.centerIn: parent; spacing: 5
              Text {
                text: modelData.icon
                font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
                color: isActive ? root.colorAccent : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
              }
              Text {
                text: modelData.label; font.pixelSize: 11
                color: isActive ? root.colorText : root.colorTextDim
                Behavior on color { ColorAnimation { duration: 120 } }
              }
            }

            Rectangle {
              anchors.bottom: parent.bottom
              anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 4
              height: 2; radius: 1; color: root.colorAccent
              opacity: isActive ? 1.0 : 0.0
              Behavior on opacity { NumberAnimation { duration: 140 } }
            }

            MouseArea {
              id: tma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: root.activeTab = modelData.id
            }
          }
        }

        // Botão fechar
        Item {
          width: 34; height: 34
          Rectangle {
            anchors.fill: parent; radius: width / 2
            color: cma.containsMouse ? Qt.rgba(1,0.3,0.3,0.15) : "transparent"
            Behavior on color { ColorAnimation { duration: 100 } }
            scale: cma.pressed ? 0.9 : 1.0
            Behavior on scale { NumberAnimation { duration: 90; easing.type: Easing.OutQuad } }
            Text {
              anchors.centerIn: parent; text: "\uf00d"
              font.family: "JetBrainsMono Nerd Font"; font.pixelSize: 12
              color: Qt.rgba(root.colorTextDim.r, root.colorTextDim.g,
                             root.colorTextDim.b, cma.containsMouse ? 1.0 : 0.5)
            }
          }
          MouseArea {
            id: cma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
            onClicked: root.closeRequested()
          }
        }
      }

      Rectangle {
        anchors.bottom: parent.bottom; width: parent.width; height: 1
        color: root.colorDivider; opacity: 0.5
      }
    }

    // Conteúdo das abas
    Item {
      Layout.fillWidth: true; Layout.fillHeight: true

      WallpaperTabWallpapers {
        id: wallTab
        anchors.fill: parent
        visible:          root.activeTab === "wallpaper"
        panelOpen:        root.panelOpen && root.activeTab === "wallpaper"
        colorText:        root.colorText
        colorTextDim:     root.colorTextDim
        colorAccent:      root.colorAccent
        colorDivider:     root.colorDivider
        mlScripts:        root.mlScripts
        wallSh:           root.wallSh
        wpRun:            root.wpRun
        effectsDir:       root.effectsDir
        currentWallpaper: root.currentWallpaper
        currentEngine:    root.currentEngine
        currentEffect:    root.currentEffect
        currentPalette:   root.currentPalette
        currentSource:    root.currentSource
        currentIndex:     root.currentIndex
        onWallpaperApplied:      function(src) { root.currentWallpaper = src }
        onEngineSelected:        function(e)   { root.currentEngine = e }
        onRefreshState:          function()    { _refreshState() }
        onWallpaperRightClicked: function(path, mx, my) {
          root._pendingWallpaperPath = path
          // Garante que os slots estejam carregados antes de abrir o menu
          if (root._menuSlots.length === 0) root._loadMenuSlots()
          slotContextMenu.popup(mx, my)
        }
      }

      WallpaperTabMatugen {
        anchors.fill: parent
        visible:          root.activeTab === "matugen"
        panelOpen:        root.panelOpen && root.activeTab === "matugen"
        colorText:        root.colorText
        colorTextDim:     root.colorTextDim
        colorAccent:      root.colorAccent
        colorDivider:     root.colorDivider
        mlScripts:        root.mlScripts
        wallSh:           root.wallSh
        wpRun:            root.wpRun
        effectsDir:       root.effectsDir
        previewDir:       root.previewDir
        currentEffect:    root.currentEffect
        currentPalette:   root.currentPalette
        currentSource:    root.currentSource
        currentIndex:     root.currentIndex
        onEffectSelected:        function(e) { root.currentEffect  = e }
        onPaletteSelected:       function(p) { root.currentPalette = p }
        onMatugenSourceSelected: function(s) { root.currentSource  = s }
        onIndexSelected:         function(i) { root.currentIndex   = i }
        onRefreshState:          function()  { _refreshState() }
      }

      WallpaperTabProfiles {
        anchors.fill: parent
        visible:      root.activeTab === "profiles"
        panelOpen:    root.panelOpen && root.activeTab === "profiles"
        colorText:    root.colorText
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider
        mlScripts:    root.mlScripts
        wallSh:       root.wallSh
        wpRun:        root.wpRun
        onRefreshState: function() { _refreshState() }
      }

      WallpaperTabHistory {
        anchors.fill: parent
        visible:      root.activeTab === "history"
        panelOpen:    root.panelOpen && root.activeTab === "history"
        colorText:    root.colorText
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider
        mlScripts:    root.mlScripts
        wpRun:        root.wpRun
        onRefreshState: function() { _refreshState() }
      }

      WallpaperTabSchedule {
        id: schedTab
        anchors.fill: parent
        visible:      root.activeTab === "schedule"
        panelOpen:    root.panelOpen && root.activeTab === "schedule"
        colorText:    root.colorText
        colorTextDim: root.colorTextDim
        colorAccent:  root.colorAccent
        colorDivider: root.colorDivider
        mlScripts:    root.mlScripts
        wallSh:       root.wallSh
        effectsDir:   root.effectsDir
        previewDir:   root.previewDir
        wpRun:        root.wpRun
        // Sincroniza slots com o menu de contexto quando atualizados
        onSlotsChanged: root._menuSlots = schedTab.slots
      }
    }
  }

  // ── Estado global ─────────────────────────────────────────────────────────
  function _refreshState() {
    if (!stateProc.running) stateProc.running = true
  }

  Process {
    id: stateProc
    command: ["bash", "-c",
      "python3 - << 'PYEOF'\n" +
      "import sys, os\n" +
      "sys.path.insert(0, '" + root.mlScripts + "')\n" +
      "from wp import state as S\n" +
      "d = S.read_all()\n" +
      "eng_file = os.path.expanduser('~/.config/ml4w/settings/wallpaper-engine.sh')\n" +
      "eng = open(eng_file).read().strip() if os.path.isfile(eng_file) else 'swww'\n" +
      "print(d.get('effect','off'))\n" +
      "print(d.get('palette','scheme-fidelity'))\n" +
      "print(d.get('matugen_source','base'))\n" +
      "print(d.get('matugen_index',0))\n" +
      "print(d.get('source',''))\n" +
      "print(eng)\n" +
      "PYEOF\n"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { stateProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        var lines = stateProc._buf.trim().split("\n")
        stateProc._buf = ""
        if (lines.length >= 6) {
          root.currentEffect    = lines[0].trim() || "off"
          root.currentPalette   = lines[1].trim() || "scheme-fidelity"
          root.currentSource    = lines[2].trim() || "base"
          root.currentIndex     = parseInt(lines[3].trim()) || 0
          root.currentWallpaper = lines[4].trim()
          root.currentEngine    = lines[5].trim() || "swww"
        }
      }
    }
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      _refreshState()
      _loadMenuSlots()
    }
  }
}
