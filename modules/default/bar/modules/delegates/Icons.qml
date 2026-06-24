import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Qt5Compat.GraphicalEffects
import "IconLookup.js" as IconLookup

Item {
  id: root
  property var modelData: null

  readonly property string homeDir: Quickshell.env("HOME") || ("/home/" + Quickshell.env("USER"))

  property bool  isHorizontal:    true
  property int   iconSize:        18
  property bool  monochrome:      false
  property color monoColor:       "white"
  property color monoColorActive: "red"
  property real  monoOpacity:     0.95
  property int   iconSpacing:     3
  property string sortOrder:      "position"
  property string fallbackIcon:   ""
  property int    barPosition:    2
  property bool   showTooltip:    true

  // Número da workspace antes do primeiro ícone
  property bool  showNumber:  false
  property color urgentColor: "#f38ba8"

  // Cores do número — independentes das cores do ícone monocromático
  property color numberColor:       "white"
  property color numberColorActive: "red"

  // Fundo (quadrado/pílula) atrás do número — opcional, com raio e padding
  // ajustáveis, e cor diferente para workspace ativa/inativa.
  property bool  numberBgEnabled:     false
  property color numberBgColor:       "transparent"
  property color numberBgColorActive: "transparent"
  property int   numberBgRadius:      4
  property int   numberBgPaddingH:    4
  property int   numberBgPaddingV:    2

  readonly property bool _wsActive: root.modelData ? root.modelData.active : false
  readonly property bool _wsUrgent: root.modelData ? root.modelData.urgent : false

  implicitWidth:  isHorizontal ? layout.implicitWidth  : iconSize + 4
  implicitHeight: isHorizontal ? iconSize + 4          : layout.implicitHeight
  width:  implicitWidth
  height: implicitHeight

  // Hover no nível do workspace inteiro (não por ícone individual) — mesma
  // experiência de tooltip dos outros estilos (Dot/Number/Hybrid). Fica
  // atrás de tudo (z negativo) e não aceita clique, já que cada ícone já
  // tem sua própria MouseArea para focar a janela específica.
  MouseArea {
    anchors.fill: parent
    z: -1
    hoverEnabled: root.showTooltip
    acceptedButtons: Qt.NoButton
    onEntered: if (root.showTooltip) WsTooltip.show(root, root.modelData, root.barPosition)
    onExited:  WsTooltip.hide()
  }

  // Contador "bumpado" manualmente. Dois problemas precisam ser
  // corrigidos juntos:
  //
  // 1) HyprlandToplevel.lastIpcObject só atualiza quando o Quickshell
  //    busca o objeto de novo do Hyprland — não é automático a cada
  //    movimento de janela. Por isso é preciso chamar
  //    Hyprland.refreshToplevels() explicitamente (ver docs do Quickshell:
  //    "Many actions that will invalidate workspace state don't send
  //    events, so this function is available if required" — reorganização
  //    de tiling é justamente um desses casos sem evento dedicado).
  //
  // 2) Mesmo com lastIpcObject atualizado, sortedToplevels usa
  //    Array.sort() com callback JS — o QML não rastreia leituras de
  //    propriedade feitas dentro desse callback como dependência do
  //    binding. Por isso o _sortDirty é lido fora do sort, só para
  //    forçar a reavaliação do binding inteiro.
  property int _sortDirty: 0

  // Reage a QUALQUER evento bruto do Hyprland — filtrar por nome (ex:
  // só "movewindow"/"windowtitle") é frágil: o evento real para título
  // é "windowtitlev2" (com endereço), e reorganizações de tiling puro
  // (mover janela dentro do mesmo workspace sem mudar foco/monitor)
  // muitas vezes não emitem evento dedicado nenhum.
  Connections {
    target: Hyprland
    function onRawEvent(event) {
      Hyprland.refreshToplevels()
      root._sortDirty++
    }
  }

  // Rede de segurança: cobre os casos em que nem o evento bruto chega
  // (reorganização interna de tiling sem socket event). Custo baixo —
  // é só refreshToplevels() + comparação de array já em memória.
  Timer {
    interval: 800
    running:  root.visible
    repeat:   true
    onTriggered: {
      Hyprland.refreshToplevels()
      root._sortDirty++
    }
  }

  property var sortedToplevels: {
    /* dependência intencional p/ forçar reavaliação em eventos do Hyprland */
    var _dep = root._sortDirty
    if (!root.modelData) return []
    var list = root.modelData.toplevels.values.slice()
    if (sortOrder === "alphabetical") {
      list.sort(function(a, b) {
        var nameA = a.wayland ? a.wayland.appId : a.title
        var nameB = b.wayland ? b.wayland.appId : b.title
        return nameA.localeCompare(nameB)
      })
    } else {
      list.sort(function(a, b) {
        var ax = a.lastIpcObject ? (a.lastIpcObject.at ? a.lastIpcObject.at[0] : 0) : 0
        var bx = b.lastIpcObject ? (b.lastIpcObject.at ? b.lastIpcObject.at[0] : 0) : 0
        return ax - bx
      })
    }
    return list
  }

  GridLayout {
    id: layout
    anchors.centerIn: parent
    columns:       root.isHorizontal ? -1 : 1
    rows:          root.isHorizontal ? 1  : -1
    columnSpacing: root.isHorizontal ? root.iconSpacing : 0
    rowSpacing:    root.isHorizontal ? 0 : root.iconSpacing

    // ── Número da workspace — sempre antes do primeiro ícone ────────────
    // Quando "numberBgEnabled" está desligado o Rectangle fica transparente
    // e sem padding extra, então o número se comporta como um texto solto
    // (igual ao comportamento original). Ligado, ganha um fundo
    // quadrado/pílula (raio ajustável) com cor própria por estado.
    Rectangle {
      id: numberBadge
      visible:          root.showNumber
      Layout.alignment: Qt.AlignCenter
      radius:           root.numberBgEnabled ? root.numberBgRadius : 0
      color:            root.numberBgEnabled
                          ? (root._wsActive ? root.numberBgColorActive : root.numberBgColor)
                          : "transparent"
      implicitWidth:  numberLabel.implicitWidth  + (root.numberBgEnabled ? root.numberBgPaddingH * 2 : 0)
      implicitHeight: numberLabel.implicitHeight + (root.numberBgEnabled ? root.numberBgPaddingV * 2 : 0)

      Behavior on color { ColorAnimation { duration: 150 } }

      Text {
        id: numberLabel
        anchors.centerIn: parent
        text:           root.modelData ? root.modelData.name : ""
        font.pixelSize: Math.max(9, Math.round(root.iconSize * 0.55))
        font.weight:    Font.Medium
        color:            root._wsUrgent ? root.urgentColor
                         : root._wsActive ? root.numberColorActive
                         : root.numberColor
        opacity:          root._wsUrgent ? 0.95 : (root._wsActive ? 0.95 : 0.55)

        Behavior on color   { ColorAnimation  { duration: 150 } }
        Behavior on opacity { NumberAnimation { duration: 150 } }
      }
    }

    Repeater {
      model: root.sortedToplevels

      delegate: Item {
        id: appItem
        required property var modelData

        Layout.preferredWidth:  root.iconSize
        Layout.preferredHeight: root.iconSize

        // ── Lookup do DesktopEntry ─────────────────────────────────────────
        property var entry: {
          var _loaded = DesktopEntries.applications.values.length
          if (_loaded === 0) return null
          if (!modelData.wayland) return null
          return IconLookup.findDesktopEntry(modelData.wayland.appId, DesktopEntries)
        }

        property string iconName: IconLookup.resolveIconName(entry)

        readonly property var iconPaths: IconLookup.buildIconPaths(iconName, root.homeDir)

        property int  attempt:   0
        property bool exhausted: false

        readonly property string currentSource: {
          if (exhausted) return ""
          if (iconPaths.length === 0) return ""
          return iconPaths[Math.min(attempt, iconPaths.length - 1)]
        }

        onIconPathsChanged: {
          appItem.attempt   = 0
          appItem.exhausted = false
        }

        // ── Ícone colorido ───────────────────────────────────────────────
        Image {
          id: iconImg
          anchors.fill: parent
          fillMode: Image.PreserveAspectFit
          visible:  !root.monochrome
          // Ativo = opacidade total; inativo = 55% (mais sutil que o original 0.6)
          opacity:  modelData.activated ? 1.0 : 0.55
          source:   appItem.currentSource

          Behavior on opacity { NumberAnimation { duration: 150 } }

          onStatusChanged: {
            if (status === Image.Error) {
              if (appItem.attempt < appItem.iconPaths.length - 1) {
                appItem.attempt++
              } else {
                appItem.exhausted = true
              }
            }
          }
        }

        // ── Fallback genérico ────────────────────────────────────────────
        Image {
          id: fallbackImg
          anchors.fill: parent
          fillMode: Image.PreserveAspectFit
          visible:  !root.monochrome && appItem.exhausted && fallbackAttempt < fallbackPaths.length
          opacity:  modelData.activated ? 1.0 : 0.55

          property int fallbackAttempt: 0

          readonly property var fallbackPaths: {
            var fb = root.fallbackIcon
            if (!fb) return []
            if (fb.startsWith("/")) return ["file://" + fb]
            return [
              "file:///usr/share/icons/Papirus/48x48/apps/"    + fb + ".svg",
              "file:///usr/share/icons/Papirus/32x32/apps/"    + fb + ".svg",
              "file:///usr/share/icons/hicolor/48x48/apps/"    + fb + ".png",
              "file:///usr/share/icons/hicolor/48x48/apps/"    + fb + ".svg",
              "file:///usr/share/icons/hicolor/scalable/apps/" + fb + ".svg",
              "file:///usr/share/pixmaps/"                     + fb + ".png",
              "file:///usr/share/pixmaps/"                     + fb + ".svg",
            ]
          }

          source: fallbackPaths.length > 0
            ? fallbackPaths[Math.min(fallbackAttempt, fallbackPaths.length - 1)]
            : ""

          onStatusChanged: {
            if (status === Image.Error) {
              if (fallbackAttempt < fallbackPaths.length - 1)
                fallbackAttempt++
              else
                fallbackAttempt = fallbackPaths.length
            }
          }

          onFallbackPathsChanged: fallbackAttempt = 0
        }

        // ── Ícone monocromático ──────────────────────────────────────────
        Item {
          id: monoContainer
          anchors.fill: parent
          visible:  root.monochrome
          opacity:  modelData.activated ? root.monoOpacity : root.monoOpacity * 0.45

          Behavior on opacity { NumberAnimation { duration: 150 } }

          Image {
            id: iconImgMono
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: appItem.exhausted ? fallbackImg.source : iconImg.source

            layer.enabled: true
            layer.effect: BrightnessContrast {
              brightness: 0.4
              contrast:  -0.3
            }
          }

          layer.enabled: true
          layer.effect: Colorize {
            hue: modelData.activated
              ? root.monoColorActive.hslHue
              : root.monoColor.hslHue
            saturation: modelData.activated
              ? root.monoColorActive.hslSaturation * 0.55
              : root.monoColor.hslSaturation * 0.55
            lightness: 0.0
          }
        }

        // ── Indicador de janela ativa ────────────────────────────────────
        // Usa monoColorActive quando monocromo, senão branco — corrige hardcode original
        Rectangle {
          anchors.bottom:           root.isHorizontal ? parent.bottom : undefined
          anchors.right:            root.isHorizontal ? undefined     : parent.right
          anchors.horizontalCenter: root.isHorizontal ? parent.horizontalCenter : undefined
          anchors.verticalCenter:   root.isHorizontal ? undefined     : parent.verticalCenter
          width:   root.isHorizontal ? 4 : 3
          height:  root.isHorizontal ? 3 : 4
          radius:  2
          visible: modelData.activated
          color:   root.monochrome ? root.monoColorActive : "white"
          opacity: modelData.activated ? 0.85 : 0.0

          Behavior on opacity { NumberAnimation { duration: 150 } }
        }

        MouseArea {
          anchors.fill: parent
          onClicked: Hyprland.dispatch("hl.dsp.focus({ window = 'address:0x" + modelData.address + "'})")
        }
      }
    }
  }
}
