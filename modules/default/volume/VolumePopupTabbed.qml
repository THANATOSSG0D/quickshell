import Quickshell
import QtQuick
import QtQuick.Layouts
import "../bar" as Bar

// ── VolumePopupTabbed ─────────────────────────────────────────────────────
// Painel de volume unificado com abas: Saída (sink) e Microfone (source).
// Substitui os dois VolumePopup separados em Bar.qml.
//
// Uso em Bar.qml (substituir os dois VolumePopup anteriores):
//
//   VolumeModule.VolumePopupTabbed {
//     id: volPopup
//     anchor.window:  bar
//     anchor.edges:   bar.popupEdge
//     anchor.gravity: bar.popupEdge
//     anchor.rect:    bar.popupRectCentered(barRoot.themePanelWidth, barRoot.popupHVolume)
//     popupW: barRoot.themePanelWidth
//     popupH: barRoot.popupHVolume
//     panelOpen:  bar.sinkPanelOpen    // sink abre na aba de saída
//     openSource: bar.sourcePanelOpen  // source pula direto para aba mic
//     colorPanelBg:    bar.popupColorBg
//     colorText:       bar.popupColorText
//     colorTextDim:    bar.popupColorTextDim
//     colorAccent:     bar.popupColorAccent
//     colorProgressBg: bar.popupColorProgress
//     colorDivider:    bar.popupColorDivider
//     colorMuted:      bar.popupColorMuted
//     onCloseRequested: bar.closeAllPanels()
//   }

Bar.BarPopup {
  id: popup

  // panelOpen — herdado do BarPopup, controlado exclusivamente por Bar.qml.
  // Não redefinir aqui: o BarPopup usa panelOpen para disparar a animação.

  // openSource: quando true, ao abrir o popup pula para a aba Microfone.
  property bool openSource: false

  popupW: 300
  popupH: 420

  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorMuted:      "#cf6679"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  // Muda para a aba correta quando o popup abre ou openSource muda
  onPanelOpenChanged: {
    if (!panelOpen) return
    tabBar.currentIndex = openSource ? 1 : 0
  }
  onOpenSourceChanged: {
    tabBar.currentIndex = openSource ? 1 : 0
  }

  // ── Conteúdo ──────────────────────────────────────────────────────────────
  Item {
    anchors.fill: parent

    // ── Tab switcher — pill flutuante, minimalista ─────────────────────────
    Item {
      id: tabBar
      anchors {
        top:              parent.top
        horizontalCenter: parent.horizontalCenter
      }
      width:  160
      height: 36

      property int currentIndex: 0

      // Pill de fundo — track neutro bem sutil
      Rectangle {
        anchors.fill: parent
        radius:       18
        color:        Qt.rgba(popup.colorText.r, popup.colorText.g,
                              popup.colorText.b, 0.05)
      }

      // Pill deslizante ativo
      Rectangle {
        id: activePill
        y:      4
        x:      tabBar.currentIndex === 0 ? 4 : tabBar.width / 2
        width:  tabBar.width / 2 - 4
        height: tabBar.height - 8
        radius: 14
        color:  Qt.rgba(popup.colorAccent.r, popup.colorAccent.g,
                        popup.colorAccent.b, 0.15)

        Behavior on x { NumberAnimation { duration: 220; easing.type: Easing.InOutCubic } }

        // Borda fina accent no pill ativo
        Rectangle {
          anchors.fill: parent
          radius:       parent.radius
          color:        "transparent"
          border.color: Qt.rgba(popup.colorAccent.r, popup.colorAccent.g,
                                popup.colorAccent.b, 0.35)
          border.width: 1
        }
      }

      // Botões das abas
      Row {
        anchors.fill: parent

        Repeater {
          model: [
            { label: "Saída",      icon: "󰕾" },
            { label: "Microfone",  icon: "󰍬" }
          ]

          delegate: Item {
            id: tab
            required property var modelData
            required property int index

            width:  tabBar.width / 2
            height: tabBar.height

            Row {
              anchors.centerIn: parent
              spacing: 5

              Text {
                text:           tab.modelData.icon
                font.pixelSize: 13
                font.family:    "JetBrainsMono Nerd Font"
                color:          tabBar.currentIndex === tab.index
                                ? popup.colorAccent
                                : Qt.rgba(popup.colorTextDim.r,
                                          popup.colorTextDim.g,
                                          popup.colorTextDim.b, 0.55)
                Behavior on color    { ColorAnimation { duration: 180 } }
                Behavior on opacity  { NumberAnimation { duration: 180 } }
              }

              Text {
                text:           tab.modelData.label
                font.pixelSize: 11
                font.weight:    tabBar.currentIndex === tab.index
                                ? Font.Medium : Font.Normal
                color:          tabBar.currentIndex === tab.index
                                ? popup.colorAccent
                                : Qt.rgba(popup.colorTextDim.r,
                                          popup.colorTextDim.g,
                                          popup.colorTextDim.b, 0.55)
                Behavior on color { ColorAnimation { duration: 180 } }
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape:  Qt.PointingHandCursor
              onClicked:    tabBar.currentIndex = tab.index
            }
          }
        }
      }
    }

    // Divisor finíssimo abaixo do switcher
    Rectangle {
      anchors {
        top:   tabBar.bottom
        topMargin:    10
        left:  parent.left
        right: parent.right
        leftMargin:  16
        rightMargin: 16
      }
      height:  1
      color:   Qt.rgba(popup.colorDivider.r,
                       popup.colorDivider.g,
                       popup.colorDivider.b, 0.25)
    }

    // ── Stack de conteúdo ──────────────────────────────────────────────────
    Item {
      anchors {
        top:    tabBar.bottom
        topMargin:  12
        left:   parent.left
        right:  parent.right
        bottom: parent.bottom
      }

      VolumeContent {
        id: sinkContent
        anchors.fill:   parent
        showOnlySink:   true
        showOnlySource: false
        opacity:        tabBar.currentIndex === 0 ? 1.0 : 0.0
        visible:        opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

        colorPanelBg:    popup.colorPanelBg
        colorText:       popup.colorText
        colorTextDim:    popup.colorTextDim
        colorAccent:     popup.colorAccent
        colorMuted:      popup.colorMuted
        colorProgressBg: popup.colorProgressBg
        colorDivider:    popup.colorDivider
        onCloseRequested: popup.closeRequested()
      }

      VolumeContent {
        id: sourceContent
        anchors.fill:   parent
        showOnlySink:   false
        showOnlySource: true
        opacity:        tabBar.currentIndex === 1 ? 1.0 : 0.0
        visible:        opacity > 0
        Behavior on opacity { NumberAnimation { duration: 160; easing.type: Easing.InOutQuad } }

        colorPanelBg:    popup.colorPanelBg
        colorText:       popup.colorText
        colorTextDim:    popup.colorTextDim
        colorAccent:     popup.colorAccent
        colorMuted:      popup.colorMuted
        colorProgressBg: popup.colorProgressBg
        colorDivider:    popup.colorDivider
        onCloseRequested: popup.closeRequested()
      }
    }
  }
}
