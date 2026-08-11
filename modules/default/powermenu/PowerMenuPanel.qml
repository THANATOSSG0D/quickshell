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

  readonly property bool   _fullscreen: root._g("fullscreen", true)
  readonly property string _style:      root._g("menuStyle", "cards")
  readonly property int    _padding:    root._g("windowedPadding", 40)

  // ── Tamanho real do conteúdo — o PowerMenu.qml (janela) lê isso pra
  // dimensionar a superfície layer-shell de verdade no modo janela (em vez
  // de cobrir a tela toda e só desenhar um card por cima dela). Calculado
  // 100% a partir do conteúdo (mainCol), então NÃO depende do tamanho atual
  // de `root` — sem risco de loop de binding com a janela que lê isto. ─────
  readonly property int contentWidth:  Math.ceil(mainCol.implicitWidth)  + root._padding * 2
  readonly property int contentHeight: Math.ceil(mainCol.implicitHeight) + root._padding * 2

  // Colunas da grade de botões — "row" = tudo numa linha (comportamento de
  // sempre), "grid" = quebra a cada N (gridColumns), "column" = empilhado.
  // Só se aplica aos estilos "cards"/"compact" (grade); "list" é sempre
  // uma coluna única de linhas.
  readonly property int _columns: {
    var mode = root._g("buttonLayoutMode", "row")
    if (mode === "column") return 1
    if (mode === "grid")   return Math.max(1, root._g("gridColumns", 3))
    return Math.max(1, root.entries.length)
  }

  opacity: root.anim
  scale:   0.96 + 0.04 * root.anim

  // ── Fundo — só no modo tela cheia. No modo janela a superfície inteira
  // JÁ É o card (dimensionada por contentWidth/contentHeight lá em cima),
  // então não tem "fora" pra escurecer — fechar ao clicar fora nesse modo
  // é responsabilidade do HyprlandFocusGrab no PowerMenu.qml. ─────────────
  Rectangle {
    visible: root._fullscreen
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

  // ── Sombra "falsa" do card no modo janela — algumas bordas empilhadas
  // com opacidade decrescente, já que não dá pra contar com blur real sem
  // depender de módulos gráficos extras. ───────────────────────────────────
  Item {
    visible: !root._fullscreen && root._g("windowShadow", true)
    anchors.fill: cardBg
    z: -1
    Repeater {
      model: 4
      Rectangle {
        required property int index
        anchors.centerIn: parent
        width:  parent.width  + (index + 1) * 5
        height: parent.height + (index + 1) * 5
        radius: cardBg.radius + (index + 1) * 3
        color:  "transparent"
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.10 - index * 0.02)
      }
    }
    Rectangle {
      anchors.fill: parent
      anchors.margins: -6
      radius: cardBg.radius + 6
      color: Qt.rgba(0, 0, 0, 0.18)
      z: -1
    }
  }

  // ── Card do modo "janela" — no modo tela cheia isso fica invisível (o
  // fundo é só o dim de tela toda, como sempre foi); no modo janela é a
  // própria superfície da janela (ver contentWidth/contentHeight acima),
  // então o clique dentro nunca deve fechar — só clicar fora dela (fora da
  // janela real agora, detectado via HyprlandFocusGrab) fecha. ─────────────
  Rectangle {
    id: cardBg
    visible: !root._fullscreen
    anchors.centerIn: parent
    width:  root.contentWidth
    height: root.contentHeight
    radius: root._g("windowedRadius", 24)
    color:  Qt.rgba(_wcBg.r, _wcBg.g, _wcBg.b, 0.97)
    border.color: root._c("colorBorder", Colors.outline_variant)
    border.width: 1

    readonly property color _wcBg: root._c("colorWindowBg", Colors.surface_container_high)

    MouseArea { anchors.fill: parent; onClicked: {} }
  }

  // ── Conteúdo central: título + itens (grade de cards/círculos ou lista) ──
  Column {
    id: mainCol
    anchors.centerIn: parent
    spacing:          24

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

    Loader {
      anchors.horizontalCenter: parent.horizontalCenter
      sourceComponent: root._style === "list" ? _listItems : _gridItems
    }

    // No modo janela, as dicas de teclado ficam dentro do card, coladas
    // embaixo dos itens (o card cresce pra caber tudo — ver contentHeight).
    Loader {
      anchors.horizontalCenter: parent.horizontalCenter
      active: !root._fullscreen
      sourceComponent: _hintsRow
    }
  }

  // ── Estilo "cards" / "compact" — grade de PowerMenuButton ────────────────
  Component {
    id: _gridItems
    GridLayout {
      columns:       root._columns
      columnSpacing: root._style === "compact" ? root._g("compactSpacing", 18) : root._g("cardSpacing", 20)
      rowSpacing:    root._style === "compact" ? root._g("compactSpacing", 18) : root._g("cardSpacing", 20)

      Repeater {
        model: root.entries

        PowerMenuButton {
          required property var modelData
          required property int index

          entry:     modelData
          isFocused: root.focused === index
          pending:   root.pendingIndex === index
          config:    root.config
          variant:   root._style === "compact" ? "compact" : "card"

          onClicked: root.activateRequested(index)
          onHovered: {
            root.focused = index
            root.focusIndexChanged(index)
          }
        }
      }
    }
  }

  // ── Estilo "list" — coluna de PowerMenuListItem ──────────────────────────
  Component {
    id: _listItems
    Column {
      spacing: root._g("listSpacing", 8)
      width:   root._g("listWidth", 340)

      Repeater {
        model: root.entries

        PowerMenuListItem {
          required property var modelData
          required property int index

          width:     root._g("listWidth", 340)
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
