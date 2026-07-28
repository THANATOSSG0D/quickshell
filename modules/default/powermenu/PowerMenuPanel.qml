import QtQuick
import QtQuick.Layouts
import "root:/"
import "."

Item {
  id: root

  property var entries:     []
  property int focused:     -1
  property int pendingIndex: -1
  // PowerMenuConfig — opcional (fallback pros defaults hardcoded se null)
  property var config: null
  // 0..1 — progresso da animação de entrada/saída, controlado pelo PowerMenu.qml
  property real anim: 1.0

  // Agora emite o ÍNDICE da entrada, não o comando — quem decide se
  // precisa de confirmação (e executa de fato) é o PowerMenu.qml, que
  // também recebe os atalhos de teclado. Assim mouse e teclado passam
  // pelo MESMO fluxo de confirmação.
  signal activateRequested(int idx)
  signal closeRequested()
  signal focusIndexChanged(int idx)

  function _g(key, fallback) { return root.config ? root.config.get(key, fallback) : fallback }
  function _c(key, fallback) { return root.config ? root.config.getColor(key) : fallback }

  readonly property bool _fullscreen: root._g("fullscreen", true)

  // Colunas da grade de botões — "row" = tudo numa linha (comportamento de
  // sempre), "grid" = quebra a cada N (gridColumns), "column" = empilhado.
  readonly property int _columns: {
    var mode = root._g("buttonLayoutMode", "row")
    if (mode === "column") return 1
    if (mode === "grid")   return Math.max(1, root._g("gridColumns", 3))
    return Math.max(1, root.entries.length)
  }

  opacity: root.anim
  scale:   0.96 + 0.04 * root.anim

  // ── Fundo ─────────────────────────────────────────────────────────────────
  Rectangle {
    anchors.fill: parent
    color:        Qt.rgba(0, 0, 0, root._g("overlayOpacity", 0.72))
    MouseArea {
      anchors.fill: parent
      onClicked: { if (root._g("closeOnClickOutside", true)) root.closeRequested() }
    }
  }

  // ── Linha decorativa topo — só faz sentido grudada na borda da tela,
  // então só aparece no modo tela cheia. ─────────────────────────────────────
  Rectangle {
    visible: root._fullscreen
    anchors.top:              parent.top
    anchors.topMargin:        48
    anchors.horizontalCenter: parent.horizontalCenter
    width:   120
    height:  2
    radius:  1
    color:   root._c("colorAccent", Colors.primary)
    opacity: 0.5
  }

  // ── Card do modo "janela" — fundo visível atrás do conteúdo, centralizado.
  // Some no modo tela cheia (aí o fundo é só o dim de tela toda, como sempre
  // foi). O clique DENTRO do card não deve fechar o menu — só o clique fora
  // dele (no dim de fundo) fecha. ─────────────────────────────────────────────
  Rectangle {
    id: windowCard
    visible: !root._fullscreen
    anchors.centerIn: parent
    width:  mainCol.implicitWidth  + root._g("windowedPadding", 40) * 2
    height: mainCol.implicitHeight + root._g("windowedPadding", 40) * 2
    radius: root._g("windowedRadius", 24)
    color:  Qt.rgba(_wcBg.r, _wcBg.g, _wcBg.b, 0.97)
    border.color: root._c("colorBorder", Colors.outline_variant)
    border.width: 1

    readonly property color _wcBg: root._c("colorWindowBg", Colors.surface_container_high)

    MouseArea { anchors.fill: parent; onClicked: {} }
  }

  // ── Conteúdo central: título + grade de botões ──────────────────────────────
  Column {
    id: mainCol
    anchors.centerIn: parent
    spacing:          28

    Text {
      anchors.horizontalCenter: parent.horizontalCenter
      text:    root._g("title", "SESSÃO")
      color:   root._c("colorLabel", Colors.on_surface_variant)
      opacity: 0.4
      font {
        family:        "Fira Sans"
        pixelSize:     11
        letterSpacing: 5
      }
    }

    GridLayout {
      anchors.horizontalCenter: parent.horizontalCenter
      columns:       root._columns
      columnSpacing: root._g("cardSpacing", 20)
      rowSpacing:    root._g("cardSpacing", 20)

      Repeater {
        model: root.entries

        PowerMenuButton {
          required property var modelData
          required property int index

          entry:     modelData
          isFocused: root.focused === index
          pending:   root.pendingIndex === index
          config:    root.config

          onClicked: root.activateRequested(index)
          onHovered: {
            root.focused = index
            root.focusIndexChanged(index)
          }
        }
      }
    }

    // No modo janela, as dicas de teclado ficam dentro do card, coladas
    // embaixo da grade (o card cresce pra caber tudo).
    Loader {
      anchors.horizontalCenter: parent.horizontalCenter
      active: !root._fullscreen
      sourceComponent: _hintsRow
    }
  }

  // ── Dicas de teclado — no modo tela cheia ficam fixas embaixo da tela;
  // no modo janela, a mesma Component é reaproveitada dentro do mainCol
  // acima (via Loader), então o conteúdo não é duplicado. ────────────────────
  Loader {
    anchors {
      horizontalCenter: parent.horizontalCenter
      bottom:           parent.bottom
      bottomMargin:     36
    }
    active: root._fullscreen
    sourceComponent: _hintsRow
  }

  Component {
    id: _hintsRow
    Row {
      spacing: 24

      Repeater {
        model: [
          { key: "ESC",   desc: "fechar"    },
          { key: "Tab",   desc: "navegar"   },
          { key: "Enter", desc: "confirmar" }
        ]

        delegate: Row {
          required property var modelData
          spacing: 7

          Rectangle {
            width:   keyTxt.implicitWidth + 12
            height:  18
            radius:  4
            color:   Colors.surface_container_high
            border.color: Colors.outline_variant
            border.width: 1
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: keyTxt
              anchors.centerIn: parent
              text:  modelData.key
              color: Colors.on_surface_variant
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 10; bold: true }
            }
          }

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text:    modelData.desc
            color:   Colors.on_surface_variant
            opacity: 0.45
            font { family: "Fira Sans"; pixelSize: 12 }
          }
        }
      }
    }
  }
}
