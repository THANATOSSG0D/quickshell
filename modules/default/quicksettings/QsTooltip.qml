pragma Singleton
import Quickshell
import QtQuick
import qs

// QsTooltip — singleton de tooltip rico para o módulo de QuickSettings.
//
// Mesma filosofia do MediaTooltip/BarTooltip (PopupWindow leve, anexado ao
// item da barra, aparece com delay no hover). Mostra um resumo de Wi-Fi,
// Ethernet, Bluetooth e Volume — sem precisar abrir o painel completo.
//
// API:
//   show(item, source, barPosition) → mostra após 500ms de hover
//   hide()                          → esconde com pequeno delay (evita piscar)
//
// "source" é o próprio QuickSettings.qml — lido diretamente, então o
// conteúdo do tooltip atualiza em tempo real (volume mudando, etc.) enquanto
// ele estiver visível.

Singleton {
  id: root

  property color bgColor:      Qt.rgba(0.05, 0.05, 0.05, 0.92)
  property color fgColor:      "#e2e2e2"
  property color fgDimColor:   Qt.rgba(1, 1, 1, 0.55)
  property color accentColor:  "#ffb4a9"
  property color mutedColor:   "#cf6679"

  property var _anchorItem: null
  property var _source:     null
  property int _barPos:     2

  // ── API ────────────────────────────────────────────────────────────────
  function show(item, source, barPosition) {
    if (!root._cfg(item, "Enabled", TooltipSettings.enabled)) return
    _anchorItem = item
    _source     = source
    _barPos     = barPosition
    hideTimer.stop()
    showTimer.restart()
  }

  function hide() {
    showTimer.stop()
    hideTimer.restart()
  }

  // ── Timers ─────────────────────────────────────────────────────────────
  Timer {
    id: showTimer
    interval: 500; repeat: false
    onTriggered: { if (root._anchorItem && root._source) popup.visible = true }
  }
  Timer {
    id: hideTimer
    interval: 150; repeat: false
    onTriggered: popup.visible = false
  }

  // ── Conveniências de leitura do source ──────────────────────────────────
  readonly property bool   _ready:        root._source ? root._source.tipDataReady    : false
  readonly property bool   _wifiOn:       root._source ? root._source.tipWifiEnabled  : false
  readonly property string _wifiSsid:     root._source ? root._source.tipWifiSsid     : ""
  readonly property bool   _ethOn:        root._source ? root._source.tipEthConnected : false
  readonly property string _ethDevice:    root._source ? root._source.tipEthDevice    : ""
  readonly property bool   _btOn:         root._source ? root._source.tipBtEnabled    : false
  readonly property real   _vol:          root._source ? root._source.vol             : 0
  readonly property bool   _muted:        root._source ? root._source.muted           : false

  readonly property string _outputDevice: root._source ? root._source.outputDeviceName : ""
  readonly property string _inputDevice:  root._source ? root._source.inputDeviceName  : ""

  readonly property string _powerProfile: root._source ? root._source.tipPowerProfile   : ""
  readonly property string _shaderName:   root._source ? root._source.tipShaderName   : ""
  readonly property string _shaderMode:   root._source ? root._source.tipShaderMode   : ""
  readonly property int    _temp:         root._source ? root._source.tipTemp         : 0
  readonly property int    _gamma:        root._source ? root._source.tipGamma        : 0

  readonly property string _shaderModeLabel: {
    if (_shaderMode === "auto") return "Automático"
    if (_shaderMode.startsWith("manual:")) return "Manual"
    // "off" não é mostrado aqui de propósito: se chegamos a este ponto com
    // um _shaderName preenchido, o shader está de fato ativo (hyprshade
    // current não mente), então um cache desatualizado dizendo "off" não
    // deve aparecer ao lado do nome — ver comentário na StatusRow do shader.
    return ""
  }

  readonly property string _weatherCondition: root._source ? root._source.tipWeatherCondition : ""
  readonly property string _weatherTemp:      root._source ? root._source.tipWeatherTemp      : ""

  readonly property string _weatherIcon: {
    var c = _weatherCondition.toLowerCase()
    if (c.indexOf("thunder") >= 0)                           return "\uf0e7"
    if (c.indexOf("snow") >= 0 || c.indexOf("sleet") >= 0)   return "\uf2dc"
    if (c.indexOf("rain") >= 0 || c.indexOf("drizzle") >= 0) return "\uf73d"
    if (c.indexOf("fog") >= 0 || c.indexOf("mist") >= 0)     return "\uf74e"
    if (c.indexOf("overcast") >= 0 || c.indexOf("cloud") >= 0) return "\uf0c2"
    return "\uf185"
  }

  // ── Linha genérica de status (component top-level, reaproveitado abaixo) ──
  component StatusRow: Row {
    property string icon: ""
    property string label: ""
    property bool   on: false
    spacing: 8
    Text {
      text: parent.icon
      color: parent.on ? root.accentColor : root.fgDimColor
      font.pixelSize: 11
      font.family: "JetBrainsMono Nerd Font"
      width: 16
    }
    Text {
      text: parent.label
      color: parent.on ? root.fgColor : root.fgDimColor
      font.pixelSize: 10
    }
  }

  // Resolve o item de ancoragem conforme TooltipSettings.align — ver
  // comentário completo em BarTooltip.qml.
  function _resolveAnchor() {
    if (!root._anchorItem) return root._anchorItem
    // "bar"     → sobe até o container raiz da barra inteira (objectName
    //             "barContentRoot", setado em Bar.qml — comum a todos os temas)
    // "section" → sobe até o container da seção do módulo hoverado
    //             (objectName "barSectionLeft/Center/Right/Top/Middle/Bottom",
    //             marcado em cada tema — ver comentário em TooltipSettings.qml)
    // "module"  → o próprio item hoverado (comportamento padrão, sem loop)
    if (root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "bar" && root._cfg(root._anchorItem, "Align", TooltipSettings.align) !== "section")
      return root._anchorItem
    var wantPrefix = root._cfg(root._anchorItem, "Align", TooltipSettings.align) === "bar" ? "barContentRoot" : "barSection"
    var it = root._anchorItem, guard = 0
    while (it && it.objectName.indexOf(wantPrefix) !== 0 && guard < 40) { it = it.parent; guard++ }
    return it || root._anchorItem
  }

  // Resolve a config de tooltip do PAINEL a que o item hoverado pertence
  // (bar ou dock — cada Loader "barContentRoot" expõe a própria config,
  // ver Bar.qml). Cai no default (TooltipSettings.*) se não achar nenhum
  // barContentRoot acima do item, ou se a propriedade não existir nele.
  function _cfg(startItem, key, dflt) {
    var it = startItem, guard = 0
    while (it && it.objectName !== "barContentRoot" && guard < 40) { it = it.parent; guard++ }
    var propName = "cfgTooltip" + key
    if (it && it[propName] !== undefined) return it[propName]
    return dflt
  }

  // ── PopupWindow ────────────────────────────────────────────────────────
  PopupWindow {
    id: popup
    visible: false
    color:   "transparent"

    readonly property int  _touchOffset: root._cfg(root._anchorItem, "Offset", TooltipSettings.offset)
    readonly property bool _barVertical: root._barPos === 2 || root._barPos === 4

    implicitWidth: TooltipSettings.resolveWidth(
      root._cfg(root._anchorItem, "WidthMode", TooltipSettings.widthMode),
      root._cfg(root._anchorItem, "FixedWidth", TooltipSettings.fixedWidth),
      root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth),
      content.implicitWidth + TooltipSettings.contentPadding
    ) + (_barVertical ? _touchOffset : 0)
    implicitHeight: content.implicitHeight + 18 + (_barVertical ? 0 : _touchOffset)

    anchor.item: root._resolveAnchor()
    anchor.edges: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.gravity: {
      switch (root._barPos) {
        case 1:  return Edges.Bottom
        case 3:  return Edges.Top
        case 4:  return Edges.Right
        default: return Edges.Left
      }
    }
    anchor.adjustment: PopupAdjustment.Flip | PopupAdjustment.Slide

    Rectangle {
      anchors.fill: parent
      anchors.leftMargin:   root._barPos === 4 ? popup._touchOffset : 0
      anchors.rightMargin:  (root._barPos !== 1 && root._barPos !== 3 && root._barPos !== 4) ? popup._touchOffset : 0
      anchors.topMargin:    root._barPos === 1 ? popup._touchOffset : 0
      anchors.bottomMargin: root._barPos === 3 ? popup._touchOffset : 0
      radius: 10
      color:  root.bgColor

      Column {
        id: content
        anchors.centerIn: parent
        spacing: 6
        // Muitas StatusRow diferentes aqui (SSID, dispositivo, shader,
        // clima...) — em vez de dar elide individual pra cada uma, o
        // clip garante que nada vaza pra fora da caixa já limitada pelo
        // teto de largura (maxWidth) lá em cima, mesmo se algum texto
        // pontual for mais longo que o esperado.
        clip: true

        // Agrupa tudo MENOS a linha de volume: dá uma referência de
        // largura "natural" estável pra barra de volume esticar até o
        // fim do tooltip. Antes a Rectangle do volume usava
        // content.implicitWidth diretamente — mas content inclui a
        // PRÓPRIA linha de volume, então era um binding loop
        // (width do volTrack → content.implicitWidth → largura da Row
        // de volume → width do volTrack outra vez). Isolando as outras
        // linhas aqui, a referência não depende mais de si mesma.
        Column {
          id: statusRows
          spacing: 6

          Text {
            visible: !root._ready
            text: "Carregando…"
            color: root.fgDimColor
            font.pixelSize: 10
          }

          StatusRow {
          visible: root._ready
          icon: "\uf1eb"
          label: root._wifiOn ? (root._wifiSsid || "ligado") : "Wi-Fi desligado"
          on: root._wifiOn
        }
        StatusRow {
          visible: root._ready
          icon: "\uf6ff"
          label: root._ethOn ? (root._ethDevice || "conectado") : "Ethernet desconectado"
          on: root._ethOn
        }
        StatusRow {
          visible: root._ready
          icon: "\uf294"
          label: root._btOn ? "Bluetooth ligado" : "Bluetooth desligado"
          on: root._btOn
        }

        // ── Dispositivos de áudio padrão ───────────────────────────────────
        StatusRow {
          visible: root._ready && root._outputDevice !== ""
          icon: "\uf2db"; on: true
          label: root._outputDevice
        }
        StatusRow {
          visible: root._ready && root._inputDevice !== ""
          icon: "\uf130"; on: true
          label: root._inputDevice
        }

        Rectangle {
          visible: root._ready
          width: parent.width; height: 1
          color: Qt.rgba(1, 1, 1, 0.08)
        }

        // ── Power profile ────────────────────────────────────────────────
        StatusRow {
          visible: root._ready && root._powerProfile !== ""
          icon: "\uf2db"; on: true
          label: root._powerProfile
        }

        // ── Shader + temperatura/gamma ──────────────────────────────────
        // hyprshade current é a fonte de verdade sobre o que está REALMENTE
        // rodando agora. O cache (~/.cache/hyprnight/shader-mode) só serve
        // para desambiguar "automático" vs "manual" quando já sabemos que
        // há um shader ativo — nunca para decidir se está desligado (o
        // cache pode ficar desatualizado se o shader foi ativado por outro
        // caminho, ex.: hyprshade.sh/rofi, que não escreve nesse arquivo).
        StatusRow {
          visible: root._ready && (root._shaderName !== "" || root._shaderMode === "off")
          icon: "\uf185"
          on: root._shaderName !== ""
          label: root._shaderName !== ""
            ? root._shaderName + (root._shaderModeLabel !== "" ? (" · " + root._shaderModeLabel) : "")
            : "Shader desligado"
        }
        StatusRow {
          visible: root._ready && root._temp > 0
          icon: "\uf042"; on: true
          label: root._temp + "K" + (root._gamma > 0 ? (" · gamma " + root._gamma + "%") : "")
        }

        // ── Clima ────────────────────────────────────────────────────────
        Row {
          visible: root._weatherTemp !== ""
          spacing: 8
          Text {
            text: root._weatherIcon
            color: root.accentColor
            font.pixelSize: 11
            font.family: "JetBrainsMono Nerd Font"
            width: 16
          }
          Text {
            text: root._weatherTemp + (root._weatherCondition !== "" ? (" · " + root._weatherCondition) : "")
            color: root.fgColor
            font.pixelSize: 10
          }
        }

        Rectangle {
          width: parent.width; height: 1
          color: Qt.rgba(1, 1, 1, 0.08)
        }
        } // fim statusRows

        // ── Volume (sempre por último, mesmo estilo do MediaTooltip) ───────
        Row {
          spacing: 5
          Text {
            id: volIcon
            text:           root._muted ? "\uf6a9" : "\uf028"
            color:          root.fgDimColor
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
          }
          Rectangle {
            id: volTrack
            // era `content.implicitWidth` — mas content é o PAI desta
            // própria Row de volume, então a largura do volTrack
            // influenciava content.implicitWidth, que influenciava de volta
            // a largura do volTrack (binding loop). Agora usa statusRows
            // (as linhas Wi-Fi/Eth/BT/dispositivos/shader/clima, que não
            // incluem a linha de volume), então a referência é estável.
            width:  Math.max(60, TooltipSettings.resolveWidth(
              root._cfg(root._anchorItem, "WidthMode", TooltipSettings.widthMode),
              root._cfg(root._anchorItem, "FixedWidth", TooltipSettings.fixedWidth) - TooltipSettings.contentPadding,
              root._cfg(root._anchorItem, "MaxWidth", TooltipSettings.maxWidth) - TooltipSettings.contentPadding,
              statusRows.implicitWidth
            ) - volIcon.implicitWidth - volPct.implicitWidth - parent.spacing * 2)
            height: 4; radius: 2
            color: Qt.rgba(1, 1, 1, 0.15)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
              width:  parent.width * Math.min(1.0, root._vol)
              height: parent.height
              radius: parent.radius
              color:  root._muted ? root.mutedColor : root.accentColor
              Behavior on width { NumberAnimation { duration: 120 } }
            }
          }
          Text {
            id: volPct
            text:           Math.round(root._vol * 100) + "%"
            color:          root.fgDimColor
            font.pixelSize: 9
            font.family:    "JetBrainsMono Nerd Font"
            anchors.verticalCenter: parent.verticalCenter
          }
        }
      }
    }
  }
}
