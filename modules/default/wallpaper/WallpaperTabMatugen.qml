import Quickshell.Io
import QtQuick
import QtQuick.Layouts

Item {
  id: root

  property color  colorText:    "#e2e2e2"
  property color  colorTextDim: "#888888"
  property color  colorAccent:  "#ffb4a9"
  property color  colorDivider: "#333333"
  property bool   panelOpen:    false
  property string mlScripts:    ""
  property string wallSh:       ""
  property string wpRun:        ""
  property string effectsDir:   ""
  property string previewDir:   ""

  property string currentEffect:  "off"
  property string currentPalette: "scheme-fidelity"
  property string currentSource:  "base"
  property int    currentIndex:   0

  signal effectSelected(string e)
  signal paletteSelected(string p)
  signal matugenSourceSelected(string s)
  signal indexSelected(int i)
  signal refreshState()

  property var    effectList:         []
  property var    swatchColors:       []
  property bool   loadingSwatches:    false
  property bool   generatingPreviews: false

  // incrementado após geração concluída para forçar reload das Image
  property int    previewVersion:  0

  readonly property var allPalettes: [
    "scheme-content",     "scheme-expressive", "scheme-fidelity",
    "scheme-fruit-salad", "scheme-monochrome", "scheme-neutral",
    "scheme-rainbow",     "scheme-tonal-spot"
  ]

  // ── Processos ─────────────────────────────────────────────────────────────

  // Lista de efeitos disponíveis
  Process {
    id: effectsListProc
    command: ["bash", "-c",
      "echo off; ls '" + root.effectsDir + "/' 2>/dev/null | sort"]
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { effectsListProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        var raw = effectsListProc._buf.trim(); effectsListProc._buf = ""
        var list = []
        raw.split("\n").forEach(function(l) {
          var t = l.trim(); if (t) list.push(t)
        })
        root.effectList = list
        // Gera previews após saber quais efeitos existem
        _generatePreviews()
      }
    }
  }

  // Gera previews usando wp-effect-previews-refresh.
  // O script lê o source do state.json automaticamente, limpa previews
  // antigas se o wallpaper mudou, e gera novas em paralelo.
  Process {
    id: previewGenProc
    property string _buf: ""
    property string _errbuf: ""
    stdout: SplitParser { onRead: function(l) { previewGenProc._buf    += l } }
    stderr: SplitParser { onRead: function(l) { previewGenProc._errbuf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        previewGenProc._buf    = ""
        previewGenProc._errbuf = ""
        root.generatingPreviews = false
        // Incrementa version APÓS conclusão para forçar reload das Image no QML
        root.previewVersion++
      }
    }
  }

  // Localiza o script wp-effect-previews-refresh ao lado de wallpaper.sh
  function _previewsRefreshScript() {
    return root.mlScripts + "/wp-effect-previews-refresh"
  }

  function _generatePreviews() {
    if (previewGenProc.running) return
    root.generatingPreviews = true
    var script = _previewsRefreshScript()
    // Executa o script de previews; ele detecta source do state.json
    // e limpa/regenera conforme necessário
    previewGenProc.command = ["bash", "-c",
      "\"" + script + "\" 2>/dev/null; true"
    ]
    previewGenProc.running = true
  }

  // path do preview: previewVersion força o Image a recarregar do disco
  function _previewPath(effectName) {
    // Adiciona ?v=N como cache-bust (Image do Qt ignora query string em file://)
    // A forma correta é mudar a source da Image — feito via previewVersion
    return root.previewDir + "/" + effectName + ".png"
  }

  // Swatches de cor do matugen
  Process {
    id: swatchProc
    command: ["bash", "-c",
      "cd '" + root.mlScripts + "' && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -m wp matugen colors 2>/dev/null"
    ]
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { swatchProc._buf += l + "\n" } }
    onRunningChanged: {
      if (!running) {
        root.loadingSwatches = false
        var raw = swatchProc._buf.trim(); swatchProc._buf = ""
        var colors = []
        raw.split("\n").forEach(function(l) {
          var c = l.trim()
          if (/^#[0-9a-fA-F]{6}$/.test(c)) colors.push(c)
        })
        root.swatchColors = colors
      }
    }
  }

  // Aplica efeito: escreve config + chama wallpaper.sh completo
  // (sem --quiet para que ele gere base+efeito e escreva state.json)
  Process {
    id: effectSetProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { effectSetProc._buf += l } }
    onRunningChanged: {
      if (!running) {
        effectSetProc._buf = ""
        root.refreshState()
        // Regenera previews após trocar efeito
        Qt.callLater(function() { _generatePreviews() })
      }
    }
  }

  Process {
    id: paletteSetProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { paletteSetProc._buf += l } }
    onRunningChanged: {
      if (!running) { paletteSetProc._buf = ""; root.refreshState() }
    }
  }

  Process {
    id: sourceSetProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { sourceSetProc._buf += l } }
    onRunningChanged: {
      if (!running) { sourceSetProc._buf = ""; root.refreshState() }
    }
  }

  Process {
    id: matugenApplyProc
    property string _buf: ""
    stdout: SplitParser { onRead: function(l) { matugenApplyProc._buf += l } }
    onRunningChanged: {
      if (!running) { matugenApplyProc._buf = ""; root.refreshState() }
    }
  }

  function _setEffect(e) {
    root.currentEffect = e
    root.effectSelected(e)
    // wallpaper.sh completo (com --quiet para não abrir picker de matugen)
    // escreve state.json via Fase 5 normal
    effectSetProc.command = ["bash", "-c",
      "echo '" + e + "' > ~/.config/ml4w/settings/wallpaper-effect.sh && " +
      "exec '" + root.wpRun + "' --quiet"
    ]
    if (!effectSetProc.running) effectSetProc.running = true
  }

  function _setPalette(p) {
    root.currentPalette = p
    root.paletteSelected(p)
    paletteSetProc.command = ["bash", "-c",
      "echo '" + p + "' > ~/.config/ml4w/settings/matugen-pallete.sh && " +
      "PYTHONPATH='" + root.mlScripts + "' " +
      "python3 -m wp matugen apply --quiet 2>/dev/null && " +
      // Atualiza state.json com a nova palette via state-and-history --patch-only
      // (se disponível) ou re-executa wallpaper.sh --quiet como fallback
      "PYTHONPATH='" + root.mlScripts + "' python3 -c \"" +
        "import sys; sys.path.insert(0,'" + root.mlScripts + "'); " +
        "from wp import state as S; d=S.read_all(); " +
        "d['palette']='" + p + "'; " +
        "S.write(d)" +
      "\" 2>/dev/null || true"
    ]
    if (!paletteSetProc.running) paletteSetProc.running = true
  }

  function _setSource(s) {
    root.currentSource = s
    root.matugenSourceSelected(s)
    sourceSetProc.command = ["bash", "-c",
      "echo '" + s + "' > ~/.config/ml4w/cache/matugen-source && " +
      "PYTHONPATH='" + root.mlScripts + "' " +
      "python3 -m wp matugen apply --quiet 2>/dev/null && " +
      "PYTHONPATH='" + root.mlScripts + "' python3 -c \"" +
        "import sys; sys.path.insert(0,'" + root.mlScripts + "'); " +
        "from wp import state as S; d=S.read_all(); " +
        "d['matugen_source']='" + s + "'; " +
        "S.write(d)" +
      "\" 2>/dev/null || true"
    ]
    if (!sourceSetProc.running) sourceSetProc.running = true
  }

  function _applyIndex(i) {
    root.currentIndex = i
    root.indexSelected(i)
    matugenApplyProc.command = ["bash", "-c",
      "cd '" + root.mlScripts + "' && " +
      "PYTHONPATH='" + root.mlScripts + "' " +
      "python3 -m wp matugen apply --index " + i + " 2>/dev/null && " +
      // Persiste índice no state.json
      "PYTHONPATH='" + root.mlScripts + "' python3 -c \"" +
        "import sys; sys.path.insert(0,'" + root.mlScripts + "'); " +
        "from wp import state as S; d=S.read_all(); " +
        "d['matugen_index']=" + i + "; " +
        "S.write(d)" +
      "\" 2>/dev/null || true"
    ]
    if (!matugenApplyProc.running) matugenApplyProc.running = true
  }

  onPanelOpenChanged: {
    if (panelOpen) {
      if (!effectsListProc.running) effectsListProc.running = true
      if (swatchColors.length === 0 && !loadingSwatches) {
        loadingSwatches = true
        if (!swatchProc.running) swatchProc.running = true
      }
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // UI
  // ═══════════════════════════════════════════════════════════════════════════

  Flickable {
    anchors.fill: parent; clip: true
    contentWidth: width
    contentHeight: col.implicitHeight + 24
    boundsMovement: Flickable.StopAtBounds

    ColumnLayout {
      id: col; x: 16; y: 14; width: parent.width - 32; spacing: 18

      // ── EFEITO ────────────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true; spacing: 8

        RowLayout {
          Layout.fillWidth: true
          Text {
            text: "\uf5aa  EFEITO"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
            color: root.colorTextDim; opacity: 0.7
            Layout.fillWidth: true
          }
          // Indicador de geração de previews
          Row {
            visible: root.generatingPreviews; spacing: 4
            Text {
              text: "\uf110"; anchors.verticalCenter: parent.verticalCenter
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
              color: root.colorTextDim; opacity: 0.6
              RotationAnimator on rotation {
                from: 0; to: 360; duration: 1200
                loops: Animation.Infinite; running: root.generatingPreviews
              }
            }
            Text {
              text: "gerando previews..."; font.pixelSize: 9
              anchors.verticalCenter: parent.verticalCenter
              color: root.colorTextDim; opacity: 0.5
            }
          }
          // Botão regenerar manualmente
          Item {
            width: 22; height: 22
            visible: !root.generatingPreviews
            Text {
              anchors.centerIn: parent; text: "\uf021"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 10 }
              color: root.colorTextDim; opacity: 0.5
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: _generatePreviews()
            }
          }
        }

        Flow {
          Layout.fillWidth: true; spacing: 8

          Repeater {
            model: root.effectList

            delegate: Item {
              id: ed
              width: 100; height: 76
              readonly property bool isAct: root.currentEffect === modelData
              // previewVersion força recarregamento da Image após nova geração
              readonly property string pvPath: root.previewDir + "/" + modelData + ".png"

              Rectangle {
                anchors.fill: parent; radius: 8; clip: true
                color: isAct
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  : (ema.containsMouse ? Qt.rgba(1,1,1,0.08) : Qt.rgba(1,1,1,0.04))
                border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.09)
                border.width: isAct ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 110 } }

                Image {
                  id: pvImg
                  anchors { top: parent.top; left: parent.left; right: parent.right }
                  height: 55
                  fillMode: Image.PreserveAspectCrop
                  asynchronous: true; cache: false; smooth: true
                  // cache:false + source reload via previewVersion para mostrar
                  // as novas previews após wp-effect-previews-refresh terminar
                  source: root.previewVersion >= 0 ? ("file://" + ed.pvPath) : ""

                  Rectangle {
                    anchors.fill: parent
                    visible: pvImg.status !== Image.Ready
                    color: Qt.rgba(1,1,1,0.06)
                    Text {
                      anchors.centerIn: parent; text: "\uf03e"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 14 }
                      color: root.colorTextDim; opacity: 0.3
                    }
                  }
                }

                Rectangle {
                  anchors.bottom: parent.bottom
                  anchors.left: parent.left; anchors.right: parent.right
                  height: 20; color: Qt.rgba(0,0,0,0.55)

                  RowLayout {
                    anchors { fill: parent; leftMargin: 6; rightMargin: 4 }
                    Text {
                      Layout.fillWidth: true
                      text: modelData; font.pixelSize: 9
                      color: isAct ? root.colorAccent : "white"
                      elide: Text.ElideRight
                      Behavior on color { ColorAnimation { duration: 100 } }
                    }
                    Text {
                      visible: isAct; text: "\uf00c"
                      font { family: "JetBrainsMono Nerd Font"; pixelSize: 9 }
                      color: root.colorAccent
                    }
                  }
                }
              }

              MouseArea {
                id: ema; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._setEffect(modelData)
              }
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.35 }

      // ── PALETTE ───────────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true; spacing: 8

        Text {
          text: "\uf53f  PALETTE"
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
          color: root.colorTextDim; opacity: 0.7
        }

        Flow {
          Layout.fillWidth: true; spacing: 6

          Repeater {
            model: root.allPalettes
            delegate: Item {
              width: pc.implicitWidth; height: 28
              readonly property bool isAct: root.currentPalette === modelData

              Rectangle {
                id: pc; anchors.fill: parent; radius: 14
                implicitWidth: pt.implicitWidth + 24
                color: isAct
                  ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                  : Qt.rgba(1,1,1,0.06)
                border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.1)
                border.width: isAct ? 1.5 : 1
                Behavior on color { ColorAnimation { duration: 120 } }

                Text {
                  id: pt; anchors.centerIn: parent
                  text: modelData.replace("scheme-", ""); font.pixelSize: 10
                  color: isAct ? root.colorAccent : root.colorText
                  Behavior on color { ColorAnimation { duration: 100 } }
                }
              }
              MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                onClicked: root._setPalette(modelData)
              }
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.35 }

      // ── SOURCE ────────────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true; spacing: 8

        Text {
          text: "\uf03e  FONTE MATUGEN"
          font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
          color: root.colorTextDim; opacity: 0.7
          Layout.fillWidth: true
        }

        Repeater {
          model: [{ id: "base", label: "base" }, { id: "final", label: "final" }]
          delegate: Item {
            width: sc.implicitWidth; height: 28
            readonly property bool isAct: root.currentSource === modelData.id

            Rectangle {
              id: sc; anchors.fill: parent; radius: 14
              implicitWidth: sl.implicitWidth + 24
              color: isAct
                ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.18)
                : Qt.rgba(1,1,1,0.06)
              border.color: isAct ? root.colorAccent : Qt.rgba(1,1,1,0.1)
              border.width: isAct ? 1.5 : 1
              Behavior on color { ColorAnimation { duration: 120 } }

              Text {
                id: sl; anchors.centerIn: parent
                text: modelData.label; font.pixelSize: 10
                color: isAct ? root.colorAccent : root.colorText
                Behavior on color { ColorAnimation { duration: 100 } }
              }
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: root._setSource(modelData.id)
            }
          }
        }
      }

      Rectangle { Layout.fillWidth: true; height: 1; color: root.colorDivider; opacity: 0.35 }

      // ── COR DA FONTE ──────────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true; spacing: 8

        RowLayout {
          Layout.fillWidth: true

          Text {
            text: "\uf111  COR DA FONTE"
            font { family: "JetBrainsMono Nerd Font"; pixelSize: 9; letterSpacing: 1.5 }
            color: root.colorTextDim; opacity: 0.7
            Layout.fillWidth: true
          }

          Item {
            width: 24; height: 24
            Text {
              anchors.centerIn: parent; text: "\uf021"
              font { family: "JetBrainsMono Nerd Font"; pixelSize: 11 }
              color: root.loadingSwatches
                ? Qt.rgba(root.colorTextDim.r, root.colorTextDim.g, root.colorTextDim.b, 0.3)
                : root.colorTextDim
              opacity: 0.7
            }
            MouseArea {
              anchors.fill: parent; cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (!swatchProc.running) {
                  root.swatchColors = []; root.loadingSwatches = true
                  swatchProc.running = true
                }
              }
            }
          }
        }

        Text {
          visible: root.loadingSwatches
          text: "gerando paleta..."
          font.pixelSize: 10; color: root.colorTextDim; opacity: 0.5
        }

        Flow {
          Layout.fillWidth: true; spacing: 6
          visible: !root.loadingSwatches && root.swatchColors.length > 0

          Repeater {
            model: root.swatchColors
            delegate: Item {
              width: 34; height: 34
              readonly property bool isAct: root.currentIndex === index

              Rectangle {
                anchors.fill: parent; radius: 7; color: modelData
                border.color: isAct ? "white" : Qt.rgba(0,0,0,0.35)
                border.width: isAct ? 2 : 1

                Text {
                  anchors { bottom: parent.bottom; right: parent.right; margins: 2 }
                  text: index; font.pixelSize: 7; color: "white"
                  style: Text.Outline; styleColor: "#80000000"
                }
                Text {
                  anchors.centerIn: parent; visible: isAct; text: "\uf00c"
                  font { family: "JetBrainsMono Nerd Font"; pixelSize: 12 }
                  color: "white"; style: Text.Outline; styleColor: "#80000000"
                }
                scale: swma.containsMouse ? 1.1 : 1.0
                Behavior on scale { NumberAnimation { duration: 90 } }
              }

              MouseArea {
                id: swma; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root._applyIndex(index)
              }
            }
          }
        }

        Text {
          visible: !root.loadingSwatches && root.swatchColors.length === 0
          text: "Abra a aba e aguarde a paleta carregar."
          font.pixelSize: 10; color: root.colorTextDim; opacity: 0.5
        }
      }

      Item { height: 8 }
    }
  }
}
