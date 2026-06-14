import QtQuick
import QtQuick.Layouts

// ── CfgCollapsible ────────────────────────────────────────────────────────────
// Seção retrátil para agrupar controles de configuração.
//
// Propriedades:
//   title        string   — texto do cabeçalho em caps (ex: "LANÇADOR")
//   expanded     bool     true   — aberta por padrão
//   colorTextDim color    — cor do label e ícone
//   colorAccent  color    — cor da linha de acento lateral
//   colorDivider color    — cor da linha separadora inferior
//
// Uso:
//   C.CfgCollapsible {
//     title: "LANÇADOR"; colorTextDim: root.colorTextDim
//     colorAccent: root.colorAccent; colorDivider: root.colorDivider
//
//     // qualquer filho vai dentro do corpo retrátil:
//     C.CfgToggle { ... }
//     C.CfgSlider { ... }
//   }
//
// Nota: os filhos devem ter width: parent.width para se adaptar corretamente.

Item {
  id: root

  // ── API pública ───────────────────────────────────────────────────────
  property string title:        ""
  property bool   expanded:     true
  required property color colorTextDim
  required property color colorAccent
  required property color colorDivider

  // ── Geometria ─────────────────────────────────────────────────────────
  // Largura herdada do parent (CfgScroll define width nos filhos)
  width:  parent ? parent.width : 0
  // Altura = header + (corpo animado)
  height: _header.height + _bodyClip.height

  // ── Cabeçalho clicável ────────────────────────────────────────────────
  Item {
    id: _header
    width:  parent.width
    height: 28

    // Linha lateral de acento (3px, mesma linguagem visual da sidebar)
    Rectangle {
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
      anchors { topMargin: 4; bottomMargin: 4 }
      width: 3; radius: 2
      color:   root.colorAccent
      opacity: root.expanded ? 1.0 : 0.35
      Behavior on opacity { NumberAnimation { duration: 160 } }
    }

    RowLayout {
      anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
      spacing: 8

      // Título
      Text {
        text:           root.title
        color:          root.colorTextDim
        font.pixelSize: 9
        font.weight:    Font.Medium
        font.family:    "JetBrainsMono Nerd Font"
        Layout.fillWidth: true
      }

      // Ícone chevron
      Text {
        text:        root.expanded ? "\uf077" : "\uf078"   // chevron-up / chevron-down
        color:       root.colorTextDim
        font.pixelSize: 8
        font.family: "JetBrainsMono Nerd Font"
        opacity:     0.7

        Behavior on text { } // sem animação no texto em si
        // animação suave na rotação não é necessária — chevron muda o glyph
      }
    }

    // Linha divisória abaixo do header
    Rectangle {
      anchors.bottom: parent.bottom
      width: parent.width; height: 1
      color: Qt.rgba(root.colorDivider.r, root.colorDivider.g, root.colorDivider.b, 0.35)
    }

    MouseArea {
      anchors.fill: parent
      cursorShape:  Qt.PointingHandCursor
      hoverEnabled: true
      onClicked: root.expanded = !root.expanded

      // Feedback visual sutil no hover
      Rectangle {
        anchors.fill: parent
        color:        parent.containsMouse
                        ? Qt.rgba(1, 1, 1, 0.03)
                        : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }
      }
    }
  }

  // ── Corpo retrátil ────────────────────────────────────────────────────
  Item {
    id:   _bodyClip
    clip: true
    width:  parent.width
    // Altura animada: 0 quando fechado, altura natural do conteúdo quando aberto
    height: root.expanded ? _bodyContent.implicitHeight : 0

    anchors.top: _header.bottom

    Behavior on height {
      NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
    }

    // Opacidade fade-in/out junto com a altura
    opacity: root.expanded ? 1.0 : 0.0
    Behavior on opacity {
      NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
    }

    // Container que mede a altura implícita dos filhos
    Column {
      id:      _bodyContent
      width:   parent.width
      spacing: 10
      topPadding:    10
      bottomPadding: 6

      // Os filhos declarados em CfgCollapsible { ... } são reparentados aqui
      // via default property alias
    }
  }

  // ── Default property: filhos vão para _bodyContent ────────────────────
  default property alias contentData: _bodyContent.data
}
