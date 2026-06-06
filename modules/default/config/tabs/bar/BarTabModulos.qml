import QtQuick
import QtQuick.Layouts
import '../../components' as C

// BarTabModulos — drag-and-drop dos módulos nos slots da barra.
C.CfgScroll {
  id: root

  required property bool   isH
  required property var    slotLeft
  required property var    slotCenter
  required property var    slotRight
  required property var    slotTop
  required property var    slotMiddle
  required property var    slotBottom
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorDivider

  // drag state (propagado do ConfigWindow)
  property string dragId:   ""
  property string dragSlot: ""
  property int    dragIdx:  -1

  signal slotChanged(string slot, var arr)
  signal moduleAdded(string slot, string modId)

  readonly property var hSlots: [
    { slot: "left",   label: "ESQUERDA" },
    { slot: "center", label: "CENTRO"   },
    { slot: "right",  label: "DIREITA"  },
  ]
  readonly property var vSlots: [
    { slot: "top",    label: "TOPO"   },
    { slot: "middle", label: "CENTRO" },
    { slot: "bottom", label: "BAIXO"  },
  ]

  function slotModel(slot) {
    if (root.isH) {
      if (slot === "left")   return root.slotLeft
      if (slot === "center") return root.slotCenter
      if (slot === "right")  return root.slotRight
    } else {
      if (slot === "top")    return root.slotTop
      if (slot === "middle") return root.slotMiddle
      if (slot === "bottom") return root.slotBottom
    }
    return []
  }

  function modInfo(id) {
    var m = {
      workspaces:    { icon: "\uf0c8", label: "Workspaces"   },
      clock:         { icon: "\uf017", label: "Relógio"      },
      volume:        { icon: "\ufa7d", label: "Volume"       },
      mediaplayer:   { icon: "\uf001", label: "Mídia"        },
      quicksettings: { icon: "\uf013", label: "Config"       },
      notifications: { icon: "\uf0f3", label: "Notificações" },
      separator:     { icon: "\uf07e", label: "Sep"          },
      spacer:        { icon: "\uf047", label: "Espaço"       },
    }
    return m[id] || { icon: "\uf128", label: id }
  }

  // ── Slots ─────────────────────────────────────────────────────────────
  C.CfgSection {
    title:       root.isH ? "SLOTS — HORIZONTAL" : "SLOTS — VERTICAL"
    colorTextDim: root.colorTextDim
  }

  Repeater {
    model: root.isH ? root.hSlots : root.vSlots

    delegate: Item {
      id: slotDel
      required property var    modelData
      readonly property string slotName: modelData.slot
      width: parent.width
      height: slotCol.implicitHeight + 22

      Rectangle {
        anchors.fill: parent
        radius: 8
        color:  Qt.rgba(1,1,1,0.025)
        border.color: darea.containsDrag
          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.6)
          : Qt.rgba(1,1,1,0.07)
        border.width: 1
        Behavior on border.color { ColorAnimation { duration: 80 } }

        DropArea {
          id: darea
          anchors.fill: parent
          keys: ["cfgmod"]
          onDropped: (drop) => {
            var id = root.dragSlot === "pool"
              ? root.dragId
              : root.slotModel(root.dragSlot)[root.dragIdx]
            if (!id) return
            if (root.dragSlot !== "pool") {
              var src = root.slotModel(root.dragSlot).slice()
              src.splice(root.dragIdx, 1)
              root.slotChanged(root.dragSlot, src)
            }
            var dst = root.slotModel(slotDel.slotName).slice()
            dst.push(id)
            root.slotChanged(slotDel.slotName, dst)
            root.dragId = ""; root.dragSlot = ""; root.dragIdx = -1
            drop.accept()
          }
        }

        Column {
          id: slotCol
          anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
          spacing: 8

          Text {
            text:           modelData.label
            color:          root.colorTextDim
            font.pixelSize: 9
            font.weight:    Font.Medium
            font.family:    "JetBrainsMono Nerd Font"
          }

          Flow {
            width: parent.width
            spacing: 5

            Repeater {
              model: root.slotModel(slotDel.slotName)

              delegate: Item {
                id: chip
                required property string modelData
                required property int    index
                readonly property var    info: root.modInfo(modelData)
                height: 28
                width:  chipRow.implicitWidth + 30

                Rectangle {
                  anchors.fill: parent
                  radius: 6
                  color: chipMa.drag.active
                    ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.1)
                    : Qt.rgba(1,1,1,0.07)
                  border.color: chipMa.drag.active ? root.colorAccent : Qt.rgba(1,1,1,0.14)
                  border.width: 1
                  Behavior on color        { ColorAnimation { duration: 80 } }
                  Behavior on border.color { ColorAnimation { duration: 80 } }

                  Row {
                    id: chipRow
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    spacing: 5
                    Text { text: chip.info.icon; color: root.colorAccent; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: chip.info.label; color: root.colorText; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                    Rectangle {
                      width: 16; height: 16; radius: 8; color: "transparent"
                      anchors.verticalCenter: parent.verticalCenter
                      Text { anchors.centerIn: parent; text: "\uf00d"; font.pixelSize: 7; font.family: "JetBrainsMono Nerd Font"
                        color: Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.55) }
                      MouseArea { anchors.fill: parent
                        onClicked: (m) => {
                          m.accepted = true
                          var a = root.slotModel(slotDel.slotName).slice()
                          a.splice(chip.index, 1)
                          root.slotChanged(slotDel.slotName, a)
                        }
                        onPressed:  (m) => m.accepted = true
                        onReleased: (m) => m.accepted = true
                      }
                    }
                  }
                }

                // Ghost drag
                Rectangle {
                  id: ghost
                  width: chip.width; height: chip.height; x: 0; y: 0; z: 200; radius: 6
                  visible: chipMa.drag.active
                  color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
                  border.color: root.colorAccent; border.width: 1
                  Drag.active:    chipMa.drag.active
                  Drag.keys:      ["cfgmod"]
                  Drag.hotSpot.x: width / 2
                  Drag.hotSpot.y: height / 2
                  Text { anchors.centerIn: parent; text: chip.info.icon + "  " + chip.info.label
                    color: root.colorText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
                }

                MouseArea {
                  id: chipMa; anchors.fill: parent; z: -1
                  drag.target: ghost; drag.threshold: 8
                  onPressed: {
                    ghost.x = 0; ghost.y = 0
                    root.dragId   = chip.modelData
                    root.dragSlot = slotDel.slotName
                    root.dragIdx  = chip.index
                  }
                  onReleased: { if (drag.active) ghost.Drag.drop(); ghost.x = 0; ghost.y = 0 }
                }
              }
            }

            Text {
              visible:        root.slotModel(slotDel.slotName).length === 0
              text:           "arrastar aqui"
              font.pixelSize: 9; height: 28
              color:          Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
              verticalAlignment: Text.AlignVCenter
            }
          }
        }
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorTextDim }
  C.CfgSection { title: "POOL — CLIQUE PARA ADICIONAR / ARRASTE PARA SLOT"; colorTextDim: root.colorTextDim }

  // ── Pool ──────────────────────────────────────────────────────────────
  Flow {
    width: parent.width
    spacing: 6

    Repeater {
      model: [
        { id: "workspaces",    icon: "\uf0c8", label: "Workspaces"   },
        { id: "clock",         icon: "\uf017", label: "Relógio"      },
        { id: "volume",        icon: "\ufa7d", label: "Volume"       },
        { id: "mediaplayer",   icon: "\uf001", label: "Mídia"        },
        { id: "quicksettings", icon: "\uf013", label: "Config"       },
        { id: "notifications", icon: "\uf0f3", label: "Notificações" },
        { id: "separator",     icon: "\uf07e", label: "Separador"    },
        { id: "spacer",        icon: "\uf047", label: "Espaço"       },
      ]
      delegate: Item {
        id: pool
        required property var modelData
        height: 30; width: poolRow.implicitWidth + 20

        Rectangle {
          anchors.fill: parent; radius: 6
          color: poolMa.drag.active
            ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.12)
            : (poolHov.containsMouse ? Qt.rgba(1,1,1,0.1) : Qt.rgba(1,1,1,0.05))
          border.color: poolMa.drag.active ? root.colorAccent : Qt.rgba(1,1,1,0.1)
          border.width: 1
          Behavior on color { ColorAnimation { duration: 80 } }

          Row {
            id: poolRow; anchors.centerIn: parent; spacing: 6
            Text { text: pool.modelData.icon; color: root.colorAccent; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font"; anchors.verticalCenter: parent.verticalCenter }
            Text { text: pool.modelData.label; color: root.colorText; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
          }
        }

        Rectangle {
          id: pghost; width: pool.width; height: pool.height; x: 0; y: 0; z: 200; radius: 6
          visible: poolMa.drag.active
          color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.3)
          border.color: root.colorAccent; border.width: 1
          Drag.active: poolMa.drag.active; Drag.keys: ["cfgmod"]
          Drag.hotSpot.x: width/2; Drag.hotSpot.y: height/2
          Text { anchors.centerIn: parent; text: pool.modelData.icon+"  "+pool.modelData.label
            color: root.colorText; font.pixelSize: 10; font.family: "JetBrainsMono Nerd Font" }
        }

        MouseArea { id: poolHov; anchors.fill: parent; hoverEnabled: true }
        MouseArea {
          id: poolMa; anchors.fill: parent; drag.target: pghost; drag.threshold: 8
          onPressed:  { pghost.x=0; pghost.y=0; root.dragId=pool.modelData.id; root.dragSlot="pool"; root.dragIdx=-1 }
          onReleased: { if (drag.active) pghost.Drag.drop(); pghost.x=0; pghost.y=0 }
          onClicked:  root.moduleAdded(root.isH ? "right" : "bottom", pool.modelData.id)
        }
      }
    }
  }
}
