import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "." as Comp

// ════════════════════════════════════════════════════════════════════════
// FOCUS — estilo de workspace ("mais completo") pedido para a Dock.
//
// Comportamento:
//   • Workspace ATIVA  → sempre expandida, mostra só os ícones (sem
//     número), reaproveitando o componente Icons.qml.
//   • Workspace INATIVA → colapsada, mostra só o número. Ao passar o
//     mouse, os ícones deslizam pra fora do lado do número, EMPURRANDO
//     as workspaces vizinhas de verdade (reflow real do RowLayout da
//     barra) — ela ocupa seu próprio espaço, não flutua por cima de
//     nada.
//
// ── Notas anti-tremor (leia antes de mexer no reveal) ─────────────────
// 1) UMA SÓ fonte de animação: só `revealClip.width` tem `Behavior`.
//    `implicitWidth` do root é um BIND DIRETO sobre esse valor (não tem
//    seu próprio Behavior). Animar duas coisas em cadeia (o filho E o
//    pai) cria uma pequena defasagem entre as duas animações — isso é
//    literalmente o que causa a sensação de tremor/dessincronia quadro
//    a quadro. Se for tocar nessa animação, mantenha essa regra: uma
//    única Behavior, todo o resto é bind puro.
// 2) SEM `anchors.centerIn` em nada que muda de tamanho durante o
//    reveal. Centralizar um item cujo tamanho está animando faz o
//    conteúdo dele deslizar horizontalmente ENQUANTO o container também
//    cresce — dois movimentos simultâneos e ligeiramente fora de fase.
//    Tudo aqui é ancorado por uma borda fixa (left→right em cadeia).
// 3) O Loader dos ícones é `active: true` fixo, nunca recriado — só a
//    largura do clip que o envolve anima. Reconstruir o ícone a cada
//    hover custaria o lookup de ícone de novo e causaria um "pulo".
// ════════════════════════════════════════════════════════════════════════

Item {
  id: root

  property var modelData: null

  property bool   isHorizontal: true
  property int    barPosition:  2
  property bool   showTooltip:  true

  // ── Ícones (workspace ativa, ou reveal em hover) ─────────────────────
  property int    iconSize:        18
  property bool   monochrome:      false
  property color  monoColor:       "white"
  property color  monoColorActive: "red"
  property int    iconSpacing:     3
  property string sortOrder:       "position"

  // ── Número (workspace inativa, colapsada) ────────────────────────────
  property int    fontSize:            10
  property color  numberColor:         "white"
  property color  numberColorActive:   "red"
  property bool   numberBgEnabled:     false
  property color  numberBgColor:       "transparent"
  property color  numberBgColorActive: "transparent"
  property int    numberBgRadius:      4
  property int    numberBgPaddingH:    4
  property int    numberBgPaddingV:    2
  property color  urgentColor:         "#f38ba8"

  // ── Fundo por trás dos ícones revelados (só visual, opcional) ────────
  property color  revealBgColor:  "transparent"
  property int    revealBgRadius: 6
  property int    revealPaddingH: 4
  property int    revealPaddingV: 2
  property int    revealGap:      4   // espaço entre número e ícones

  // Duração/curva da ÚNICA animação de reveal — ver nota (1) acima.
  // InOutCubic em vez de OutCubic: OutCubic começa no pico de velocidade
  // instantaneamente, e essa partida abrupta é percebida como um
  // "solavanco" logo no primeiro quadro — InOutCubic acelera e desacelera
  // suavemente nas duas pontas, sem início brusco.
  property int    revealDurationMs: 240
  readonly property int _revealEasing: Easing.InOutCubic

  readonly property bool _wsActive:   modelData ? modelData.active : false
  readonly property bool _wsUrgent:   modelData ? modelData.urgent : false
  readonly property bool _wsOccupied: modelData ? (modelData.toplevels && modelData.toplevels.values.length > 0) : false

  readonly property real _numberMinSize: Math.max(16, root.fontSize * 2.0)

  // Expandida = workspace ativa (sempre) OU inativa com o mouse em cima
  readonly property bool expanded: root._wsActive || hoverArea.containsMouse

  // Número não reserva espaço nenhum quando a workspace está ativa (ela
  // não mostra número, só ícones — igual ao comportamento original).
  readonly property real _numberContribution: root._wsActive ? 0 : (root.isHorizontal ? numberBadgeHost.width : numberBadgeHost.height)
  // Espelha revealClip.width/height num único nome, pra não repetir o
  // ternário isHorizontal em implicitWidth/Height abaixo.
  readonly property real _revealContribution: root.isHorizontal ? revealClip.width : revealClip.height

  // ── Tamanho reportado ao layout pai — bind direto, ver nota (1) ──────
  // Cresce de verdade (empurra os vizinhos no RowLayout da barra), sem
  // Behavior própria: a suavidade vem inteira de `revealClip.width`.
  implicitWidth: root.isHorizontal
    ? root._numberContribution + (root._revealContribution > 0 ? root.revealGap : 0) + root._revealContribution
    : Math.max(numberBadge.implicitWidth, revealClip.implicitWidth)
  implicitHeight: root.isHorizontal
    ? Math.max(numberBadge.implicitHeight, revealClip.implicitHeight)
    : root._numberContribution + (root._revealContribution > 0 ? root.revealGap : 0) + root._revealContribution

  // ── Área de hover/clique ──────────────────────────────────────────────
  // anchors.fill: parent aqui é seguro (não causa flicker) porque agora
  // `parent` (root) cresce de verdade em sincronia com o conteúdo — não
  // existe mais um hit-box de tamanho diferente do visual.
  MouseArea {
    id: hoverArea
    anchors.fill: parent
    z: -1
    hoverEnabled: !root._wsActive
    onEntered: if (root.showTooltip && !root._wsActive) WsTooltip.show(root, root.modelData, root.barPosition)
    onExited:  WsTooltip.hide()
    onClicked: if (!root._wsActive && root.modelData) root.modelData.activate()
  }

  // ── Número ────────────────────────────────────────────────────────────
  // Toda a Behavior daqui usa a MESMA duração/curva do reveal
  // (revealDurationMs / _revealEasing) — antes o número tinha os seus
  // próprios tempos (150ms InOutQuad / 220ms OutBack com overshoot),
  // dessincronizados do resto: cada parte da UI se movendo no seu
  // próprio ritmo, mesmo que sutil, é o que o olho lê como "tremor".
  // O overshoot (OutBack) também foi removido — um elemento pequeno
  // (a pílula) crescendo além do alvo e voltando é literalmente um
  // solavanco, por mais sutil que seja.
  Item {
    id: numberBadgeHost
    visible: !root._wsActive
    anchors.left: root.isHorizontal ? parent.left : undefined
    anchors.top:  root.isHorizontal ? undefined   : parent.top
    anchors.verticalCenter:   root.isHorizontal ? parent.verticalCenter : undefined
    anchors.horizontalCenter: root.isHorizontal ? undefined : parent.horizontalCenter
    width:  numberBadge.implicitWidth  + 6
    height: numberBadge.implicitHeight + 6

    // Glow sutil atrás da pílula — só aparece quando ocupada/em hover,
    // dá profundidade sem depender de DropShadow/GraphicalEffects
    // (mais barato e não introduz nenhuma animação extra fora de sync).
    Rectangle {
      anchors.centerIn: parent
      width:  numberBadge.implicitWidth  + 6
      height: numberBadge.implicitHeight + 6
      radius: root.numberBgEnabled ? root.numberBgRadius + 3 : height / 2
      color:  "transparent"
      border.width: 1
      border.color: root._wsUrgent
        ? Qt.rgba(root.urgentColor.r, root.urgentColor.g, root.urgentColor.b, 0.35)
        : Qt.rgba(root.numberColorActive.r, root.numberColorActive.g, root.numberColorActive.b, root.expanded ? 0.3 : 0.0)

      Behavior on border.color { ColorAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }
    }

    Rectangle {
      id: numberBadge
      anchors.centerIn: parent
      implicitWidth:  Math.max(root._numberMinSize, numberLabel.implicitWidth  + root.numberBgPaddingH * 2)
      implicitHeight: Math.max(root._numberMinSize, numberLabel.implicitHeight + root.numberBgPaddingV * 2)
      width:  implicitWidth
      height: implicitHeight
      radius: root.numberBgEnabled ? root.numberBgRadius : height / 2
      color:  root.numberBgEnabled
        ? (root.expanded ? root.numberBgColorActive : root.numberBgColor)
        : "transparent"

      border.color: root._wsUrgent
        ? root.urgentColor
        : root.numberBgEnabled
          ? "transparent"
          : Qt.rgba(root.numberColor.r, root.numberColor.g, root.numberColor.b, root._wsOccupied ? 0.35 : 0.15)
      border.width: root._wsUrgent ? 1.5 : (root.numberBgEnabled ? 0 : 1)

      Behavior on color          { ColorAnimation  { duration: root.revealDurationMs; easing.type: root._revealEasing } }
      Behavior on border.color   { ColorAnimation  { duration: root.revealDurationMs; easing.type: root._revealEasing } }
      Behavior on implicitWidth  { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }
      Behavior on implicitHeight { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }

      // Falso "text-shadow": uma cópia do texto, 1px abaixo, mais escura
      // e translúcida — dá contraste/profundidade sem layer.effect (que
      // exigiria ShaderEffectSource e um import extra).
      Text {
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 1
        text:           numberLabel.text
        font:           numberLabel.font
        color:          Qt.rgba(0, 0, 0, 0.35)
        opacity:        numberLabel.opacity * 0.6
        visible:        !root.numberBgEnabled
      }

      Text {
        id: numberLabel
        anchors.centerIn: parent
        text:           root.modelData ? root.modelData.name : ""
        font.pixelSize: Math.max(9, root.fontSize)
        font.weight:    root._wsOccupied ? Font.DemiBold : Font.Medium
        // (sem letterSpacing: no Qt ele soma espaço também DEPOIS do
        // último caractere, deslocando o glifo dentro da própria caixa
        // de texto mesmo com anchors.centerIn — deixava o número fora
        // do centro do círculo)
        color:   root._wsUrgent        ? root.urgentColor
               : root.expanded         ? root.numberColorActive
               : root.numberBgEnabled  ? root.numberColor
               : Qt.rgba(root.numberColor.r, root.numberColor.g, root.numberColor.b, root._wsOccupied ? 0.9 : 0.55)
        opacity: root._wsUrgent ? 0.95 : 1.0

        Behavior on color   { ColorAnimation  { duration: root.revealDurationMs; easing.type: root._revealEasing } }
        Behavior on opacity { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }
      }
    }
  }

  // ── Reveal — ícones deslizando pra fora do lado do número ────────────
  // clip:true + width animando de 0 até a largura natural dos ícones É
  // o slide (não precisa de nenhum transform/x adicional). Ancorado por
  // borda fixa (nunca centerIn) — ver nota (2).
  Item {
    id: revealClip
    clip: true
    anchors.left: root.isHorizontal
      ? (root._wsActive ? parent.left : numberBadgeHost.right)
      : parent.left
    anchors.top: root.isHorizontal
      ? parent.top
      : (root._wsActive ? parent.top : numberBadgeHost.bottom)
    anchors.leftMargin: root.isHorizontal && !root._wsActive ? (root.expanded ? root.revealGap : 0) : 0
    anchors.topMargin:  !root.isHorizontal && !root._wsActive ? (root.expanded ? root.revealGap : 0) : 0

    readonly property int implicitWidth:  iconsLoader.implicitWidth  + root.revealPaddingH * 2
    readonly property int implicitHeight: iconsLoader.implicitHeight + root.revealPaddingV * 2

    width:  root.isHorizontal ? (root.expanded ? implicitWidth  : 0) : implicitWidth
    height: root.isHorizontal ? implicitHeight : (root.expanded ? implicitHeight : 0)

    // ÚNICA Behavior de todo o reveal — ver nota (1) no cabeçalho.
    Behavior on width  { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }
    Behavior on height { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }
    Behavior on anchors.leftMargin { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }
    Behavior on anchors.topMargin  { NumberAnimation { duration: root.revealDurationMs; easing.type: root._revealEasing } }

    Rectangle {
      anchors.fill: parent
      radius: root.revealBgRadius
      color:  root.revealBgColor
    }

    Loader {
      id: iconsLoader
      anchors.left: parent.left
      anchors.top:  parent.top
      anchors.leftMargin: root.revealPaddingH
      anchors.topMargin:  root.revealPaddingV
      active: true   // nunca recriado — ver nota (3)
      sourceComponent: iconsDelegateComp
    }
  }

  Component {
    id: iconsDelegateComp
    Comp.Icons {}
  }

  Binding { target: iconsLoader.item; property: "modelData";       value: root.modelData;       when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "isHorizontal";    value: root.isHorizontal;    when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "iconSize";        value: root.iconSize;        when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "monochrome";      value: root.monochrome;      when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "monoColor";       value: root.monoColor;       when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "monoColorActive"; value: root.monoColorActive; when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "iconSpacing";     value: root.iconSpacing;     when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "sortOrder";       value: root.sortOrder;       when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "barPosition";     value: root.barPosition;     when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "showTooltip";     value: false;                when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "showNumber";      value: false;                when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "urgentColor";     value: root.urgentColor;     when: iconsLoader.item !== null }
}
