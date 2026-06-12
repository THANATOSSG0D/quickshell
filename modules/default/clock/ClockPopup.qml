import Quickshell
import QtQuick
import "../bar" as Bar

// ── ClockPopup ────────────────────────────────────────────────────────────
// Popup do relógio e timer/pomodoro. Filho QML do PanelWindow da barra.
// Posicionamento via anchor.window/rect/edges definido em Bar.qml.
//
// clockContentRef expõe o ClockContent para que Clock.qml receba
// a injeção de `clockContent` feita em Bar.qml → onLoaded.

Bar.BarPopup {
  id: popup
  objectName: "ClockPopup"

  popupW: 280
  popupH: 480

  property color colorText:       "#e2e2e2"
  property color colorTextDim:    "#c6c6c6"
  property color colorAccent:     "#ffb4a9"
  property color colorProgressBg: "#474747"
  property color colorDivider:    "#474747"

  // Referência capturada por Bar.qml para injetar em Clock.qml
  readonly property var clockContentRef: content

  ClockContent {
    id: content
    anchors.fill:    parent
    colorPanelBg:    popup.colorPanelBg
    colorText:       popup.colorText
    colorTextDim:    popup.colorTextDim
    colorAccent:     popup.colorAccent
    colorProgressBg: popup.colorProgressBg
    colorDivider:    popup.colorDivider
    onCloseRequested: popup.closeRequested()
  }
}
