import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs
import '../../components' as C

// modules/default/config/tabs/widgets/WidgetsTabFavorites.qml → modules/widgets/favorites/
import '../../../../widgets/favorites' as Shared

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

  Shared.FavoritesConfig { id: config }

  // limpa placeholders de argumento (%f %U etc) do Exec=, mesma regra
  // usada pelo dmenu em DmenuContent._allApps
  function _cleanExec(execString) {
    return (execString || "").replace(/%[uUfFdDnNickvm]/g, "").trim()
  }

  // ── apps instalados via DesktopEntries (mesma fonte que o dmenu usa) ──
  readonly property var _allApps: {
    const apps = DesktopEntries.applications.values
    const list = []
    for (let i = 0; i < apps.length; i++) {
      const a = apps[i]
      if (!a || !a.name) continue
      const name = a.name.trim()
      if (name === "") continue
      list.push({ name, comment: (a.comment || "").trim(), icon: a.icon || "", exec: root._cleanExec(a.execString) })
    }
    list.sort((a, b) => a.name.localeCompare(b.name))
    return list
  }

  property string _searchQuery: ""
  readonly property var _searchResults: {
    const q = _searchQuery.trim().toLowerCase()
    if (q === "") return []
    return root._allApps.filter(a => a.name.toLowerCase().includes(q)).slice(0, 8)
  }

  C.CfgScroll {

    C.CfgSection { title: "WIDGET DE APPS FAVORITOS"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      font.pixelSize: 10
      text: "Grade de atalhos. Busque um app instalado abaixo pra adicionar automaticamente " +
            "(nome, ícone e comando vêm do próprio .desktop) ou cadastre manualmente algo " +
            "que não apareça na busca."
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "BUSCAR APP INSTALADO"; colorTextDim: root.colorTextDim }

    Rectangle {
      width: parent.width
      height: 34
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"

      TextInput {
        id: searchInput
        anchors.fill: parent
        anchors.margins: 8
        color: root.colorText
        font.pixelSize: 12
        clip: true
        selectByMouse: true
        onTextChanged: root._searchQuery = text

        Text {
          anchors.verticalCenter: parent.verticalCenter
          visible: searchInput.text.length === 0
          text: "digite pra buscar (ex: firefox, spotify…)"
          color: root.colorTextDim
          opacity: 0.5
          font.pixelSize: 12
        }
      }
    }

    Column {
      width: parent.width
      spacing: 4
      visible: root._searchQuery.trim().length > 0

      Text {
        visible: root._searchResults.length === 0
        text: "nenhum app encontrado"
        color: root.colorTextDim
        opacity: 0.5
        font.pixelSize: 11
      }

      Repeater {
        model: root._searchResults
        delegate: Rectangle {
          required property var modelData
          readonly property bool alreadyAdded: config.hasCommand(modelData.exec)
          width: parent.width
          height: 40
          radius: 8
          color: resultArea.containsMouse ? Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.7)
                                           : Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.35)

          RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 10
            spacing: 8

            Item {
              width: 22; height: 22
              IconImage {
                id: resultIcon
                anchors.centerIn: parent
                width: 20; height: 20
                smooth: true
                opacity: status === Image.Ready ? 1 : 0
                source: {
                  const ico = modelData.icon || ""
                  if (ico === "") return ""
                  if (ico.startsWith("/") || ico.startsWith("file://")) return ico
                  return "image://icon/" + ico
                }
              }
              Text {
                anchors.centerIn: parent
                visible: resultIcon.status !== Image.Ready
                text: (modelData.name || "?").charAt(0).toUpperCase()
                color: root.colorAccent
                opacity: 0.6
                font { pixelSize: 12; bold: true }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 0
              Text {
                Layout.fillWidth: true
                text: modelData.name
                color: root.colorText
                font.pixelSize: 12
                elide: Text.ElideRight
              }
              Text {
                Layout.fillWidth: true
                visible: modelData.comment !== ""
                text: modelData.comment
                color: root.colorTextDim
                opacity: 0.6
                font.pixelSize: 9
                elide: Text.ElideRight
              }
            }

            Text {
              text: alreadyAdded ? "adicionado" : "+ adicionar"
              color: alreadyAdded ? root.colorTextDim : root.colorAccent
              opacity: alreadyAdded ? 0.5 : 1
              font.pixelSize: 11
            }
          }

          MouseArea {
            id: resultArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: alreadyAdded ? Qt.ArrowCursor : Qt.PointingHandCursor
            onClicked: {
              if (alreadyAdded) return
              config.addApp(modelData.name, modelData.exec, modelData.icon)
              searchInput.text = ""
            }
          }
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "FAVORITOS"; colorTextDim: root.colorTextDim }

    // ── lista de favoritos já adicionados ──────────────────────────────
    Column {
      width: parent.width
      spacing: 6

      Text {
        visible: config.apps.length === 0
        text: "nenhum favorito ainda — busque um app acima"
        color: root.colorTextDim
        opacity: 0.5
        font.pixelSize: 11
      }

      Repeater {
        model: config.apps
        delegate: Rectangle {
          required property var modelData
          width: parent.width
          height: 44
          radius: 8
          color: Qt.rgba(root.colorSidebar.r, root.colorSidebar.g, root.colorSidebar.b, 0.5)

          RowLayout {
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8

            Item {
              width: 26; height: 26
              IconImage {
                id: favIcon
                anchors.centerIn: parent
                width: 22; height: 22
                smooth: true
                opacity: status === Image.Ready ? 1 : 0
                source: {
                  const ico = modelData.icon || ""
                  if (ico === "") return ""
                  if (ico.startsWith("/") || ico.startsWith("file://")) return ico
                  return "image://icon/" + ico
                }
              }
              Text {
                anchors.centerIn: parent
                visible: favIcon.status !== Image.Ready
                text: (modelData.name || "?").charAt(0).toUpperCase()
                color: root.colorAccent
                opacity: 0.6
                font { pixelSize: 12; bold: true }
              }
            }

            ColumnLayout {
              Layout.fillWidth: true
              spacing: 2

              TextInput {
                Layout.fillWidth: true
                text: modelData.name
                color: root.colorText
                font.pixelSize: 12
                clip: true
                selectByMouse: true
                onEditingFinished: config.updateApp(modelData.id, { name: text })
              }
              TextInput {
                Layout.fillWidth: true
                text: modelData.command
                color: root.colorTextDim
                font.pixelSize: 10
                clip: true
                selectByMouse: true
                onEditingFinished: config.updateApp(modelData.id, { command: text })
              }
            }

            Text {
              text: "\uf1f8"
              color: root.colorTextDim
              font { pixelSize: 13; family: "JetBrainsMono Nerd Font" }
              MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: config.removeApp(modelData.id)
              }
            }
          }
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "ADICIONAR MANUALMENTE"; colorTextDim: root.colorTextDim }

    Text {
      width: parent.width
      wrapMode: Text.WordWrap
      color: root.colorTextDim
      opacity: 0.7
      font.pixelSize: 10
      text: "Pra algo que não tem .desktop instalado (script, site, comando custom). " +
            "Ícone é opcional — aceita nome de ícone do tema (ex: firefox) ou caminho " +
            "absoluto pra uma imagem; deixe vazio pra usar a inicial do nome."
    }

    Rectangle {
      width: parent.width
      height: 108
      radius: 8
      border.width: 1
      border.color: root.colorDivider
      color: "transparent"

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 8
        spacing: 6

        RowLayout {
          Layout.fillWidth: true
          spacing: 6

          Rectangle {
            width: 26; height: 26; radius: 6
            border.width: 1
            border.color: root.colorDivider
            color: "transparent"
            IconImage {
              id: newIconPreview
              anchors.centerIn: parent
              width: 20; height: 20
              smooth: true
              opacity: status === Image.Ready ? 1 : 0
              source: {
                const ico = newIconInput.text
                if (ico === "") return ""
                if (ico.startsWith("/") || ico.startsWith("file://")) return ico
                return "image://icon/" + ico
              }
            }
          }

          TextInput {
            id: newNameInput
            Layout.fillWidth: true
            color: root.colorText
            font.pixelSize: 12
            selectByMouse: true
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: newNameInput.text.length === 0
              text: "nome"
              color: root.colorTextDim
              opacity: 0.5
              font.pixelSize: 12
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          TextInput {
            id: newCommandInput
            Layout.fillWidth: true
            color: root.colorText
            font.pixelSize: 11
            selectByMouse: true
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: newCommandInput.text.length === 0
              text: "comando (ex: firefox --new-window)"
              color: root.colorTextDim
              opacity: 0.5
              font.pixelSize: 11
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: 6
          TextInput {
            id: newIconInput
            Layout.fillWidth: true
            color: root.colorText
            font.pixelSize: 11
            selectByMouse: true
            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: newIconInput.text.length === 0
              text: "ícone (opcional): nome do tema ou caminho"
              color: root.colorTextDim
              opacity: 0.5
              font.pixelSize: 11
            }
          }

          Text {
            text: "adicionar"
            color: root.colorAccent
            font.pixelSize: 11
            MouseArea {
              anchors.fill: parent
              anchors.margins: -6
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (newNameInput.text.trim().length === 0) return
                config.addApp(newNameInput.text, newCommandInput.text, newIconInput.text)
                newNameInput.text = ""
                newCommandInput.text = ""
                newIconInput.text = ""
              }
            }
          }
        }
      }
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "POSIÇÃO"; colorTextDim: root.colorTextDim }

    PositionGrid {
      width: parent.width
      value: config.position
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      onSelected: (i) => config.position = i
    }

    C.CfgSlider {
      label: "Margem da borda da tela"; from: 0; to: 160; step: 4; unit: " px"
      value: config.edgeMargin
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.edgeMargin = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }
    C.CfgSection { title: "GRADE"; colorTextDim: root.colorTextDim }

    C.CfgSlider {
      label: "Colunas"; from: 2; to: 8; step: 1; unit: ""
      value: config.columns
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.columns = v
    }
    C.CfgSlider {
      label: "Tamanho do ícone"; from: 14; to: 36; step: 1; unit: " px"
      value: config.iconSize
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.iconSize = v
    }
    C.CfgSlider {
      label: "Largura"; from: 140; to: 360; step: 4; unit: " px"
      value: config.fixedWidth
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedWidth = v
    }
    C.CfgSlider {
      label: "Altura máxima"; from: 80; to: 320; step: 4; unit: " px"
      value: config.fixedHeight
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorProgressBg: root.colorProgressBg
      onMoved: (v) => config.fixedHeight = v
    }

    C.CfgDiv { colorDivider: root.colorDivider }

    ResetButton {
      width: parent.width
      colorAccent: root.colorAccent
      label: "restaurar padrões"
      onClicked: {
        config.position = 4
        config.edgeMargin = 48
        config.fixedWidth = 220
        config.fixedHeight = 140
        config.columns = 4
        config.iconSize = 22
      }
    }
  }
}

