import QtQuick
import QtQuick.Layouts
import "root:/"

Item {
  id: root

  property var  entry:     ({})
  property bool isFocused: false
  // true quando esta é a entrada aguardando um segundo Enter/clique pra
  // confirmar (ações destrutivas com entry.confirm === true)
  property bool pending:   false

  // "card" (padrão — retângulo com ícone+label+keybind) · "compact"
  // (círculo só com o ícone, usado pelo menuStyle "compact")
  property string variant: "card"

  // PowerMenuConfig — opcional. Sem config, cai nos defaults hardcoded
  // de sempre (Colors.* direto), então o componente nunca quebra mesmo
  // se for usado fora do fluxo normal do PowerMenu.qml.
  property var config: null

  signal clicked()
  signal hovered()

  function _c(key, fallback) {
    return root.config ? root.config.getColor(key) : fallback
  }
  function _g(key, fallback) {
    return root.config ? root.config.get(key, fallback) : fallback
  }

  readonly property color _cAccent:        _c("colorAccent",       Colors.primary)
  readonly property color _cCardBg:        _c("colorCardBg",       Colors.surface_container)
  readonly property color _cCardBgFocused: _c("colorCardBgFocused",Colors.primary_container)
  readonly property color _cBorder:        _c("colorBorder",       Colors.outline_variant)
  readonly property color _cIcon:          _c("colorIcon",         Colors.on_surface_variant)
  readonly property color _cLabel:         _c("colorLabel",        Colors.on_surface_variant)
  readonly property color _cLabelFocused:  _c("colorLabelFocused", Colors.on_primary_container)
  readonly property color _cKeybindBg:     _c("colorKeybindBg",    Colors.surface_container_highest)
  readonly property color _cDanger:        _c("colorDanger",       Colors.error)

  readonly property int _animMs:     _g("hoverAnimMs", 160)
  readonly property real _focusScale:_g("focusScale",  1.06)
  readonly property int _iconSize:   _g("iconSize",    42)

  // Card fica "quente" (vermelho) quando é destrutivo e está em foco/pending
  readonly property bool _hot: pending || (isFocused && entry.danger === true)

  readonly property bool _compact: root.variant === "compact"

  // Tamanho-alvo do botão. Guardado numa property própria (não direto em
  // `width`/`height`) e replicado em Layout.preferredWidth/Height — quando
  // este item vive dentro de um GridLayout/RowLayout/ColumnLayout (como no
  // PowerMenuPanel), o Layout SEMPRE sobrescreve `width`/`height` fixados
  // direto na property; ele só respeita o tamanho pedido via as properties
  // anexadas Layout.preferredWidth/Layout.preferredHeight. Sem isso, os
  // sliders de "Largura"/"Altura" do card na aba de config não tinham
  // nenhum efeito visual — o layout sempre esmagava o valor de volta.
  readonly property int _targetW: root._compact ? root._g("compactDiameter", 64) : root._g("cardWidth",  160)
  readonly property int _targetH: root._compact ? root._g("compactDiameter", 64) : root._g("cardHeight", 180)

  width:  root._targetW
  height: root._targetH
  Layout.preferredWidth:  root._targetW
  Layout.preferredHeight: root._targetH

  // ── Scale no hover/foco ───────────────────────────────────────────────────
  scale: isFocused ? root._focusScale : 1.0
  Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }

  // Raio efetivo — vira metade da dimensão (círculo perfeito) no compact
  readonly property int _radius: root._compact ? Math.round(root._targetW / 2) : root._g("cardRadius", 20)

  // ── Glow externo ─────────────────────────────────────────────────────────
  Rectangle {
    anchors.centerIn: parent
    width:   parent.width  + 18
    height:  parent.height + 18
    radius:  root._compact ? width / 2 : root._radius + 6
    color:   "transparent"
    border.color: root._hot ? root._cDanger : root._cAccent
    border.width: 1
    opacity: isFocused ? (root._hot ? 0.42 : 0.30) : 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    Behavior on border.color { ColorAnimation { duration: root._animMs } }
  }

  // ── Card ─────────────────────────────────────────────────────────────────
  Rectangle {
    id: card
    anchors.fill: parent
    radius:       root._radius

    color: root._hot
      ? Qt.rgba(root._cDanger.r, root._cDanger.g, root._cDanger.b, isFocused ? 0.24 : 0.10)
      : (isFocused
        ? Qt.rgba(root._cCardBgFocused.r, root._cCardBgFocused.g, root._cCardBgFocused.b, 0.22)
        : Qt.rgba(root._cCardBg.r,        root._cCardBg.g,        root._cCardBg.b,        0.90))

    border.color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cBorder)
    border.width: root._hot && isFocused ? 1.5 : 1

    Behavior on color        { ColorAnimation { duration: root._animMs } }
    Behavior on border.color { ColorAnimation { duration: root._animMs } }

    // Linha de acento no topo do card — só no estilo "card" (num círculo
    // não tem "topo reto" pra grudar uma linha decorativa)
    Rectangle {
      visible: !root._compact
      anchors.top:              parent.top
      anchors.horizontalCenter: parent.horizontalCenter
      width:   isFocused ? 56 : 0
      height:  2
      radius:  1
      color:   root._hot ? root._cDanger : root._cAccent
      Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
      Behavior on color { ColorAnimation { duration: root._animMs } }
    }
  }

  // Config de exibição — a badge de atalho pode ser desligada globalmente;
  // labels não fazem sentido no variant "compact" (círculo pequeno demais).
  readonly property bool _showLabels:   !root._compact && root._g("showLabels", true)
  readonly property bool _showKeybind:  root._g("showKeybindBadge", true)

  // ── Conteúdo — estilo "card" (ícone + label + keybind, empilhados) ────────
  ColumnLayout {
    visible: !root._compact
    anchors {
      fill:         parent
      topMargin:    26
      bottomMargin: 18
      leftMargin:   12
      rightMargin:  12
    }
    spacing: 8

    // Ícone — troca pra um alerta quando pending, com um "pulso" sutil
    Text {
      Layout.alignment: Qt.AlignHCenter
      text:  root.pending ? "\uf12a" : (entry.text ?? "?")
      color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cIcon)
      font { family: "JetBrainsMono Nerd Font"; pixelSize: root._iconSize }
      Behavior on color { ColorAnimation { duration: root._animMs } }

      SequentialAnimation on opacity {
        running: root.pending
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 420; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutQuad }
      }
    }

    // Divisor
    Rectangle {
      visible: root._showLabels
      Layout.alignment: Qt.AlignHCenter
      width:   isFocused ? 30 : 14
      height:  1
      color:   root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cBorder)
      opacity: 0.6
      Behavior on width { NumberAnimation { duration: 200 } }
      Behavior on color { ColorAnimation { duration: root._animMs } }
    }

    // Label — vira "CONFIRMAR?" durante o pending
    Text {
      visible: root._showLabels || root.pending
      Layout.alignment: Qt.AlignHCenter
      Layout.fillWidth: true
      text:  root.pending ? "CONFIRMAR?" : (entry.label ?? "").toUpperCase()
      color: root._hot ? root._cDanger : (isFocused ? root._cLabelFocused : root._cLabel)
      horizontalAlignment: Text.AlignHCenter
      font { family: "Fira Sans"; pixelSize: 11; letterSpacing: 2.5; bold: true }
      Behavior on color { ColorAnimation { duration: root._animMs } }
    }

    // Keybind badge — durante pending, dica pra repetir a tecla/Enter
    Rectangle {
      Layout.alignment: Qt.AlignHCenter
      visible: root.pending || (root._showKeybind && (entry.keybind ?? "") !== "")
      width:   kbLabel.implicitWidth + 14
      height:  kbLabel.implicitHeight + 6
      radius:  5
      color:   root._hot
        ? Qt.rgba(root._cDanger.r, root._cDanger.g, root._cDanger.b, 0.18)
        : (isFocused
          ? Qt.rgba(root._cAccent.r, root._cAccent.g, root._cAccent.b, 0.18)
          : root._cKeybindBg)
      border.color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cBorder)
      border.width: 1
      Behavior on color        { ColorAnimation { duration: root._animMs } }
      Behavior on border.color { ColorAnimation { duration: root._animMs } }

      Text {
        id: kbLabel
        anchors.centerIn: parent
        text:  root.pending ? "ENTER" : (entry.keybind ?? "").toUpperCase()
        color: root._hot ? root._cDanger : (isFocused ? root._cAccent : Colors.outline)
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true }
        Behavior on color { ColorAnimation { duration: root._animMs } }
      }
    }
  }

  // ── Conteúdo — estilo "compact" (só o ícone centralizado no círculo,
  // com um badge de atalho pequeno colado no canto inferior direito) ────────
  Item {
    visible: root._compact
    anchors.fill: parent

    Text {
      anchors.centerIn: parent
      text:  root.pending ? "\uf12a" : (entry.text ?? "?")
      color: root._hot ? root._cDanger : (isFocused ? root._cAccent : root._cIcon)
      font { family: "JetBrainsMono Nerd Font"; pixelSize: Math.round(root._iconSize * 0.72) }
      Behavior on color { ColorAnimation { duration: root._animMs } }

      SequentialAnimation on opacity {
        running: root.pending && root._compact
        loops: Animation.Infinite
        NumberAnimation { to: 0.4; duration: 420; easing.type: Easing.InOutQuad }
        NumberAnimation { to: 1.0; duration: 420; easing.type: Easing.InOutQuad }
      }
    }

    Rectangle {
      visible: root._showKeybind && (entry.keybind ?? "") !== ""
      anchors.right:  parent.right
      anchors.bottom: parent.bottom
      anchors.rightMargin:  -2
      anchors.bottomMargin: -2
      width:  compactKb.implicitWidth + 10
      height: compactKb.implicitHeight + 4
      radius: height / 2
      color:  root._cKeybindBg
      border.color: root._cBorder
      border.width: 1

      Text {
        id: compactKb
        anchors.centerIn: parent
        text:  (entry.keybind ?? "").toUpperCase()
        color: Colors.outline
        font { family: "JetBrainsMono Nerd Font"; pixelSize: 8; bold: true }
      }
    }
  }

  // ── Mouse ─────────────────────────────────────────────────────────────────
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape:  Qt.PointingHandCursor
    onEntered:    root.hovered()
    onClicked:    root.clicked()
  }
}
