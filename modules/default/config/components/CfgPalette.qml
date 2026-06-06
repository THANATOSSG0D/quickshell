import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root

  required property string label
  required property string value
  required property var    colors
  required property var    overlay
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorSidebar
  required property color  colorDivider

  signal edited(string v)

  width:  parent ? parent.width : 0
  height: 30

  // ── Diagnóstico ───────────────────────────────────────────────────────
  Component.onCompleted: {
    console.log("[CfgPalette] onCompleted label='" + root.label + "'")
    console.log("[CfgPalette]   colors:", root.colors)
    console.log("[CfgPalette]   overlay:", root.overlay)
    if (root.colors) {
      console.log("[CfgPalette]   colors.primary:", root.colors.primary)
      console.log("[CfgPalette]   colors.background:", root.colors.background)
      console.log("[CfgPalette]   colors.error:", root.colors.error)
    } else {
      console.log("[CfgPalette]   !! colors é null/undefined !!")
    }
  }

  // Mapa explícito — bracket notation não funciona em QtObject/Singleton
  readonly property var colorMap: ({
    "background":                root.colors ? root.colors.background                : "#888",
    "error":                     root.colors ? root.colors.error                     : "#888",
    "error_container":           root.colors ? root.colors.error_container           : "#888",
    "inverse_on_surface":        root.colors ? root.colors.inverse_on_surface        : "#888",
    "inverse_primary":           root.colors ? root.colors.inverse_primary           : "#888",
    "inverse_surface":           root.colors ? root.colors.inverse_surface           : "#888",
    "on_background":             root.colors ? root.colors.on_background             : "#888",
    "on_error":                  root.colors ? root.colors.on_error                  : "#888",
    "on_error_container":        root.colors ? root.colors.on_error_container        : "#888",
    "on_primary":                root.colors ? root.colors.on_primary                : "#888",
    "on_primary_container":      root.colors ? root.colors.on_primary_container      : "#888",
    "on_primary_fixed":          root.colors ? root.colors.on_primary_fixed          : "#888",
    "on_primary_fixed_variant":  root.colors ? root.colors.on_primary_fixed_variant  : "#888",
    "on_secondary":              root.colors ? root.colors.on_secondary              : "#888",
    "on_secondary_container":    root.colors ? root.colors.on_secondary_container    : "#888",
    "on_secondary_fixed":        root.colors ? root.colors.on_secondary_fixed        : "#888",
    "on_secondary_fixed_variant":root.colors ? root.colors.on_secondary_fixed_variant: "#888",
    "on_surface":                root.colors ? root.colors.on_surface                : "#888",
    "on_surface_variant":        root.colors ? root.colors.on_surface_variant        : "#888",
    "on_tertiary":               root.colors ? root.colors.on_tertiary               : "#888",
    "on_tertiary_container":     root.colors ? root.colors.on_tertiary_container     : "#888",
    "on_tertiary_fixed":         root.colors ? root.colors.on_tertiary_fixed         : "#888",
    "on_tertiary_fixed_variant": root.colors ? root.colors.on_tertiary_fixed_variant : "#888",
    "outline":                   root.colors ? root.colors.outline                   : "#888",
    "outline_variant":           root.colors ? root.colors.outline_variant           : "#888",
    "primary":                   root.colors ? root.colors.primary                   : "#888",
    "primary_container":         root.colors ? root.colors.primary_container         : "#888",
    "primary_fixed":             root.colors ? root.colors.primary_fixed             : "#888",
    "primary_fixed_dim":         root.colors ? root.colors.primary_fixed_dim         : "#888",
    "scrim":                     root.colors ? root.colors.scrim                     : "#888",
    "secondary":                 root.colors ? root.colors.secondary                 : "#888",
    "secondary_container":       root.colors ? root.colors.secondary_container       : "#888",
    "secondary_fixed":           root.colors ? root.colors.secondary_fixed           : "#888",
    "secondary_fixed_dim":       root.colors ? root.colors.secondary_fixed_dim       : "#888",
    "shadow":                    root.colors ? root.colors.shadow                    : "#888",
    "source_color":              root.colors ? root.colors.source_color              : "#888",
    "surface":                   root.colors ? root.colors.surface                   : "#888",
    "surface_bright":            root.colors ? root.colors.surface_bright            : "#888",
    "surface_container":         root.colors ? root.colors.surface_container         : "#888",
    "surface_container_high":    root.colors ? root.colors.surface_container_high    : "#888",
    "surface_container_highest": root.colors ? root.colors.surface_container_highest : "#888",
    "surface_container_low":     root.colors ? root.colors.surface_container_low     : "#888",
    "surface_container_lowest":  root.colors ? root.colors.surface_container_lowest  : "#888",
    "surface_dim":               root.colors ? root.colors.surface_dim               : "#888",
    "surface_tint":              root.colors ? root.colors.surface_tint              : "#888",
    "surface_variant":           root.colors ? root.colors.surface_variant           : "#888",
    "tertiary":                  root.colors ? root.colors.tertiary                  : "#888",
    "tertiary_container":        root.colors ? root.colors.tertiary_container        : "#888",
    "tertiary_fixed":            root.colors ? root.colors.tertiary_fixed            : "#888",
    "tertiary_fixed_dim":        root.colors ? root.colors.tertiary_fixed_dim        : "#888",
  })

  readonly property var paletteKeys: [
    "background","error","error_container","inverse_on_surface","inverse_primary",
    "inverse_surface","on_background","on_error","on_error_container","on_primary",
    "on_primary_container","on_primary_fixed","on_primary_fixed_variant","on_secondary",
    "on_secondary_container","on_secondary_fixed","on_secondary_fixed_variant",
    "on_surface","on_surface_variant","on_tertiary","on_tertiary_container",
    "on_tertiary_fixed","on_tertiary_fixed_variant","outline","outline_variant",
    "primary","primary_container","primary_fixed","primary_fixed_dim","scrim",
    "secondary","secondary_container","secondary_fixed","secondary_fixed_dim",
    "shadow","source_color","surface","surface_bright","surface_container",
    "surface_container_high","surface_container_highest","surface_container_low",
    "surface_container_lowest","surface_dim","surface_tint","surface_variant",
    "tertiary","tertiary_container","tertiary_fixed","tertiary_fixed_dim"
  ]

  function resolveColor(key) {
    var c = root.colorMap[key]
    if (c === undefined || c === null) return "#888888"
    return c
  }

  property bool _open: false

  // Recalcula posição do popup usando mapToGlobal → mapFromGlobal
  // para cruzar a fronteira do Loader/layer corretamente
  function _placePopup() {
    if (!root.overlay || !root._open) return
    // Ponto bottom-left da box em coordenadas globais (da tela)
    var globalPt = box.mapToGlobal(0, box.height + 4)
    // Converte para coordenadas locais do overlay
    var localPt  = root.overlay.mapFromGlobal(globalPt.x, globalPt.y)
    popup.x = localPt.x
    popup.y = localPt.y
    // Garante que não sai pela direita da janela
    var maxX = root.overlay.width - popup.width - 4
    if (popup.x > maxX) popup.x = maxX
    console.log("[CfgPalette '" + root.label + "'] popup pos:",
      popup.x, popup.y,
      "| globalPt:", globalPt.x, globalPt.y,
      "| overlay size:", root.overlay.width, "x", root.overlay.height)
  }

  on_OpenChanged: {
    if (_open) {
      popup.parent = root.overlay
      Qt.callLater(_placePopup)
    } else {
      popup.parent = root
    }
  }

  onVisibleChanged: { if (!visible) _open = false }

  // ── Label ─────────────────────────────────────────────────────────────
  Text {
    anchors.verticalCenter: parent.verticalCenter
    text:           root.label
    color:          root.colorTextDim
    font.pixelSize: 10
    width:          110
  }

  // ── Box ───────────────────────────────────────────────────────────────
  Rectangle {
    id: box
    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
    width:  230
    height: 26
    radius: 5
    color:  root._open
      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.1)
      : Qt.rgba(1,1,1,0.06)
    border.color: root._open
      ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.75)
      : Qt.rgba(1,1,1,0.14)
    border.width: 1
    Behavior on color        { ColorAnimation { duration: 80 } }
    Behavior on border.color { ColorAnimation { duration: 80 } }

    Row {
      anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
      spacing: 6

      // Preview da cor selecionada
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 14; height: 14; radius: 3
        color:        root.resolveColor(root.value)
        border.color: Qt.rgba(1,1,1,0.25)
        border.width: 1
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width:          box.width - 56
        text:           root.value
        color:          root.colorText
        font.pixelSize: 10
        font.family:    "JetBrainsMono Nerd Font"
        elide:          Text.ElideRight
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        text:           root._open ? "\uf0d8" : "\uf0d7"
        color:          root.colorTextDim
        font.pixelSize: 9
        font.family:    "JetBrainsMono Nerd Font"
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root._open = !root._open
    }
  }

  // ── Popup — reparentado para overlay ao abrir ─────────────────────────
  Rectangle {
    id: popup
    parent:  root
    visible: root._open
    width:   230
    height:  260
    radius:  7
    z:       999
    color:   root.colorSidebar
    border.color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.8)
    border.width: 1
    clip:    true

    // Fecha ao clicar fora — MouseArea separado no overlay, atrás do popup
    MouseArea {
      parent:  popup.parent   // mesmo pai do popup (o overlay)
      x: -10000; y: -10000
      width:  20000; height: 20000
      z:      popup.z - 1     // atrás do popup, na frente do resto
      enabled: root._open
      onClicked: root._open = false
    }

    // Lista com scroll real
    ListView {
      id: listView
      anchors { fill: parent; margins: 5 }
      spacing: 1
      clip:    true
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar {
        policy: listView.contentHeight > listView.height
          ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff
      }

      model: root.paletteKeys

      delegate: Rectangle {
        required property string modelData
        required property int    index

        readonly property bool  isActive:     root.value === modelData
        readonly property color previewColor: root.resolveColor(modelData)

        width:  listView.width - (listView.contentHeight > listView.height ? 8 : 0)
        height: 26
        radius: 4
        color:  isActive
          ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.2)
          : (rHov.containsMouse ? Qt.rgba(1,1,1,0.07) : "transparent")
        Behavior on color { ColorAnimation { duration: 50 } }

        Row {
          anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
          spacing: 6

          Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 12; height: 12; radius: 3
            color:        previewColor
            border.color: Qt.rgba(1,1,1,0.2)
            border.width: 1
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            width:          parent.width - 82
            text:           modelData
            color:          isActive ? root.colorAccent : root.colorText
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            elide:          Text.ElideRight
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            text:           previewColor.toString().toUpperCase().substring(0, 7)
            color:          root.colorTextDim
            font.pixelSize: 8
            font.family:    "JetBrainsMono Nerd Font"
          }
        }

        MouseArea {
          id: rHov
          anchors.fill: parent
          hoverEnabled: true
          onClicked: { root.edited(modelData); root._open = false }
        }
      }
    }
  }
}
