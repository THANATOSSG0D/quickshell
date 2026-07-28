import QtQuick
import QtQuick.Layouts
import qs
import '../../components' as C
import '../widgets' as W

// ── ScreenLockTab ────────────────────────────────────────────────────────────
// Aba de configuração do Screen Lock no ConfigWindow. Mesmo padrão estrutural
// do PowerMenuTab: um Loader só trocando entre Components nomeados, C.CfgChip/
// C.CfgPalette/C.CfgSlider/C.CfgToggle da lib compartilhada, PmField próprio
// pra texto (não existe equivalente na lib).
//
// Subtabs:
//   0 — Botões    lista editável dos botões de energia (label/ícone/ação/confirmação)
//   1 — Aparência cores + tamanho do relógio via C.CfgPalette/CfgSlider
//   2 — Layout    tamanhos da cápsula/botões/espaçamentos (posição agora é por GRUPO)
//   3 — Comportamento  DPMS, PAM, shake, username, wallpaper
//   4 — Grupos    múltiplos grupos posicionáveis — relógio/senha/botões/widgets
//                 são "membros" que entram em qualquer grupo, igual ao
//                 WidgetLayoutConfig do desktop.

Item {
  id: root

  property int activeSubtab: 0

  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  // ScreenLockConfig — passada pelo ConfigWindow (win.configScreenLock)
  property var config: null

  function g(key, def) { return root.config ? root.config.get(key, def) : def }
  function s(key, value) { if (root.config) root.config.set(key, value) }

  readonly property var _buttons: root.config ? root.config.getButtons() : []
  readonly property var _groups:  root.config ? root.config.getGroups()  : []

  // Todos os "membros" possíveis num grupo — os 3 especiais do lock em si
  // (relógio, senha/usuário, botões de energia) mais os widgets reaproveitados
  // do desktop. Qualquer um pode ir pra qualquer grupo.
  readonly property var _allMembers: [
    { id: "clock",       label: "Relógio + data",       special: true },
    { id: "auth",        label: "Senha + usuário",      special: true },
    { id: "buttons",     label: "Botões de energia",    special: true },
    { id: "todo",        label: "Lista de tarefas" },
    { id: "calendar",    label: "Calendário"       },
    { id: "weather",     label: "Clima"            },
    { id: "cpu",         label: "CPU"              },
    { id: "ram",         label: "RAM"              },
    { id: "gpu",         label: "GPU"              },
    { id: "network",     label: "Rede"             },
    { id: "disk",        label: "Disco"            },
    { id: "system",      label: "Sistema"          },
    { id: "process",     label: "Processos"        },
    { id: "bluetooth",   label: "Bluetooth"        },
    { id: "habits",      label: "Hábitos"          },
    { id: "mediaplayer", label: "Media Player"     },
    { id: "favorites",   label: "Apps Favoritos"   },
  ]
  function _memberLabel(id) {
    const m = root._allMembers.find(m => m.id === id)
    return m ? m.label : id
  }

  readonly property var _colorDefs: [
    { key: "colorClockText", label: "Texto do relógio",              def: "on_surface"         },
    { key: "colorDateText",  label: "Texto da data",                 def: "on_surface_variant" },
    { key: "colorAccent",    label: "Destaque (linha, senha digitada)", def: "primary"          },
    { key: "colorError",     label: "Erro / ação destrutiva",        def: "error"               },
    { key: "colorRunning",   label: "Autenticando (spinner)",        def: "tertiary"            },
    { key: "colorCapsuleBg", label: "Fundo da cápsula de senha",     def: "surface_container"   },
    { key: "colorButtonBg",  label: "Fundo dos botões de energia",   def: "surface_container_high" },
  ]

  // ── Loader principal — um Loader só, trocando entre Components nomeados,
  // mesmo padrão do PanelTab/PowerMenuTab. ──────────────────────────────────
  Loader {
    anchors.fill: parent
    property int _sub: root.activeSubtab
    on_SubChanged: { active = false; active = true }
    active: true
    sourceComponent: {
      if (root.activeSubtab === 0) return _compBotoes
      if (root.activeSubtab === 1) return _compAparencia
      if (root.activeSubtab === 2) return _compLayout
      if (root.activeSubtab === 3) return _compComportamento
      return _compGrupos
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // BOTÕES DE ENERGIA (subtab 0)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compBotoes
    C.CfgScroll {
      C.CfgSection { title: "BOTÕES DE ENERGIA"; colorTextDim: root.colorTextDim }
      Text {
        width: parent.width
        text: "Aparecem onde quer que o membro \"Botões de energia\" esteja posicionado (aba Grupos). \"Confirmar\" pede um segundo clique antes de executar — recomendado pra Reiniciar/Desligar."
        color: root.colorTextDim; opacity: 0.6
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }

      Repeater {
        model: root._buttons
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          width: parent ? parent.width : 0
          height: rowCol.implicitHeight + 20
          radius: 10
          color: Qt.darker(root.colorSidebar, 0.96)
          border.color: root.colorDivider
          border.width: 1

          ColumnLayout {
            id: rowCol
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              PmField {
                Layout.preferredWidth: 44
                text: row.modelData.icon ?? ""
                placeholder: "icon"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateButton(row.modelData.id, { icon: v })
              }
              PmField {
                Layout.fillWidth: true
                text: row.modelData.label ?? ""
                placeholder: "Label"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateButton(row.modelData.id, { label: v })
              }

              Row {
                spacing: 4
                Rectangle {
                  width: 26; height: 26; radius: 6
                  color: "transparent"; border.color: root.colorDivider; border.width: 1
                  Text { anchors.centerIn: parent; text: "▲"; color: root.colorTextDim; font.pixelSize: 10 }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.config && root.config.moveButton(row.index, row.index - 1)
                  }
                }
                Rectangle {
                  width: 26; height: 26; radius: 6
                  color: "transparent"; border.color: root.colorDivider; border.width: 1
                  Text { anchors.centerIn: parent; text: "▼"; color: root.colorTextDim; font.pixelSize: 10 }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.config && root.config.moveButton(row.index, row.index + 1)
                  }
                }
                Rectangle {
                  width: 26; height: 26; radius: 6
                  color: "transparent"; border.color: Colors.error; border.width: 1
                  Text { anchors.centerIn: parent; text: "✕"; color: Colors.error; font.pixelSize: 11 }
                  MouseArea {
                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                    onClicked: root.config && root.config.removeButton(row.modelData.id)
                  }
                }
              }
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: 8

              PmField {
                Layout.fillWidth: true
                text: row.modelData.action ?? ""
                placeholder: "comando (ou __displayOff pra apagar a tela)"
                colorText: root.colorText; colorTextDim: root.colorTextDim
                colorDivider: root.colorDivider; colorAccent: root.colorAccent
                colorBg: root.colorSidebar
                onCommitted: (v) => root.config && root.config.updateButton(row.modelData.id, { action: v })
              }
              C.CfgChip {
                label:  "Confirmar"
                active: row.modelData.confirm === true
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.config && root.config.updateButton(row.modelData.id, { confirm: !row.modelData.confirm })
              }
              C.CfgChip {
                label:  "Visível"
                active: row.modelData.visible !== false
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                onChipClicked: root.config && root.config.updateButton(row.modelData.id, { visible: row.modelData.visible === false })
              }
            }
          }
        }
      }

      C.CfgDiv { colorDivider: root.colorDivider }

      Row {
        spacing: 10
        Rectangle {
          width: addTxt.implicitWidth + 24; height: 32; radius: 8
          color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.16)
          border.color: root.colorAccent; border.width: 1
          Text { id: addTxt; anchors.centerIn: parent; text: "+ Novo botão"; color: root.colorAccent
            font { family: "Fira Sans"; pixelSize: 12; bold: true } }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.config && root.config.addButton({
              icon: "󰐥", label: "Nova ação", action: "echo troque-me", confirm: true, visible: true
            })
          }
        }
        Rectangle {
          width: resetTxt.implicitWidth + 24; height: 32; radius: 8
          color: "transparent"; border.color: root.colorDivider; border.width: 1
          Text { id: resetTxt; anchors.centerIn: parent; text: "Restaurar padrões"; color: root.colorTextDim
            font { family: "Fira Sans"; pixelSize: 12 } }
          MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: root.config && root.config.resetButtons()
          }
        }
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // APARÊNCIA (subtab 1)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compAparencia
    C.CfgScroll {
      C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }
      Repeater {
        model: root._colorDefs
        delegate: C.CfgPalette {
          required property var modelData
          label:    modelData.label
          value:    root.g(modelData.key, modelData.def)
          colors:   root.colors; overlay: root.overlay
          colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
          colorText: root.colorText; colorSidebar: root.colorSidebar
          colorDivider: root.colorDivider
          onEdited: (v) => root.s(modelData.key, v)
        }
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "RELÓGIO"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Tamanho do relógio"; from: 48; to: 140; step: 2; unit: " px"
        value: root.g("clockPixelSize", 96)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("clockPixelSize", v)
      }
      C.CfgSlider {
        label: "Tamanho da data"; from: 10; to: 28; step: 1; unit: " px"
        value: root.g("datePixelSize", 16)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("datePixelSize", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "OVERLAY"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Opacidade do escurecido sobre o wallpaper"; from: 0.0; to: 0.9; step: 0.02; unit: ""
        value: root.g("scrimOpacity", 0.55)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("scrimOpacity", v)
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // LAYOUT (subtab 2) — só tamanhos agora; posição/fundo/colunas viraram
  // propriedade de cada GRUPO (aba Grupos).
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compLayout
    C.CfgScroll {
      C.CfgSection { title: "CÁPSULA DE SENHA"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Largura"; from: 220; to: 480; step: 4; unit: " px"
        value: root.g("capsuleWidth", 320)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("capsuleWidth", v)
      }
      C.CfgSlider {
        label: "Altura"; from: 40; to: 90; step: 2; unit: " px"
        value: root.g("capsuleHeight", 56)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("capsuleHeight", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "BOTÕES DE ENERGIA"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Tamanho dos botões"; from: 32; to: 64; step: 2; unit: " px"
        value: root.g("buttonSize", 44)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("buttonSize", v)
      }
      C.CfgSlider {
        label: "Espaçamento entre botões"; from: 0; to: 32; step: 2; unit: " px"
        value: root.g("buttonSpacing", 10)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("buttonSpacing", v)
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      Text {
        width: parent.width
        text: "Posição, fundo/card e colunas de cada bloco agora vivem na aba Grupos — dá pra ter vários grupos na tela ao mesmo tempo, cada um em um canto."
        color: root.colorTextDim; opacity: 0.6
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // COMPORTAMENTO (subtab 3)
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compComportamento
    C.CfgScroll {
      C.CfgSection { title: "DPMS / INATIVIDADE"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Tempo até apagar a tela"; from: 15000; to: 300000; step: 5000; unit: " ms"
        value: root.g("dpmsTimeoutMs", 90000)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("dpmsTimeoutMs", v)
      }
      Text {
        width: parent.width
        text: "Só vale a partir do PRÓXIMO bloqueio — a instância isolada do lock lê essa config uma vez ao iniciar."
        color: root.colorTextDim; opacity: 0.55
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "AUTENTICAÇÃO"; colorTextDim: root.colorTextDim }
      C.CfgSlider {
        label: "Timeout do PAM"; from: 3000; to: 20000; step: 500; unit: " ms"
        value: root.g("pamWatchdogMs", 8000)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        colorText: root.colorText; colorProgressBg: root.colorProgressBg
        onMoved: (v) => root.s("pamWatchdogMs", v)
      }
      C.CfgToggle {
        label: "Balançar a cápsula ao errar a senha"
        checked: root.g("shakeOnFail", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("shakeOnFail", !root.g("shakeOnFail", true))
      }
      C.CfgToggle {
        label: "Mostrar contagem de tentativas após a 3ª"
        checked: root.g("showFailCount", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("showFailCount", !root.g("showFailCount", true))
      }
      C.CfgToggle {
        label: "Mostrar nome de usuário"
        checked: root.g("showUsername", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("showUsername", !root.g("showUsername", true))
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      C.CfgSection { title: "WALLPAPER"; colorTextDim: root.colorTextDim }
      C.CfgToggle {
        label: "Usar o wallpaper atual do sistema (cache do ml4w)"
        checked: root.g("useSystemWallpaper", true)
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onToggled: root.s("useSystemWallpaper", !root.g("useSystemWallpaper", true))
      }
      PmField {
        width: 340
        visible: !root.g("useSystemWallpaper", true)
        text: root.g("customWallpaperPath", "")
        placeholder: "/caminho/pra/imagem.png"
        colorText: root.colorText; colorTextDim: root.colorTextDim
        colorDivider: root.colorDivider; colorAccent: root.colorAccent
        colorBg: root.colorSidebar
        onCommitted: (v) => root.s("customWallpaperPath", v)
      }
    }
  }

  // ══════════════════════════════════════════════════════════════════════
  // GRUPOS (subtab 4) — múltiplos grupos, cada um com posição/card/colunas
  // próprios. Membros disponíveis: relógio, senha/usuário, botões de
  // energia, e todos os widgets do desktop — cada membro só pode estar em
  // UM grupo por vez (igual WidgetLayoutConfig).
  // ══════════════════════════════════════════════════════════════════════
  Component {
    id: _compGrupos
    C.CfgScroll {
      C.CfgSection { title: "GRUPOS"; colorTextDim: root.colorTextDim }
      Text {
        width: parent.width
        text: "Cada grupo é um card independente na tela — dá pra ter quantos quiser, cada um com sua posição, colunas e fundo. Um membro (relógio, senha, widget...) só pode estar em um grupo por vez."
        color: root.colorTextDim; opacity: 0.6
        font { family: "Fira Sans"; pixelSize: 11 }
        wrapMode: Text.WordWrap
      }

      Rectangle {
        width: addGroupTxt.implicitWidth + 24; height: 32; radius: 8
        color: Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.16)
        border.color: root.colorAccent; border.width: 1
        Text { id: addGroupTxt; anchors.centerIn: parent; text: "+ Novo grupo"; color: root.colorAccent
          font { family: "Fira Sans"; pixelSize: 12; bold: true } }
        MouseArea {
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
          onClicked: root.config && root.config.addGroup()
        }
      }

      Repeater {
        model: root._groups
        delegate: Rectangle {
          id: gcard
          required property var modelData
          required property int index
          readonly property var grp: modelData
          width: parent ? parent.width : 0
          height: gcol.implicitHeight + 24
          radius: 12
          color: Qt.darker(root.colorSidebar, 0.94)
          border.color: root.colorDivider
          border.width: 1

          ColumnLayout {
            id: gcol
            anchors.fill: parent
            anchors.margins: 14
            spacing: 12

            // ── Cabeçalho ──────────────────────────────────────────────
            RowLayout {
              Layout.fillWidth: true
              Text {
                Layout.fillWidth: true
                text: "Grupo " + (gcard.index + 1) + "  ·  " + (gcard.grp.members || []).length + " membro(s)"
                color: root.colorText
                font { family: "Fira Sans"; pixelSize: 13; bold: true }
              }
              Rectangle {
                width: 26; height: 26; radius: 6
                color: "transparent"; border.color: Colors.error; border.width: 1
                Text { anchors.centerIn: parent; text: "✕"; color: Colors.error; font.pixelSize: 11 }
                MouseArea {
                  anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                  onClicked: root.config && root.config.removeGroup(gcard.grp.id)
                }
              }
            }

            // ── Posição ────────────────────────────────────────────────
            W.PositionGrid {
              width: 200
              value: gcard.grp.position ?? 4
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              onSelected: (idx) => root.config && root.config.setGroupField(gcard.grp.id, "position", idx)
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Margem"; from: 0; to: 160; step: 4; unit: " px"
                value: gcard.grp.edgeMargin ?? 48
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "edgeMargin", v)
              }
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Ajuste horizontal"; from: -400; to: 400; step: 10; unit: " px"
                value: gcard.grp.offsetX ?? 0
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "offsetX", v)
              }
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Ajuste vertical"; from: -400; to: 400; step: 10; unit: " px"
                value: gcard.grp.offsetY ?? 0
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "offsetY", v)
              }
            }

            C.CfgDiv { colorDivider: root.colorDivider }

            // ── Membros ────────────────────────────────────────────────
            Text {
              text: "MEMBROS"
              color: root.colorTextDim; opacity: 0.7
              font { family: "Fira Sans"; pixelSize: 10; letterSpacing: 1.5; bold: true }
            }
            Flow {
              Layout.fillWidth: true
              spacing: 6
              Repeater {
                model: root._allMembers
                delegate: C.CfgChip {
                  required property var modelData
                  label:  modelData.label
                  active: root.config ? root.config.groupForMember(modelData.id) === gcard.grp.id : false
                  colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                  onChipClicked: root.config && root.config.toggleMember(gcard.grp.id, modelData.id)
                }
              }
            }

            // Ordem + coluna dos membros DESSE grupo
            Repeater {
              model: gcard.grp.members || []
              delegate: Rectangle {
                id: mrow
                required property string modelData
                required property int index
                Layout.fillWidth: true
                height: 36
                radius: 6
                color: "transparent"
                border.color: root.colorDivider
                border.width: 1

                RowLayout {
                  anchors.fill: parent
                  anchors.margins: 6
                  spacing: 8

                  Text {
                    Layout.fillWidth: true
                    text: root._memberLabel(mrow.modelData)
                    color: root.colorTextDim
                    font { family: "Fira Sans"; pixelSize: 11 }
                  }

                  Row {
                    visible: (gcard.grp.columns ?? 1) > 1
                    spacing: 3
                    Repeater {
                      model: gcard.grp.columns ?? 1
                      delegate: Rectangle {
                        required property int index
                        readonly property int _col: index + 1
                        readonly property int _cur: root.config ? root.config.memberColumn(gcard.grp, mrow.modelData) : 1
                        width: 20; height: 20; radius: 4
                        color: _cur === _col ? Qt.rgba(root.colorAccent.r, root.colorAccent.g, root.colorAccent.b, 0.25) : "transparent"
                        border.color: _cur === _col ? root.colorAccent : root.colorDivider
                        border.width: 1
                        Text { anchors.centerIn: parent; text: _col; color: root.colorText; font.pixelSize: 9 }
                        MouseArea {
                          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                          onClicked: root.config && root.config.setMemberColumn(gcard.grp.id, mrow.modelData, _col)
                        }
                      }
                    }
                  }

                  Rectangle {
                    width: 22; height: 22; radius: 5
                    color: "transparent"; border.color: root.colorDivider; border.width: 1
                    Text { anchors.centerIn: parent; text: "▲"; color: root.colorTextDim; font.pixelSize: 9 }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.config && root.config.moveMember(gcard.grp.id, mrow.modelData, -1)
                    }
                  }
                  Rectangle {
                    width: 22; height: 22; radius: 5
                    color: "transparent"; border.color: root.colorDivider; border.width: 1
                    Text { anchors.centerIn: parent; text: "▼"; color: root.colorTextDim; font.pixelSize: 9 }
                    MouseArea {
                      anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                      onClicked: root.config && root.config.moveMember(gcard.grp.id, mrow.modelData, 1)
                    }
                  }
                }
              }
            }

            C.CfgDiv { colorDivider: root.colorDivider }

            // ── Grade e card ───────────────────────────────────────────
            C.CfgSlider {
              Layout.fillWidth: true
              label: "Colunas"; from: 1; to: 3; step: 1; unit: ""
              value: gcard.grp.columns ?? 1
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              colorText: root.colorText; colorProgressBg: root.colorProgressBg
              onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "columns", v)
            }
            RowLayout {
              Layout.fillWidth: true
              spacing: 10
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Espaço entre colunas"; from: 0; to: 48; step: 2; unit: " px"
                value: gcard.grp.columnSpacing ?? 20
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "columnSpacing", v)
              }
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Espaço entre membros"; from: 0; to: 48; step: 2; unit: " px"
                value: gcard.grp.itemSpacing ?? 20
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "itemSpacing", v)
              }
            }

            C.CfgToggle {
              label: "Fundo/card visível"
              checked: gcard.grp.bgEnabled === true
              colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
              onToggled: root.config && root.config.setGroupField(gcard.grp.id, "bgEnabled", !gcard.grp.bgEnabled)
            }
            ColumnLayout {
              Layout.fillWidth: true
              visible: gcard.grp.bgEnabled === true
              spacing: 8
              C.CfgPalette {
                label: "Cor do fundo"; value: gcard.grp.bgColor || "surface_container"
                colors: root.colors; overlay: root.overlay
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
                onEdited: (v) => root.config && root.config.setGroupField(gcard.grp.id, "bgColor", v)
              }
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Opacidade do fundo"; from: 0; to: 1; step: 0.02; unit: ""
                value: gcard.grp.bgOpacity ?? 0.55
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "bgOpacity", v)
              }
              C.CfgPalette {
                label: "Cor da borda"; value: gcard.grp.borderColor || "outline_variant"
                colors: root.colors; overlay: root.overlay
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
                onEdited: (v) => root.config && root.config.setGroupField(gcard.grp.id, "borderColor", v)
              }
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Raio de borda"; from: 0; to: 48; step: 2; unit: " px"
                value: gcard.grp.radius ?? 14
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "radius", v)
              }
              C.CfgSlider {
                Layout.fillWidth: true
                label: "Padding interno"; from: 0; to: 60; step: 2; unit: " px"
                value: gcard.grp.padding ?? 20
                colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
                colorText: root.colorText; colorProgressBg: root.colorProgressBg
                onMoved: (v) => root.config && root.config.setGroupField(gcard.grp.id, "padding", v)
              }
            }
          }
        }
      }

      C.CfgDiv { colorDivider: root.colorDivider }
      Rectangle {
        width: resetGroupsTxt.implicitWidth + 24; height: 32; radius: 8
        color: "transparent"; border.color: root.colorDivider; border.width: 1
        Text { id: resetGroupsTxt; anchors.centerIn: parent; text: "Restaurar grupos padrão"; color: root.colorTextDim
          font { family: "Fira Sans"; pixelSize: 12 } }
        MouseArea {
          anchors.fill: parent; cursorShape: Qt.PointingHandCursor
          onClicked: root.config && root.config.resetGroups()
        }
      }
    }
  }
}
