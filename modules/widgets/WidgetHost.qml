import qs

import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

import "clock"
import "todo"
import "calendar"
import "weather"
import "cpu"
import "ram"
import "gpu"
import "network"
import "disk"
import "system"
import "process"
import "bluetooth"
import "habits"
import "mediaplayer"
import "favorites"

// ── WidgetHost ──────────────────────────────────────────────────────────
// Quando existe pelo menos um grupo ativo em WidgetLayoutConfig.groups,
// essa é a ÚNICA janela que renderiza os widgets agrupados: um card por
// grupo (cada um com sua própria posição/margem/estilo). Dentro do card,
// os membros viram "faixas" (ver panel.bands): blocos de colunas
// independentes tipo masonry — cada coluna empilha só os PRÓPRIOS
// membros pela própria altura, nunca esticada pra bater com a vizinha —
// intercalados com widgets marcados "ocupar linha inteira", que quebram
// o fluxo e ocupam a largura toda do card. Todo widget de uma mesma
// coluna (mesmo em faixas diferentes) fica com a MESMA largura, a do
// maior — ver panel.bindColWidth(). Os Widget.qml individuais
// (ClockWidget, TodoWidget, etc.) se desligam sozinhos quando o widget
// deles está em algum grupo ATIVO e HABILITADO (ver isGrouped()/
// isEnabled() em cada um).

Scope {
  id: widgetHost

  WidgetLayoutConfig { id: layoutCfg }

  // Janela centralizada de "nova tarefa" do módulo Todo (se ele estiver
  // presente em algum grupo) — mesma janela usada pelo modo não-agrupado,
  // compartilhada entre todos os cards.
  TodoAddWindow { id: addTaskWindow }

  // Painel grande (Kanban / Progresso / Agenda) do módulo Todo — mesma
  // ideia, uma instância só pra todos os grupos.
  TodoDashboard {
    id: dashboardWindow
    onEditTaskRequested: (task) => addTaskWindow.openEdit(task)
    onAddTaskRequested: addTaskWindow.openForm()
  }

  // Mesma ideia pro módulo Habits — janela de add/edit + painel de
  // gerenciar/histórico, uma instância só pra todos os grupos.
  HabitsAddWindow { id: addHabitWindow }
  HabitsDashboard {
    id: habitsDashboardWindow
    onEditHabitRequested: (habit) => addHabitWindow.openEdit(habit)
    onAddHabitRequested: addHabitWindow.openForm()
  }

  Component { id: clockComp;    ClockContent    { grouped: true } }
  Component { id: todoComp;     TodoContent     { grouped: true } }
  Component { id: calendarComp; CalendarContent { grouped: true } }
  Component { id: weatherComp;  WeatherContent  { grouped: true } }
  Component { id: cpuComp;      CpuContent      { grouped: true } }
  Component { id: ramComp;      RamContent      { grouped: true } }
  Component { id: gpuComp;      GpuContent      { grouped: true } }
  Component { id: networkComp;  NetworkContent  { grouped: true } }
  Component { id: diskComp;     DiskContent     { grouped: true } }
  Component { id: systemComp;   SystemContent   { grouped: true } }
  Component { id: processComp;  ProcessContent  { grouped: true } }
  Component { id: bluetoothComp; BluetoothContent { grouped: true } }
  Component { id: habitsComp;      HabitsContent      { grouped: true } }
  Component { id: mediaPlayerComp; MediaPlayerContent { grouped: true } }
  Component { id: favoritesComp;   FavoritesContent   { grouped: true } }

  function componentFor(id) {
    switch (id) {
      case "clock":     return clockComp
      case "todo":      return todoComp
      case "calendar":  return calendarComp
      case "weather":   return weatherComp
      case "cpu":       return cpuComp
      case "ram":       return ramComp
      case "gpu":       return gpuComp
      case "network":   return networkComp
      case "disk":      return diskComp
      case "system":    return systemComp
      case "process":   return processComp
      case "bluetooth": return bluetoothComp
      case "habits":      return habitsComp
      case "mediaplayer": return mediaPlayerComp
      case "favorites":   return favoritesComp
    }
    return null
  }

  // produto cartesiano tela × grupo-ativo — cada combinação vira uma
  // PanelWindow própria, então grupos com posições diferentes na mesma
  // tela não brigam pela mesma janela/máscara. Um grupo só entra aqui se
  // tiver pelo menos 1 membro que também esteja HABILITADO (widget
  // desativado não conta, mesmo que ainda esteja marcado no grupo).
  readonly property var _instances: {
    const list = []
    const activeGroups = layoutCfg.groups.filter(g =>
      g.enabled && g.members.some(id => layoutCfg.isEnabled(id)))
    for (const screen of Quickshell.screens) {
      for (const group of activeGroups) {
        list.push({ screen: screen, group: group })
      }
    }
    return list
  }

  Variants {
    model: widgetHost._instances

    delegate: Component {
      PanelWindow {
        id: panel
        required property var modelData
        readonly property var group: modelData.group
        screen: modelData.screen

        anchors { left: true; right: true; top: true; bottom: true }
        color: "transparent"

        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace: "widget-group-" + group.id

        // data selecionada no Calendário (yyyy-MM-dd, "" = nenhuma) —
        // estado por card, só existe enquanto os dois widgets (calendar +
        // todo) estiverem juntos NESSE grupo. Ver wiring genérico no
        // Loader abaixo: não é específico de tipo, só liga quando os dois
        // membros existem e expõem as propriedades/sinais esperados.
        property string todoFilterDate: ""

        // membros do grupo já filtrados pelos que estão habilitados —
        // widget desativado desaparece do card sem precisar sair do
        // grupo (fica só "pausado", volta sozinho se reativar)
        readonly property var activeMembers: group.members.filter(id => layoutCfg.isEnabled(id))

        // Quebra activeMembers em "faixas" (bands), na ordem original:
        //   { type: "columns", cols: [[id,...], [id,...], ...] } — um
        //     bloco de colunas independentes, cada uma empilhando só os
        //     PRÓPRIOS membros pela própria altura (masonry — nunca
        //     esticado pra bater com a coluna vizinha)
        //   { type: "span", id } — um widget sozinho ocupando a largura
        //     inteira do card (memberFullWidth), que também fecha o
        //     bloco de colunas atual e abre um novo depois dele
        readonly property var bands: {
          const cols = group.columns || 1
          const mc = group.memberColumns || {}
          const fw = group.memberFullWidth || {}
          const result = []
          let current = null

          function flush() {
            if (current && current.some(c => c.length > 0)) result.push({ type: "columns", cols: current })
            current = null
          }

          for (const id of activeMembers) {
            if (fw[id]) {
              flush()
              result.push({ type: "span", id })
            } else {
              if (!current) current = Array.from({ length: cols }, () => [])
              let col = mc[id] || 1
              if (col < 1) col = 1
              if (col > cols) col = cols
              current[col - 1].push(id)
            }
          }
          flush()
          return result
        }

        // largura máxima observada em cada índice de coluna, compartilhada
        // entre TODAS as faixas de colunas do card — assim colunas de
        // faixas diferentes ainda alinham entre si, e todo widget da
        // mesma coluna fica com a MESMA largura (a do maior), em vez de
        // só centralizado cada um com o próprio tamanho
        property var colWidths: ({})

        function bindColWidth(item, col) {
          const w = item.implicitWidth
          if (w <= 0) return
          const cw = Object.assign({}, colWidths)
          if (!cw[col] || w > cw[col]) {
            cw[col] = w
            colWidths = cw
          }
          // o piso mínimo (columnMinWidth) é aplicado AQUI DENTRO do
          // binding, não no momento do load — assim, se o usuário mudar
          // o slider depois, todo item já carregado recalcula sozinho
          // (se aplicasse só na hora do load, teria que esperar o widget
          // recarregar pra pegar um piso novo)
          item.width = Qt.binding(function() {
            const measured = panel.colWidths[col] || item.implicitWidth
            return Math.max(measured, panel.group.columnMinWidth || 0)
          })
        }

        // wiring compartilhado (dashboard/todo/calendário) — igual pra
        // qualquer widget carregado, seja numa coluna ou numa faixa cheia
        function wireItem(item) {
          if (!item) return
          if (item.addTaskRequested !== undefined)
            item.addTaskRequested.connect(function() { addTaskWindow.openForm() })
          if (item.editTaskRequested !== undefined)
            item.editTaskRequested.connect(function(task) { addTaskWindow.openEdit(task) })
          if (item.dashboardRequested !== undefined)
            item.dashboardRequested.connect(function() { dashboardWindow.open() })

          // Habits combinado: mesmo wiring genérico do Todo acima, com
          // sinais próprios (addHabitRequested/editHabitRequested/
          // habitsDashboardRequested) pra não colidir com os do Todo.
          if (item.addHabitRequested !== undefined)
            item.addHabitRequested.connect(function() { addHabitWindow.openForm() })
          if (item.editHabitRequested !== undefined)
            item.editHabitRequested.connect(function(habit) { addHabitWindow.openEdit(habit) })
          if (item.habitsDashboardRequested !== undefined)
            item.habitsDashboardRequested.connect(function() { habitsDashboardWindow.open() })

          // Calendário combinado: clicar num dia informa a data
          // selecionada pro estado do card; a própria borda de seleção
          // do calendário fica amarrada a esse mesmo estado (some se o
          // filtro for limpo pelo lado do Todo).
          if (item.dateSelected !== undefined) {
            item.selectedDate = Qt.binding(function() { return panel.todoFilterDate })
            item.dateSelected.connect(function(date) { panel.todoFilterDate = date })
          }

          // Todo combinado: filtra pela data escolhida no calendário (se
          // ele também estiver nesse mesmo grupo — do contrário
          // todoFilterDate nunca sai de "") e permite limpar o filtro
          // pelo "×" do próprio cabeçalho.
          if (item.filterDate !== undefined) {
            item.filterDate = Qt.binding(function() { return panel.todoFilterDate })
            if (item.clearFilterRequested !== undefined)
              item.clearFilterRequested.connect(function() { panel.todoFilterDate = "" })
          }
        }

        mask: Region { item: content }

        readonly property var positions: [
          { h: Qt.AlignLeft,    v: Qt.AlignTop     },
          { h: Qt.AlignHCenter, v: Qt.AlignTop     },
          { h: Qt.AlignRight,   v: Qt.AlignTop     },
          { h: Qt.AlignLeft,    v: Qt.AlignVCenter },
          { h: Qt.AlignHCenter, v: Qt.AlignVCenter },
          { h: Qt.AlignRight,   v: Qt.AlignVCenter },
          { h: Qt.AlignLeft,    v: Qt.AlignBottom  },
          { h: Qt.AlignHCenter, v: Qt.AlignBottom  },
          { h: Qt.AlignRight,   v: Qt.AlignBottom  },
        ]

        Item {
          id: content
          x: {
            if (positions[panel.group.position].h === Qt.AlignLeft)  return panel.group.edgeMargin
            if (positions[panel.group.position].h === Qt.AlignRight) return parent.width - width - panel.group.edgeMargin
            return (parent.width - width) / 2
          }
          y: {
            if (positions[panel.group.position].v === Qt.AlignTop)    return panel.group.edgeMargin
            if (positions[panel.group.position].v === Qt.AlignBottom) return parent.height - height - panel.group.edgeMargin
            return (parent.height - height) / 2
          }
          width: card.width
          height: card.implicitHeight

          Rectangle {
            id: card
            width: bandsLayout.implicitWidth + 24
            implicitHeight: bandsLayout.implicitHeight + 24
            radius: panel.group.radius !== undefined ? panel.group.radius : 14
            color: {
              const c = Colors[panel.group.bgColor || "surface_container"]
              const o = panel.group.bgOpacity !== undefined ? panel.group.bgOpacity : 0.55
              return Qt.rgba(c.r, c.g, c.b, o)
            }
            border.width: panel.group.borderWidth !== undefined ? panel.group.borderWidth : 1
            border.color: {
              const c = Colors[panel.group.borderColor || "outline_variant"]
              const o = panel.group.borderOpacity !== undefined ? panel.group.borderOpacity : 0.4
              return Qt.rgba(c.r, c.g, c.b, o)
            }

            ColumnLayout {
              id: bandsLayout
              anchors.centerIn: parent
              spacing: 14

              Repeater {
                model: panel.bands
                delegate: Item {
                  id: bandItem
                  required property var modelData
                  required property int index
                  Layout.fillWidth: modelData.type === "span"
                  Layout.alignment: Qt.AlignHCenter
                  implicitWidth: bandLoader.item ? bandLoader.item.implicitWidth : 0
                  implicitHeight: bandLoader.item ? bandLoader.item.implicitHeight : 0

                  Loader {
                    id: bandLoader
                    anchors.fill: parent
                    sourceComponent: bandItem.modelData.type === "span" ? spanBandComp : columnsBandComp
                  }
                  // ── faixa "widget sozinho, largura total" ──────────
                  Component {
                    id: spanBandComp
                    Loader {
                      anchors.centerIn: parent
                      sourceComponent: widgetHost.componentFor(bandItem.modelData.id)
                      onLoaded: panel.wireItem(item)
                    }
                  }

                  // ── faixa "bloco de colunas independentes (masonry)" ──
                  Component {
                    id: columnsBandComp
                    RowLayout {
                      spacing: panel.group.columnSpacing !== undefined ? panel.group.columnSpacing : 20

                      Repeater {
                        model: bandItem.modelData.cols
                        delegate: ColumnLayout {
                          id: colStack
                          required property var modelData  // [widgetId, ...] dessa coluna
                          required property int index       // índice da coluna
                          spacing: 0

                          Repeater {
                            model: colStack.modelData
                            delegate: ColumnLayout {
                              required property string modelData  // widgetId
                              required property int index          // posição na coluna
                              spacing: 0

                              Loader {
                                Layout.alignment: Qt.AlignHCenter
                                sourceComponent: widgetHost.componentFor(modelData)
                                onLoaded: {
                                  panel.bindColWidth(item, colStack.index)
                                  panel.wireItem(item)
                                }
                              }

                              Rectangle {
                                Layout.fillWidth: true
                                Layout.topMargin: (panel.group.itemSpacing !== undefined ? panel.group.itemSpacing : 20) / 2
                                Layout.bottomMargin: (panel.group.itemSpacing !== undefined ? panel.group.itemSpacing : 20) / 2
                                height: 1
                                visible: index < colStack.modelData.length - 1
                                color: Qt.rgba(1, 1, 1, 0.1)
                              }
                            }
                          }
                        }
                      }
                    }
                  }

                }
              }
            }
          }
        }
      }
    }
  }
}
