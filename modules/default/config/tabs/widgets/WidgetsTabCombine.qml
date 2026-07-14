import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabCombine.qml → modules/widgets/
import '../../../../widgets' as Shared

Item {
  id: root

  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  anchors.fill: parent

  Shared.WidgetLayoutConfig { id: layoutCfg }

  readonly property var _allWidgets: [
    { id: "clock",     label: "Relógio"          },
    { id: "todo",      label: "Lista de tarefas" },
    { id: "calendar",  label: "Calendário"       },
    { id: "weather",   label: "Clima"            },
    { id: "cpu",       label: "CPU"              },
    { id: "ram",       label: "RAM"              },
    { id: "gpu",       label: "GPU"              },
    { id: "network",   label: "Rede"             },
    { id: "disk",      label: "Disco"            },
    { id: "system",    label: "Sistema"          },
    { id: "bluetooth", label: "Bluetooth"        },
  ]

  C.CfgScroll {

    C.CfgSection { title: "WIDGETS ATIVOS"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Desativar aqui tira o widget de TODO lugar — individual e de dentro de " +
            "qualquer grupo combinado — sem precisar desmarcar ele do grupo. Fica " +
            "'pausado': volta sozinho pra onde estava se reativar depois."
    }

    ColumnLayout {
      width: parent.width
      spacing: 2

      Repeater {
        model: root._allWidgets
        delegate: RowLayout {
          required property var modelData
          Layout.fillWidth: true

          C.CfgToggle {
            Layout.fillWidth: true
            label: modelData.label
            checked: layoutCfg.isEnabled(modelData.id)
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            onToggled: layoutCfg.setEnabled(modelData.id, !layoutCfg.isEnabled(modelData.id))
          }
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "MODO COMBINADO"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Cada grupo junta os widgets marcados nele num único card, empilhados na ordem " +
            "escolhida, com divisores em vez de flutuar cada um separado. Um widget só pode " +
            "estar em um grupo por vez. Widgets fora de qualquer grupo continuam aparecendo " +
            "do jeito de sempre, na posição individual deles."
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ColumnLayout {
      width: parent.width
      spacing: 10

      Repeater {
        model: layoutCfg.groups
        delegate: ColumnLayout {
          id: groupBlock
          required property var modelData
          required property int index
          Layout.fillWidth: true
          spacing: 8

          readonly property var group: modelData
          readonly property string groupName: "Grupo " + (index + 1)

          // ── cabeçalho: nome, habilitar/desabilitar, excluir ──
          RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
              Layout.fillWidth: true
              text: groupBlock.groupName +
                    (groupBlock.group.members.length > 0
                       ? "  ·  " + groupBlock.group.members.length + " widget(s)"
                       : "  ·  vazio")
              color: root.colorText
              font.pixelSize: 12
              font.bold: true
            }

            C.CfgToggle {
              label: "Ativo"
              checked: groupBlock.group.enabled
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              onToggled: layoutCfg.setGroupEnabled(groupBlock.group.id, !groupBlock.group.enabled)
            }

            Text {
              text: "󰩹"
              color: root.colorTextDim
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 13 }
              MouseArea {
                anchors.fill: parent
                anchors.margins: -4
                cursorShape: Qt.PointingHandCursor
                onClicked: layoutCfg.removeGroup(groupBlock.group.id)
              }
            }
          }

          // ── posição do grupo ──
          PositionGrid {
            Layout.fillWidth: true
            value: groupBlock.group.position
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            onSelected: (i) => layoutCfg.setGroupPosition(groupBlock.group.id, i)
          }

          C.CfgSlider {
            Layout.fillWidth: true
            label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
            value: groupBlock.group.edgeMargin
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupEdgeMargin(groupBlock.group.id, v)
          }

          // ── widgets do grupo ──
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
              model: root._allWidgets
              delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 8

                readonly property int memberIndex: groupBlock.group.members.indexOf(modelData.id)
                readonly property bool included: memberIndex !== -1
                readonly property string otherGroupId: layoutCfg.groupForWidget(modelData.id)
                readonly property bool inOtherGroup: !included && otherGroupId !== "" && otherGroupId !== groupBlock.group.id
                readonly property bool widgetDisabled: !layoutCfg.isEnabled(modelData.id)

                Rectangle {
                  width: 16; height: 16; radius: 4
                  border.width: 1.5
                  border.color: parent.included ? root.colorAccent : root.colorTextDim
                  color: parent.included ? root.colorAccent : "transparent"
                  opacity: (parent.inOtherGroup || parent.widgetDisabled) ? 0.4 : 1
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: layoutCfg.toggleMember(groupBlock.group.id, modelData.id)
                  }
                }

                Text {
                  Layout.fillWidth: true
                  text: modelData.label
                        + (parent.included ? "  ·  posição " + (parent.memberIndex + 1) : "")
                        + (parent.inOtherGroup ? "  ·  já em outro grupo" : "")
                        + (parent.widgetDisabled ? "  ·  desativado" : "")
                  color: (parent.inOtherGroup || parent.widgetDisabled) ? root.colorTextDim : root.colorText
                  font.pixelSize: 12
                }

                Text {
                  visible: parent.included
                  text: "▲"
                  color: root.colorTextDim
                  font.pixelSize: 9
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: layoutCfg.moveMember(groupBlock.group.id, modelData.id, -1)
                  }
                }
                Text {
                  visible: parent.included
                  text: "▼"
                  color: root.colorTextDim
                  font.pixelSize: 9
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: layoutCfg.moveMember(groupBlock.group.id, modelData.id, 1)
                  }
                }
              }
            }

            Text {
              visible: groupBlock.group.members.length === 0
              text: "Nenhum widget selecionado — marque acima pra montar esse grupo."
              color: root.colorTextDim
              font.pixelSize: 11
            }
          }

          C.CfgDiv { Layout.fillWidth: true; colorDivider: root.colorDivider }
        }
      }

      Text {
        visible: layoutCfg.groups.length === 0
        Layout.fillWidth: true
        text: "Nenhum grupo criado ainda."
        color: root.colorTextDim
        font.pixelSize: 11
      }

      // ── adicionar grupo ──
      Rectangle {
        Layout.fillWidth: true
        height: 30
        radius: 8
        color: addMa.containsMouse
          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
          : "transparent"
        border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b,
                              addMa.containsMouse ? 0.6 : 0.3)
        border.width: 1
        Behavior on color        { ColorAnimation { duration: 60 } }
        Behavior on border.color { ColorAnimation { duration: 60 } }

        Row {
          anchors.centerIn: parent; spacing: 6
          Text {
            text: "󰐕"; color: root.colorAccent
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
            anchors.verticalCenter: parent.verticalCenter
          }
          Text {
            text: "Adicionar grupo"; color: root.colorAccent
            font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
          }
        }

        MouseArea {
          id: addMa; anchors.fill: parent; hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: layoutCfg.addGroup()
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "remover todos os grupos"
      onClicked: layoutCfg.groups = []
    }
  }
}
