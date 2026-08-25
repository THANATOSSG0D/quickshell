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
    { id: "process",   label: "Processos"        },
    { id: "bluetooth", label: "Bluetooth"        },
    { id: "favorites",   label: "Apps favoritos" },
    { id: "habits",      label: "Hábitos"        },
    { id: "mediaplayer", label: "Media Player"   },
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
      // sem isso, esse ColumnLayout (que não está dentro de outro Layout —
      // o pai é o Column cru do CfgScroll) só recebe height = implicitHeight
      // UMA VEZ na criação; virar binding vivo garante que o Column pai
      // recalcula a altura total sempre que o conteúdo mudar de tamanho.
      height: implicitHeight
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
      text: "Cada grupo junta os widgets marcados nele num único card. Com 1 coluna " +
            "(padrão) fica empilhado verticalmente; com mais colunas, cada uma empilha " +
            "só os SEUS widgets pela própria altura — nunca esticada pra bater com a " +
            "coluna vizinha. Marque um widget como 'linha inteira' pra ele ocupar a " +
            "largura toda e quebrar o fluxo de colunas naquele ponto (as colunas " +
            "recomeçam balanceadas depois dele). Além da posição em grid, dá pra " +
            "afinar o card com os sliders de ajuste fino (px), e cada widget dentro " +
            "do grupo tem seu próprio controle de escala (50%–200%) pra diminuir ou " +
            "aumentar ele individualmente. Um widget só pode estar em um grupo por " +
            "vez. Widgets fora de qualquer grupo continuam aparecendo do jeito de " +
            "sempre, na posição individual deles."
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ColumnLayout {
      width: parent.width
      // idem: binding vivo, não atribuição única — esse é o container que
      // mais muda de altura no tab inteiro (grupos, colunas, toggles),
      // então era onde o corte mais aparecia.
      height: implicitHeight
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

          // ── cabeçalho: nome (linha própria, largura toda) + habilitar/excluir ──
          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            Rectangle {
              id: nameBox
              Layout.fillWidth: true
              Layout.minimumWidth: 120
              height: 30
              radius: 6
              color: "transparent"
              border.width: 1
              border.color: nameInput.activeFocus
                ? root.colorAccent
                : Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
              Behavior on border.color { ColorAnimation { duration: 60 } }

              TextInput {
                id: nameInput
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                verticalAlignment: TextInput.AlignVCenter
                text: groupBlock.group.name || ""
                color: root.colorText
                font.pixelSize: 12
                font.bold: true
                selectByMouse: true
                clip: true
                onEditingFinished: layoutCfg.setGroupName(groupBlock.group.id, text.trim())

                // placeholder: "Grupo N · X widget(s)" enquanto não tem
                // nome próprio e o campo não está em foco
                Text {
                  visible: nameInput.text.length === 0 && !nameInput.activeFocus
                  anchors.verticalCenter: parent.verticalCenter
                  text: groupBlock.groupName +
                        (groupBlock.group.members.length > 0
                           ? "  ·  " + groupBlock.group.members.length + " widget(s)"
                           : "  ·  vazio")
                  color: root.colorTextDim
                  font: nameInput.font
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              Item { Layout.fillWidth: true } // empurra os dois controles pra direita

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

          Text {
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            color: root.colorTextDim
            font.pixelSize: 9
            text: "Ajuste fino: desloca o card por cima da posição do grid acima, " +
                  "pra quando os 9 pontos não bastam. Positivo = direita/baixo."
          }
          C.CfgSlider {
            Layout.fillWidth: true
            label: "Ajuste fino horizontal"; from: -300; to: 300; step: 2; unit: " px"
            value: groupBlock.group.offsetX || 0
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupOffsetX(groupBlock.group.id, v)
          }
          C.CfgSlider {
            Layout.fillWidth: true
            label: "Ajuste fino vertical"; from: -300; to: 300; step: 2; unit: " px"
            value: groupBlock.group.offsetY || 0
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupOffsetY(groupBlock.group.id, v)
          }

          C.CfgSlider {
            Layout.fillWidth: true
            label: "Colunas"; from: 1; to: 4; step: 1; unit: ""
            value: groupBlock.group.columns || 1
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupColumns(groupBlock.group.id, v)
          }

          // ── auto-organizar ──
          Rectangle {
            Layout.fillWidth: true
            visible: (groupBlock.group.columns || 1) > 1
            height: 28
            radius: 8
            color: autoMa.containsMouse
              ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.15)
              : "transparent"
            border.color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b,
                                  autoMa.containsMouse ? 0.6 : 0.3)
            border.width: 1

            Row {
              anchors.centerIn: parent; spacing: 6
              Text {
                text: "󰒓"; color: root.colorAccent
                font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
                anchors.verticalCenter: parent.verticalCenter
              }
              Text {
                text: "Auto-organizar colunas"; color: root.colorAccent
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
              }
            }

            MouseArea {
              id: autoMa; anchors.fill: parent; hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: layoutCfg.autoBalanceGroup(groupBlock.group.id)
            }
          }
        Item {
            visible: (groupBlock.group.columns || 1) > 1
            width: parent.width
            height: textItem.implicitHeight

          Text {
              id: textItem
              width: parent.width
              wrapMode: Text.WordWrap
              color: root.colorTextDim
              font.pixelSize: 9
              text: "Redistribui os widgets (que não estão em 'linha inteira') tentando " +
                    "equilibrar a altura total de cada coluna — usa uma estimativa por tipo " +
                    "de widget, não é exato, mas evita ter que arrumar coluna por coluna."
            }
        }

          C.CfgDiv { Layout.fillWidth: true; colorDivider: root.colorDivider }
          C.CfgSection { title: "TAMANHO E ESPAÇAMENTO"; colorTextDim: root.colorTextDim }

          C.CfgSlider {
            Layout.fillWidth: true
            label: "Largura mínima da coluna"; from: 0; to: 400; step: 10; unit: " px"
            value: groupBlock.group.columnMinWidth || 0
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupColumnMinWidth(groupBlock.group.id, v)
          }
          Text {
            visible: (groupBlock.group.columnMinWidth || 0) === 0
            width: parent.width
            wrapMode: Text.WordWrap
            color: root.colorTextDim
            font.pixelSize: 9
            text: "0 = sem piso, cada coluna usa só o tamanho do maior widget dela."
          }
          C.CfgSlider {
            Layout.fillWidth: true
            visible: (groupBlock.group.columns || 1) > 1
            label: "Espaçamento entre colunas"; from: 0; to: 60; step: 2; unit: " px"
            value: groupBlock.group.columnSpacing !== undefined ? groupBlock.group.columnSpacing : 20
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupColumnSpacing(groupBlock.group.id, v)
          }
          C.CfgSlider {
            Layout.fillWidth: true
            label: "Espaçamento entre widgets (vertical)"; from: 0; to: 60; step: 2; unit: " px"
            value: groupBlock.group.itemSpacing !== undefined ? groupBlock.group.itemSpacing : 20
            colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
            colorText: root.colorText; colorProgressBg: root.colorProgressBg
            onMoved: (v) => layoutCfg.setGroupItemSpacing(groupBlock.group.id, v)
          }

          C.CfgSection { title: "APARÊNCIA DO CARD"; colorTextDim: root.colorTextDim }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 6

            C.CfgPalette {
              Layout.fillWidth: true
              label: "Cor de fundo"
              value: groupBlock.group.bgColor || "surface_container"
              colors: root.colors; overlay: root.overlay
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorSidebar: root.colorSidebar
              colorDivider: root.colorDivider
              onEdited: (v) => layoutCfg.setGroupBgColor(groupBlock.group.id, v)
            }
            C.CfgSlider {
              Layout.fillWidth: true
              label: "Opacidade do fundo"; from: 0; to: 100; step: 5; unit: "%"
              value: Math.round((groupBlock.group.bgOpacity !== undefined ? groupBlock.group.bgOpacity : 0.55) * 100)
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorProgressBg: root.colorProgressBg
              onMoved: (v) => layoutCfg.setGroupBgOpacity(groupBlock.group.id, v / 100)
            }

            C.CfgPalette {
              Layout.fillWidth: true
              label: "Cor da borda"
              value: groupBlock.group.borderColor || "outline_variant"
              colors: root.colors; overlay: root.overlay
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorSidebar: root.colorSidebar
              colorDivider: root.colorDivider
              onEdited: (v) => layoutCfg.setGroupBorderColor(groupBlock.group.id, v)
            }
            C.CfgSlider {
              Layout.fillWidth: true
              label: "Opacidade da borda"; from: 0; to: 100; step: 5; unit: "%"
              value: Math.round((groupBlock.group.borderOpacity !== undefined ? groupBlock.group.borderOpacity : 0.4) * 100)
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorProgressBg: root.colorProgressBg
              onMoved: (v) => layoutCfg.setGroupBorderOpacity(groupBlock.group.id, v / 100)
            }
            C.CfgSlider {
              Layout.fillWidth: true
              label: "Espessura da borda"; from: 0; to: 4; step: 1; unit: " px"
              value: groupBlock.group.borderWidth !== undefined ? groupBlock.group.borderWidth : 1
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorProgressBg: root.colorProgressBg
              onMoved: (v) => layoutCfg.setGroupBorderWidth(groupBlock.group.id, v)
            }
            C.CfgSlider {
              Layout.fillWidth: true
              label: "Arredondamento"; from: 0; to: 30; step: 2; unit: " px"
              value: groupBlock.group.radius !== undefined ? groupBlock.group.radius : 14
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorProgressBg: root.colorProgressBg
              onMoved: (v) => layoutCfg.setGroupRadius(groupBlock.group.id, v)
            }
          }

          // ── widgets do grupo ──
          C.CfgDiv { Layout.fillWidth: true; colorDivider: root.colorDivider }
          C.CfgSection { title: "WIDGETS DO GRUPO"; colorTextDim: root.colorTextDim }

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Repeater {
              model: root._allWidgets
              delegate: RowLayout {
                id: widgetRow
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

                // coluna do widget dentro do card — só faz sentido mostrar
                // quando o grupo tem mais de 1 coluna disponível E o
                // widget não estiver marcado como "linha inteira" (nesse
                // caso a coluna dele não importa, ele quebra o fluxo)
                Row {
                  visible: widgetRow.included && (groupBlock.group.columns || 1) > 1
                           && !layoutCfg.memberIsFullWidth(groupBlock.group, widgetRow.modelData.id)
                  spacing: 3
                  Repeater {
                    model: groupBlock.group.columns || 1
                    delegate: Rectangle {
                      required property int modelData
                      readonly property int colNum: modelData + 1
                      readonly property bool active: layoutCfg.memberColumn(groupBlock.group, widgetRow.modelData.id) === colNum
                      width: 16; height: 16; radius: 3
                      color: active ? root.colorAccent : "transparent"
                      border.width: 1
                      border.color: active ? root.colorAccent : root.colorTextDim

                      Text {
                        anchors.centerIn: parent
                        text: parent.colNum
                        font.pixelSize: 8
                        color: parent.active ? Colors.background : root.colorTextDim
                      }
                      MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: layoutCfg.setMemberColumn(groupBlock.group.id, widgetRow.modelData.id, colNum)
                      }
                    }
                  }
                }

                // escala individual do widget dentro do card — 50% a
                // 200%, em passos de 10%. Sempre visível pra qualquer
                // widget incluído, independente de coluna/linha inteira.
                Row {
                  visible: widgetRow.included
                  spacing: 3

                  Rectangle {
                    width: 16; height: 16; radius: 3
                    border.width: 1; border.color: root.colorTextDim
                    color: "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "−"; font.pixelSize: 10; color: root.colorTextDim
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        const cur = layoutCfg.memberScale(groupBlock.group, widgetRow.modelData.id)
                        layoutCfg.setMemberScale(groupBlock.group.id, widgetRow.modelData.id,
                          Math.round((cur - 0.1) * 10) / 10)
                      }
                    }
                  }

                  Text {
                    width: 30
                    horizontalAlignment: Text.AlignHCenter
                    text: Math.round(layoutCfg.memberScale(groupBlock.group, widgetRow.modelData.id) * 100) + "%"
                    color: root.colorTextDim
                    font.pixelSize: 9
                  }

                  Rectangle {
                    width: 16; height: 16; radius: 3
                    border.width: 1; border.color: root.colorTextDim
                    color: "transparent"
                    Text {
                      anchors.centerIn: parent
                      text: "+"; font.pixelSize: 10; color: root.colorTextDim
                    }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: {
                        const cur = layoutCfg.memberScale(groupBlock.group, widgetRow.modelData.id)
                        layoutCfg.setMemberScale(groupBlock.group.id, widgetRow.modelData.id,
                          Math.round((cur + 0.1) * 10) / 10)
                      }
                    }
                  }
                }

                // "ocupar linha inteira" — só faz sentido com mais de 1
                // coluna (com 1 coluna já é sempre largura total mesmo)
                Rectangle {
                  visible: widgetRow.included && (groupBlock.group.columns || 1) > 1
                  readonly property bool active: layoutCfg.memberIsFullWidth(groupBlock.group, widgetRow.modelData.id)
                  width: fwLabel.implicitWidth + 10; height: 16; radius: 3
                  color: active ? root.colorAccent : "transparent"
                  border.width: 1
                  border.color: active ? root.colorAccent : root.colorTextDim

                  Text {
                    id: fwLabel
                    anchors.centerIn: parent
                    text: "linha inteira"
                    font.pixelSize: 8
                    color: parent.active ? Colors.background : root.colorTextDim
                  }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: layoutCfg.setMemberFullWidth(
                      groupBlock.group.id, widgetRow.modelData.id, !parent.active)
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
