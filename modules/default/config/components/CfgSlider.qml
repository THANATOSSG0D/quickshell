import QtQuick
import QtQuick.Layouts

RowLayout {
  id: root

  required property string label
  required property real   value
  required property real   from
  required property real   to
  required property real   step
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg

  property string unit: ""

  signal moved(real v)

  width:   parent ? parent.width : 0
  spacing: 10

  // ── Casas decimais derivadas do step ────────────────────────────────────
  // ANTES: o texto sempre usava Math.round(value), então sliders com
  // step decimal (ex: opacidade, step:0.05) mostravam só o inteiro —
  // impossível ver/ajustar com precisão. Além disso, o MouseArea fazia
  // Math.round(raw / step) * step sem corrigir erro de ponto flutuante
  // do JS, gerando valores como 0.30000000000000004 (visíveis nos logs).
  //
  // AGORA: a quantidade de casas decimais é derivada do próprio step
  // (0.05 → 2 casas; 1 → 0 casas) e usada tanto para exibir quanto para
  // arredondar o valor após o snap, eliminando o ruído de float.
  readonly property int _decimals: {
    if (!root.step || root.step <= 0) return 0
    var s = root.step.toString()
    if (s.indexOf("e-") !== -1) return parseInt(s.split("e-")[1], 10)
    var dot = s.indexOf(".")
    return dot === -1 ? 0 : (s.length - dot - 1)
  }

  Text {
    text:                  root.label
    color:                 root.colorTextDim
    font.pixelSize:        11
    Layout.preferredWidth: 130
  }

  Item { Layout.fillWidth: true }

  Text {
    text:                  root.value.toFixed(root._decimals) + root.unit
    color:                 root.colorText
    font.pixelSize:        10
    font.family:           "JetBrainsMono Nerd Font"
    Layout.preferredWidth: 54
    horizontalAlignment:   Text.AlignRight
  }

  Item {
    Layout.preferredWidth: 130
    height: 20

    readonly property real ratio: (root.value - root.from) / Math.max(1, root.to - root.from)

    Rectangle {
      anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right }
      height: 4; radius: 2
      color: Qt.rgba(root.colorProgressBg.r, root.colorProgressBg.g, root.colorProgressBg.b, 0.8)

      Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        radius: 2
        width:  parent.parent.ratio * parent.width
        color:  root.colorAccent
      }
    }

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      x:      parent.ratio * (parent.width - width)
      width:  14; height: 14; radius: 7; color: "white"
      Behavior on x { enabled: !sma.pressed; NumberAnimation { duration: 80 } }
    }

    MouseArea {
      id: sma
      anchors.fill: parent
      function apply(mx) {
        var r   = Math.max(0, Math.min(1, mx / parent.width))
        var raw = root.from + r * (root.to - root.from)
        var snapped = Math.round(raw / root.step) * root.step
        // Corrige o erro de ponto flutuante do passo anterior
        // (ex: 0.30000000000000004 → 0.3) antes de emitir.
        root.moved(parseFloat(snapped.toFixed(root._decimals)))
      }
      onPositionChanged: (m) => apply(m.x)
      onClicked:         (m) => apply(m.x)
    }
  }
}
