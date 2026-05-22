import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Layouts
import ".." as Bar

// ── BarEditorPopup ────────────────────────────────────────────────────────────
// Herda de Bar.BarPopup (PanelWindow). barRef injetado por Bar.qml.
// Animação gerenciada inteiramente pelo BarPopup (_animProg).

Bar.BarPopup {
  id: popup

  popupW:      440
  popupH:      560
  bgRadius:    14
  animDuration: 220

  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#888888"
  property color colorAccent:     "#ffb4a9"
  property color colorProgressBg: "#333333"
  property color colorDivider:    "#333333"

  property var config: null

  onPanelOpenChanged: {
    if (panelOpen && config && config.configLoaded) _reload()
  }

  // Re-carrega quando o config termina de carregar (caso o painel já estivesse aberto)
  Connections {
    target: popup.config
    ignoreUnknownSignals: true
    function onConfigLoadedChanged() {
      if (popup.panelOpen && popup.config && popup.config.configLoaded) popup._reload()
    }
  }

  // ── Estado local ──────────────────────────────────────────────────────
  property var  slotLeft:   []
  property var  slotCenter: []
  property var  slotRight:  []
  property var  slotTop:    []
  property var  slotMiddle: []
  property var  slotBottom: []

  property bool   localAutoHide:  false
  property bool   localSilence:   false
  property int    localPosition:  4
  property int    localPillWidth:      800
  property int    localPillMinSpacing: 20
  property int    localBarSize:        30
  property int    localBarMargin: 3
  property string localWsStyle:   "icons"
  property string localWsSort:    "position"
  property bool   localWsMono:    true
  property int    localWsSpacing: 4
  property bool   localWsAddBtn:  true
  property string localTheme:     "Pill"

  readonly property bool localIsH: localPosition === 1 || localPosition === 3

  property string _dragId:   ""
  property string _dragSlot: ""
  property int    _dragIdx:  -1

  // ── Helpers ───────────────────────────────────────────────────────────
  function _reload() {
    if (!config) return
    console.log("[BarEditor] _reload() | config.modulesLeft:", JSON.stringify(config.modulesLeft),
                "| config.modulesRight:", JSON.stringify(config.modulesRight),
                "| config.modulesTop:", JSON.stringify(config.modulesTop),
                "| config.modulesBottom:", JSON.stringify(config.modulesBottom))
    slotLeft   = (config.modulesLeft   || []).slice()
    slotCenter = (config.modulesCenter || []).slice()
    slotRight  = (config.modulesRight  || []).slice()
    slotTop    = (config.modulesTop    || []).slice()
    slotMiddle = (config.modulesMiddle || []).slice()
    slotBottom = (config.modulesBottom || []).slice()
    localAutoHide  = config.autoHide  || false
    localSilence   = config.silenceMode || false
    localPosition  = config.position  || 4
    localPillWidth       = config.pillWidth    || 800
    localPillMinSpacing  = config.pillMinSpacing !== undefined ? config.pillMinSpacing : 20
    localBarSize         = config.barSize      || 30
    localBarMargin = config.barMargin || 3
    localWsStyle   = config.wsStyle   || "icons"
    localWsSort    = config.wsIconsSort || "position"
    localWsMono    = config.wsIconMonochrome !== undefined ? config.wsIconMonochrome : true
    localWsSpacing = config.wsIconSpacing || 4
    localWsAddBtn  = config.wsShowAddButton !== undefined ? config.wsShowAddButton : true
    localTheme     = config.theme || "Pill"
  }

  function _save() {
    if (!config) return
    // Preserva os slots da orientação inativa (não editada agora) com o
    // valor do config, evitando sobrescrever com arrays vazios ou desatualizados.
    var saveLeft   = localIsH ? slotLeft   : (config.modulesLeft   || []).slice()
    var saveCenter = localIsH ? slotCenter : (config.modulesCenter || []).slice()
    var saveRight  = localIsH ? slotRight  : (config.modulesRight  || []).slice()
    var saveTop    = localIsH ? (config.modulesTop    || []).slice() : slotTop
    var saveMiddle = localIsH ? (config.modulesMiddle || []).slice() : slotMiddle
    var saveBottom = localIsH ? (config.modulesBottom || []).slice() : slotBottom
    console.log("[BarEditor] _save() | left:", JSON.stringify(saveLeft),
                "| center:", JSON.stringify(saveCenter),
                "| right:", JSON.stringify(saveRight),
                "| top:", JSON.stringify(saveTop),
                "| middle:", JSON.stringify(saveMiddle),
                "| bottom:", JSON.stringify(saveBottom))
    config.saveAll({
      modulesLeft:      saveLeft.slice(),
      modulesCenter:    saveCenter.slice(),
      modulesRight:     saveRight.slice(),
      modulesTop:       saveTop.slice(),
      modulesMiddle:    saveMiddle.slice(),
      modulesBottom:    saveBottom.slice(),
      autoHide:         localAutoHide,
      silence:          localSilence,
      position:         localPosition,
      pillWidth:        localPillWidth,
      pillMinSpacing:   localPillMinSpacing,
      barSize:          localBarSize,
      barMargin:        localBarMargin,
      wsStyle:          localWsStyle,
      wsIconsSort:      localWsSort,
      wsIconMonochrome: localWsMono,
      wsIconSpacing:    localWsSpacing,
      wsShowAddButton:  localWsAddBtn,
      theme:            localTheme
    })
  }

  function _resetToDefaults() {
    slotLeft   = ["mediaplayer"]
    slotCenter = ["workspaces"]
    slotRight  = ["quicksettings", "separator", "clock", "separator", "volume"]
    slotTop    = ["mediaplayer"]
    slotMiddle = ["workspaces"]
    slotBottom = ["quicksettings", "separator", "clock", "separator", "volume"]
    localBarSize         = 30
    localBarMargin       = 3
    localPillWidth       = 800
    localPillMinSpacing  = 20
    _save()
  }

  function slotModel(slot) {
    if (localIsH) {
      if (slot === "left")   return slotLeft
      if (slot === "center") return slotCenter
      if (slot === "right")  return slotRight
    } else {
      if (slot === "top")    return slotTop
      if (slot === "middle") return slotMiddle
      if (slot === "bottom") return slotBottom
    }
    return []
  }

  function setSlot(slot, arr) {
    if (localIsH) {
      if (slot === "left")   slotLeft   = arr
      if (slot === "center") slotCenter = arr
      if (slot === "right")  slotRight  = arr
    } else {
      if (slot === "top")    slotTop    = arr
      if (slot === "middle") slotMiddle = arr
      if (slot === "bottom") slotBottom = arr
    }
    _save()
  }

  function addModule(slot, modId) {
    var a = slotModel(slot).slice(); a.push(modId); setSlot(slot, a)
  }

  function removeModule(slot, idx) {
    var a = slotModel(slot).slice(); a.splice(idx, 1); setSlot(slot, a)
  }

  function dropModule(toSlot) {
    var modId = _dragSlot === "pool" ? _dragId : slotModel(_dragSlot)[_dragIdx]
    if (!modId) return
    if (_dragSlot !== "pool") {
      var src = slotModel(_dragSlot).slice()
      src.splice(_dragIdx, 1)
      setSlot(_dragSlot, src)
    }
    var dst = slotModel(toSlot).slice()
    dst.push(modId)
    setSlot(toSlot, dst)
    _dragId = ""; _dragSlot = ""; _dragIdx = -1
  }

  function modInfo(id) {
    var map = {
      workspaces:    { icon: "\uf0c8", label: "Workspaces" },
      clock:         { icon: "\uf017", label: "Relogio"    },
      volume:        { icon: "\ufa7d", label: "Volume"     },
      mediaplayer:   { icon: "\uf001", label: "Midia"      },
      quicksettings: { icon: "\uf013", label: "Config"     },
      notifications: { icon: "\uf0f3", label: "Notificações" },
      separator:     { icon: "\uf07e", label: "Sep"        },
      spacer:        { icon: "\uf047", label: "Espaco"     },
    }
    return map[id] || { icon: "\uf128", label: id }
  }

  // ── UI ────────────────────────────────────────────────────────────────
  // Conteúdo vai diretamente para o bg do BarPopup (via default alias).
  // Não precisamos de um Rectangle adicional — bg já fornece fundo + radius.

  Flickable {
    anchors.fill:    parent
    anchors.margins: 16
    contentHeight:   mainCol.implicitHeight
    clip:            true
    boundsBehavior:  Flickable.StopAtBounds

    ColumnLayout {
      id: mainCol
      width: parent.width
      spacing: 10

      // Header
      RowLayout {
        Layout.fillWidth: true
        Text {
          text: "\uf085  Barra"
          color: popup.colorText; font.pixelSize: 13; font.weight: Font.Medium
          font.family: "JetBrainsMono Nerd Font"
        }
        Item { Layout.fillWidth: true }
        Rectangle {
          width: resetLbl.implicitWidth + 14; height: 22; radius: 5
          color: _rx.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05)
          border.color: Qt.rgba(1,1,1,0.12); border.width: 1
          Text { id: resetLbl; anchors.centerIn: parent
            text: "\uf0e2  Padrao"; color: popup.colorTextDim; font.pixelSize: 9
            font.family: "JetBrainsMono Nerd Font" }
          MouseArea { id: _rx; anchors.fill: parent; hoverEnabled: true
            onClicked: popup._resetToDefaults() }
        }
        Item { width: 6 }
        Rectangle {
          width: 22; height: 22; radius: 11
          color: _hx.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
          Text { anchors.centerIn: parent; text: "\uf00d"
            color: popup.colorTextDim; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
          MouseArea { id: _hx; anchors.fill: parent; hoverEnabled: true
            onClicked: popup.closeRequested() }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1
        color: Qt.rgba(popup.colorDivider.r, popup.colorDivider.g, popup.colorDivider.b, 0.3) }

      Text { text: "POSICAO"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }
      Row {
        spacing: 5
        Repeater {
          model: [
            { id: 1, label: "Topo",     icon: "\uf077" },
            { id: 3, label: "Baixo",    icon: "\uf078" },
            { id: 4, label: "Esquerda", icon: "\uf053" },
            { id: 2, label: "Direita",  icon: "\uf054" },
          ]
          delegate: Rectangle {
            required property var modelData
            readonly property bool act: popup.localPosition === modelData.id
            width: 76; height: 28; radius: 5
            color:        act ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.2) : Qt.rgba(1,1,1,0.05)
            border.color: act ? popup.colorAccent : Qt.rgba(1,1,1,0.1); border.width: 1
            Row { anchors.centerIn: parent; spacing: 5
              Text { text: modelData.icon; color: act ? popup.colorAccent : popup.colorTextDim
                font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
              Text { text: modelData.label; color: act ? popup.colorAccent : popup.colorTextDim
                font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { anchors.fill: parent
              onClicked: { popup.localPosition = modelData.id; popup._save(); popup.closeRequested() } }
          }
        }
      }

      Text { text: "TEMA"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }
      Row {
        spacing: 5
        Repeater {
          model: ["Pill", "Default", "Minimal"]
          delegate: Rectangle {
            required property string modelData
            readonly property bool act: popup.localTheme === modelData
            width: tl.implicitWidth + 16; height: 26; radius: 5
            color: act ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.2) : Qt.rgba(1,1,1,0.05)
            border.color: act ? popup.colorAccent : Qt.rgba(1,1,1,0.1); border.width: 1
            Text { id: tl; anchors.centerIn: parent; text: modelData; font.pixelSize: 10
              color: parent.act ? popup.colorAccent : popup.colorTextDim }
            MouseArea { anchors.fill: parent
              onClicked: { popup.localTheme = modelData; popup._save() } }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1
        color: Qt.rgba(popup.colorDivider.r, popup.colorDivider.g, popup.colorDivider.b, 0.3) }

      Text { text: "COMPORTAMENTO"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }
      Repeater {
        model: [
          { label: "Auto-ocultar",          prop: "localAutoHide" },
          { label: "Silence (sem OSD/toasts)", prop: "localSilence"   },
          { label: "Botao + workspaces",     prop: "localWsAddBtn" },
          { label: "Icones monocromaticos",  prop: "localWsMono"   },
        ]
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true
          Text { text: modelData.label; color: popup.colorTextDim; font.pixelSize: 10; Layout.fillWidth: true }
          Rectangle {
            width: 34; height: 18; radius: 9
            property bool chk: popup[modelData.prop]
            color: chk ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.8) : Qt.rgba(1,1,1,0.12)
            Behavior on color { ColorAnimation { duration: 120 } }
            Rectangle {
              width: 12; height: 12; radius: 6; color: "white"
              anchors.verticalCenter: parent.verticalCenter
              x: parent.chk ? parent.width - width - 3 : 3
              Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }
            }
            MouseArea { anchors.fill: parent
              onClicked: { popup[modelData.prop] = !popup[modelData.prop]; popup._save() } }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1
        color: Qt.rgba(popup.colorDivider.r, popup.colorDivider.g, popup.colorDivider.b, 0.3) }

      Text { text: "DIMENSOES"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }
      Repeater {
        model: [
          { label: "Largura pill",   prop: "localPillWidth",      from: 400, to: 2000, step: 10, unit: "px", vis: localIsH },
          { label: "Espac. lateral", prop: "localPillMinSpacing",  from: 0,   to: 120,  step: 4,  unit: "px", vis: localIsH },
          { label: "Espessura",      prop: "localBarSize",         from: 20,  to: 60,   step: 2,  unit: "px", vis: true     },
          { label: "Margem",         prop: "localBarMargin",       from: 0,   to: 30,   step: 1,  unit: "px", vis: true     },
          { label: "Espac. icones",  prop: "localWsSpacing",       from: 0,   to: 16,   step: 1,  unit: "px", vis: true     },
        ]
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true; visible: modelData.vis
          Text { text: modelData.label; color: popup.colorTextDim; font.pixelSize: 10 }
          Item { Layout.fillWidth: true }
          Text { text: Math.round(popup[modelData.prop]) + modelData.unit
            color: popup.colorText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
            Layout.preferredWidth: 50; horizontalAlignment: Text.AlignRight }
          Item {
            Layout.preferredWidth: 100; height: 20
            readonly property real _from:  modelData.from
            readonly property real _to:    modelData.to
            readonly property real _step:  modelData.step
            readonly property real _ratio: (popup[modelData.prop] - _from) / Math.max(1, _to - _from)
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              anchors.left: parent.left; anchors.right: parent.right
              height: 4; radius: 2
              color: Qt.rgba(popup.colorProgressBg.r, popup.colorProgressBg.g, popup.colorProgressBg.b, 0.5)
              Rectangle {
                anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                radius: 2; width: parent.parent.parent._ratio * parent.width; color: popup.colorAccent
              }
            }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              x: parent._ratio * (parent.width - width)
              width: 14; height: 14; radius: 7; color: "white"
              Behavior on x { enabled: !_sma.pressed; NumberAnimation { duration: 80 } }
            }
            MouseArea {
              id: _sma; anchors.fill: parent
              function _apply(mx) {
                var ratio = Math.max(0, Math.min(1, mx / parent.width))
                var raw   = parent._from + ratio * (parent._to - parent._from)
                popup[modelData.prop] = Math.round(raw / parent._step) * parent._step
                popup._save()
              }
              onPositionChanged: (mouse) => _apply(mouse.x)
              onClicked:         (mouse) => _apply(mouse.x)
            }
          }
        }
      }

      Text { text: "ESTILO WORKSPACES"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }
      Row {
        spacing: 5
        Repeater {
          model: [{ id: "icons", label: "Icones" }, { id: "dots", label: "Dots" },
                  { id: "hybrid", label: "Hybrid" }, { id: "number", label: "Numero" }]
          delegate: Rectangle {
            required property var modelData
            readonly property bool act: popup.localWsStyle === modelData.id
            width: wsl.implicitWidth + 16; height: 26; radius: 5
            color: act ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.2) : Qt.rgba(1,1,1,0.05)
            border.color: act ? popup.colorAccent : Qt.rgba(1,1,1,0.1); border.width: 1
            Text { id: wsl; anchors.centerIn: parent; text: modelData.label; font.pixelSize: 10
              color: parent.act ? popup.colorAccent : popup.colorTextDim }
            MouseArea { anchors.fill: parent
              onClicked: { popup.localWsStyle = modelData.id; popup._save() } }
          }
        }
      }

      Text { text: "ORDENACAO ICONES"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }
      Row {
        spacing: 5
        Repeater {
          model: [{ id: "position", label: "Posicao" }, { id: "alphabetical", label: "Alfabetica" }]
          delegate: Rectangle {
            required property var modelData
            readonly property bool act: popup.localWsSort === modelData.id
            width: wso.implicitWidth + 16; height: 26; radius: 5
            color: act ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.2) : Qt.rgba(1,1,1,0.05)
            border.color: act ? popup.colorAccent : Qt.rgba(1,1,1,0.1); border.width: 1
            Text { id: wso; anchors.centerIn: parent; text: modelData.label; font.pixelSize: 10
              color: parent.act ? popup.colorAccent : popup.colorTextDim }
            MouseArea { anchors.fill: parent
              onClicked: { popup.localWsSort = modelData.id; popup._save() } }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1
        color: Qt.rgba(popup.colorDivider.r, popup.colorDivider.g, popup.colorDivider.b, 0.3) }

      // ── Modulos ───────────────────────────────────────────────────────
      Text {
        text: popup.localIsH ? "MODULOS (HORIZONTAL)" : "MODULOS (VERTICAL)"
        color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font"
      }

      Repeater {
        model: popup.localIsH
          ? [{ slot: "left", label: "Esquerda" }, { slot: "center", label: "Centro" }, { slot: "right", label: "Direita" }]
          : [{ slot: "top",  label: "Topo"      }, { slot: "middle", label: "Centro" }, { slot: "bottom", label: "Baixo"  }]

        delegate: Item {
          id: slotDelegate
          required property var modelData
          readonly property string slotName: modelData.slot
          Layout.fillWidth: true
          height: slotInner.implicitHeight + 20

          Rectangle {
            anchors.fill: parent; radius: 7
            color: Qt.rgba(1,1,1,0.03)
            border.color: slotDrop.containsDrag
              ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.55)
              : Qt.rgba(1,1,1,0.08)
            border.width: 1

            DropArea {
              id: slotDrop; anchors.fill: parent; keys: ["barmodule"]
              onDropped: (drop) => { popup.dropModule(slotDelegate.slotName); drop.accept() }
            }

            Column {
              id: slotInner
              anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
              spacing: 6

              Text { text: modelData.label; color: popup.colorTextDim
                font.pixelSize: 9; font.family: "JetBrainsMono Nerd Font" }

              Flow {
                width: parent.width; spacing: 4

                Repeater {
                  model: popup.slotModel(slotDelegate.slotName)

                  delegate: Item {
                    id: chipOuter
                    required property string modelData
                    required property int    index
                    readonly property var    info:     popup.modInfo(modelData)
                    readonly property string chipSlot: slotDelegate.slotName
                    height: 26
                    width:  chipStaticRow.implicitWidth + 28

                    Rectangle {
                      anchors.fill: parent; radius: 5
                      color: chipMa.drag.active
                        ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.08)
                        : Qt.rgba(1,1,1,0.08)
                      border.color: chipMa.drag.active ? popup.colorAccent : Qt.rgba(1,1,1,0.14)
                      border.width: 1
                      Behavior on color        { ColorAnimation { duration: 80 } }
                      Behavior on border.color { ColorAnimation { duration: 80 } }

                      Row {
                        id: chipStaticRow
                        anchors.left: parent.left; anchors.leftMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 5
                        Text { text: chipOuter.info.icon; color: popup.colorAccent
                          font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"
                          anchors.verticalCenter: parent.verticalCenter }
                        Text { text: chipOuter.info.label; color: popup.colorText
                          font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        Rectangle {
                          width: 18; height: 18; radius: 9; color: "transparent"
                          anchors.verticalCenter: parent.verticalCenter
                          Text { anchors.centerIn: parent; text: "\uf00d"; font.pixelSize: 8
                            font.family: "JetBrainsMono Nerd Font"
                            color: Qt.rgba(popup.colorTextDim.r, popup.colorTextDim.g, popup.colorTextDim.b, 0.6) }
                          MouseArea {
                            anchors.fill: parent
                            onClicked:  (mouse) => { mouse.accepted = true; popup.removeModule(chipOuter.chipSlot, chipOuter.index) }
                            onPressed:  (mouse) => { mouse.accepted = true }
                            onReleased: (mouse) => { mouse.accepted = true }
                          }
                        }
                      }
                    }

                    Rectangle {
                      id: chipGhost
                      width: chipOuter.width; height: chipOuter.height
                      x: 0; y: 0; z: 100
                      radius: 5
                      visible: chipMa.drag.active
                      color: Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.35)
                      border.color: popup.colorAccent; border.width: 1
                      Drag.active:    chipMa.drag.active
                      Drag.keys:      ["barmodule"]
                      Drag.hotSpot.x: width  / 2
                      Drag.hotSpot.y: height / 2
                      Text { anchors.centerIn: parent
                        text:  chipOuter.info.icon + "  " + chipOuter.info.label
                        color: popup.colorText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                    }

                    MouseArea {
                      id: chipMa
                      anchors.fill: parent
                      z: -1
                      drag.target:    chipGhost
                      drag.threshold: 8
                      onPressed: {
                        chipGhost.x = 0; chipGhost.y = 0
                        popup._dragId   = chipOuter.modelData
                        popup._dragSlot = chipOuter.chipSlot
                        popup._dragIdx  = chipOuter.index
                      }
                      onReleased: {
                        if (drag.active) chipGhost.Drag.drop()
                        chipGhost.x = 0; chipGhost.y = 0
                      }
                    }
                  }
                }

                Text {
                  visible: popup.slotModel(slotDelegate.slotName).length === 0
                  text: "soltar aqui"; font.pixelSize: 9
                  color: Qt.rgba(popup.colorTextDim.r, popup.colorTextDim.g, popup.colorTextDim.b, 0.35)
                  height: 26; verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1
        color: Qt.rgba(popup.colorDivider.r, popup.colorDivider.g, popup.colorDivider.b, 0.3) }

      // ── Pool ──────────────────────────────────────────────────────────
      Text { text: "ADICIONAR MODULO"; color: popup.colorTextDim
        font.pixelSize: 9; font.weight: Font.Medium; font.family: "JetBrainsMono Nerd Font" }

      Flow {
        Layout.fillWidth: true; spacing: 5

        Repeater {
          model: [
            { id: "workspaces",    icon: "\uf0c8", label: "Workspaces" },
            { id: "clock",         icon: "\uf017", label: "Relogio"    },
            { id: "volume",        icon: "\ufa7d", label: "Volume"     },
            { id: "mediaplayer",   icon: "\uf001", label: "Midia"      },
            { id: "quicksettings", icon: "\uf013", label: "Config"     },
            { id: "notifications", icon: "\uf0f3", label: "Notificações" },
            { id: "separator",     icon: "\uf07e", label: "Separador"  },
            { id: "spacer",        icon: "\uf047", label: "Espaco"     },
          ]
          delegate: Item {
            id: poolOuter
            required property var modelData
            height: 28; width: poolStaticRow.implicitWidth + 20

            Rectangle {
              anchors.fill: parent; radius: 5
              color: poolMa.drag.active
                ? Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.12)
                : Qt.rgba(1,1,1,0.06)
              border.color: poolMa.drag.active ? popup.colorAccent : Qt.rgba(1,1,1,0.12)
              border.width: 1
              Behavior on color        { ColorAnimation { duration: 80 } }
              Behavior on border.color { ColorAnimation { duration: 80 } }
              Row {
                id: poolStaticRow; anchors.centerIn: parent; spacing: 5
                Text { text: poolOuter.modelData.icon; color: popup.colorAccent
                  font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                Text { text: poolOuter.modelData.label; color: popup.colorText
                  font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
              }
            }

            Rectangle {
              id: poolGhost
              width: poolOuter.width; height: poolOuter.height
              x: 0; y: 0; z: 100; radius: 5
              visible: poolMa.drag.active
              color: Qt.rgba(popup.colorAccent.r, popup.colorAccent.g, popup.colorAccent.b, 0.35)
              border.color: popup.colorAccent; border.width: 1
              Drag.active:    poolMa.drag.active
              Drag.keys:      ["barmodule"]
              Drag.hotSpot.x: width  / 2
              Drag.hotSpot.y: height / 2
              Text { anchors.centerIn: parent
                text:  poolOuter.modelData.icon + "  " + poolOuter.modelData.label
                color: popup.colorText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
            }

            MouseArea {
              id: poolMa; anchors.fill: parent
              drag.target: poolGhost; drag.threshold: 8
              onPressed: {
                poolGhost.x = 0; poolGhost.y = 0
                popup._dragId   = poolOuter.modelData.id
                popup._dragSlot = "pool"
                popup._dragIdx  = -1
              }
              onReleased: {
                if (drag.active) poolGhost.Drag.drop()
                poolGhost.x = 0; poolGhost.y = 0
              }
              onClicked: popup.addModule(popup.localIsH ? "right" : "bottom", poolOuter.modelData.id)
            }
          }
        }
      }

      Item { height: 8 }
    }
  }
}
