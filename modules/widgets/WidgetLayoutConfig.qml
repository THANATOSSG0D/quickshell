import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons

// ── WidgetLayoutConfig ──────────────────────────────────────────────────
// Config compartilhada dos widgets: (1) modo combinado, com MÚLTIPLOS
// grupos simultâneos — cada um com sua própria posição/margem e sua
// própria lista de `members` (na ordem em que aparecem dentro do card).
// Um widget só pode pertencer a um grupo por vez — ao marcá-lo num grupo,
// ele é removido automaticamente de qualquer outro. (2) enabled/disabled
// por widget — independente de agrupamento, um widget desativado some de
// TODA parte (individual e dentro de qualquer grupo combinado).
//
// ids válidos: "clock", "todo", "calendar", "weather", "cpu", "ram",
// "gpu", "network", "disk", "system", "process", "bluetooth", "habits",
// "mediaplayer", "favorites"
//
// Formato de cada grupo:
//   { id, enabled, position, edgeMargin, offsetX, offsetY, columns,
//     memberColumns, memberFullWidth, memberScale, members, bgColor,
//     bgOpacity, borderColor, borderOpacity, borderWidth, radius,
//     columnMinWidth, columnSpacing, itemSpacing }
//   `offsetX`/`offsetY` são um ajuste fino (px) somado por cima da posição
//   já resolvida pelo grid de 9 pontos + edgeMargin — servem pra destravar
//   o card daquele grid quando os 9 pontos não bastam (ex: "quase
//   centralizado mas 30px mais pra cima"). Positivo = direita/baixo.
//   `columns` controla quantas colunas o card tem disponíveis.
//   `memberColumns` é um mapa widgetId → coluna (1-indexed) — cada membro
//   pode ser posicionado numa coluna específica; sem entrada = coluna 1.
//   `memberFullWidth` é um mapa widgetId → bool — widget marcado quebra
//   o fluxo de colunas naquele ponto e ocupa a largura inteira do card.
//   `memberScale` é um mapa widgetId → número (0.5 a 2.0) — escala visual
//   individual daquele widget dentro do card. Ausente ou undefined = 1.0
//   (tamanho normal). Widget maior/menor por causa da escala ainda entra
//   na conta de largura da coluna (todos da mesma coluna alinham pela
//   maior largura JÁ escalada) e na estimativa de altura do auto-balanço.
//   Cada coluna empilha só os SEUS membros pela própria altura (tipo
//   "alvenaria"/masonry) — não existe altura de linha compartilhada
//   entre colunas, então um widget pequeno nunca fica esticado só pra
//   bater com um grande na coluna vizinha.
//   `columnMinWidth` é um piso (px) pra largura de toda coluna — 0 (ou
//   ausente) = só o tamanho natural do maior widget dela, sem piso.
//   `columnSpacing`/`itemSpacing` são os espaçamentos horizontal (entre
//   colunas) e vertical (entre widgets empilhados na mesma coluna), em px.
//   `bgColor`/`borderColor` são chaves do singleton Colors (ex: "primary",
//   "on_surface", "outline", "background", "error").

Item {
  id: config
  visible: false

  property var groups: [] // [{ id, enabled, position, edgeMargin, members }]

  // Mapa widgetId → bool. Ausente ou undefined = ATIVO (default é sempre
  // ligado; só existe entrada explícita pra quem já foi desativado alguma
  // vez — assim widgets novos que eu adicionar no futuro já nascem
  // habilitados sem precisar tocar nesse JSON).
  property var enabled: ({})

  function isEnabled(widgetId) {
    return enabled[widgetId] !== false
  }

  function setEnabled(widgetId, value) {
    const e = Object.assign({}, enabled)
    e[widgetId] = value
    enabled = e
  }

  function _uid() {
    return "g" + Date.now().toString(36) + Math.floor(Math.random() * 1000)
  }

  function addGroup() {
    const g = groups.slice()
    g.push({
      id: _uid(), enabled: true, position: 4, edgeMargin: 48,
      offsetX: 0, offsetY: 0,
      columns: 1, memberColumns: {}, memberFullWidth: {}, memberScale: {},
      members: [],
      bgColor: "surface_container", bgOpacity: 0.55,
      borderColor: "outline_variant", borderOpacity: 0.4,
      borderWidth: 1, radius: 14,
      columnMinWidth: 0, columnSpacing: 20, itemSpacing: 20,
    })
    groups = g
  }

  function removeGroup(groupId) {
    groups = groups.filter(g => g.id !== groupId)
  }

  function _updateGroup(groupId, patch) {
    groups = groups.map(g => g.id === groupId ? Object.assign({}, g, patch) : g)
  }

  function setGroupEnabled(groupId, enabled)     { _updateGroup(groupId, { enabled }) }
  function setGroupPosition(groupId, position)   { _updateGroup(groupId, { position }) }
  function setGroupEdgeMargin(groupId, edgeMargin) { _updateGroup(groupId, { edgeMargin }) }
  function setGroupOffsetX(groupId, offsetX)     { _updateGroup(groupId, { offsetX }) }
  function setGroupOffsetY(groupId, offsetY)     { _updateGroup(groupId, { offsetY }) }
  function setGroupColumns(groupId, columns)     { _updateGroup(groupId, { columns }) }
  function setGroupBgColor(groupId, bgColor)         { _updateGroup(groupId, { bgColor }) }
  function setGroupBgOpacity(groupId, bgOpacity)     { _updateGroup(groupId, { bgOpacity }) }
  function setGroupBorderColor(groupId, borderColor) { _updateGroup(groupId, { borderColor }) }
  function setGroupBorderOpacity(groupId, borderOpacity) { _updateGroup(groupId, { borderOpacity }) }
  function setGroupBorderWidth(groupId, borderWidth) { _updateGroup(groupId, { borderWidth }) }
  function setGroupRadius(groupId, radius)           { _updateGroup(groupId, { radius }) }
  function setGroupColumnMinWidth(groupId, columnMinWidth) { _updateGroup(groupId, { columnMinWidth }) }
  function setGroupColumnSpacing(groupId, columnSpacing)   { _updateGroup(groupId, { columnSpacing }) }
  function setGroupItemSpacing(groupId, itemSpacing)       { _updateGroup(groupId, { itemSpacing }) }

  // Coluna (1-indexed) de um membro específico dentro do grupo. Widget
  // não assinalado explicitamente cai na coluna 1 por padrão.
  function setMemberColumn(groupId, widgetId, column) {
    const group = groups.find(g => g.id === groupId)
    if (!group) return
    const mc = Object.assign({}, group.memberColumns || {})
    mc[widgetId] = column
    _updateGroup(groupId, { memberColumns: mc })
  }

  function memberColumn(group, widgetId) {
    return (group.memberColumns && group.memberColumns[widgetId]) || 1
  }

  // Sobrescreve o mapa memberColumns inteiro de uma vez (usado pelo
  // auto-organizar, pra não disparar N escritas em sequência)
  function setGroupMemberColumns(groupId, memberColumns) {
    _updateGroup(groupId, { memberColumns })
  }

  // Escala individual (0.5–2.0) de um widget dentro do grupo. Sem entrada
  // explícita = 1.0 (tamanho normal).
  function setMemberScale(groupId, widgetId, scale) {
    const group = groups.find(g => g.id === groupId)
    if (!group) return
    const clamped = Math.max(0.5, Math.min(2.0, scale))
    const ms = Object.assign({}, group.memberScale || {})
    ms[widgetId] = clamped
    _updateGroup(groupId, { memberScale: ms })
  }

  function memberScale(group, widgetId) {
    const v = group.memberScale && group.memberScale[widgetId]
    return (v === undefined || v === null) ? 1.0 : v
  }

  // Estimativa de altura (px) de cada tipo de widget, só pra o
  // auto-organizar ter uma noção de "peso" ao distribuir — não precisa
  // ser exata, é só pra balancear razoavelmente. Widgets que eu não
  // conheço (ex: adicionados depois, como os seus habits/mediaplayer/
  // favorites) caem no valor padrão de 150.
  readonly property var _heightEstimate: ({
    clock: 90, todo: 220, calendar: 200, weather: 130,
    cpu: 176, ram: 110, gpu: 190, network: 150, disk: 110,
    system: 160, process: 170, bluetooth: 130,
  })

  // Auto-organiza os membros do grupo nas colunas disponíveis, tentando
  // deixar a altura TOTAL de cada coluna o mais parecida possível
  // (bin-packing guloso: o próximo widget sempre vai pra coluna mais
  // baixa até agora). Membros marcados "linha inteira" não entram nessa
  // conta (eles não pertencem a nenhuma coluna). Não mexe na ORDEM
  // dentro de cada coluna — essa ainda segue a ordem de `members`.
  function autoBalanceGroup(groupId) {
    const group = groups.find(g => g.id === groupId)
    if (!group) return
    const cols = group.columns || 1
    if (cols <= 1) return // com 1 coluna só, não tem o que balancear

    const fw = group.memberFullWidth || {}
    const candidates = group.members.filter(id => !fw[id])

    // peso de cada widget = altura estimada × sua própria escala — um
    // widget escalado pra 150% pesa 1.5x mais na hora de balancear
    const weight = (id) => (_heightEstimate[id] || 150) * memberScale(group, id)

    // maior primeiro deixa o guloso mais preciso
    const sorted = candidates.slice().sort((a, b) => weight(b) - weight(a))

    const colHeights = new Array(cols).fill(0)
    const mc = {}
    for (const id of sorted) {
      let minCol = 0
      for (let c = 1; c < cols; c++) {
        if (colHeights[c] < colHeights[minCol]) minCol = c
      }
      mc[id] = minCol + 1
      colHeights[minCol] += weight(id)
    }
    setGroupMemberColumns(groupId, mc)
  }

  // Widget "ocupa linha inteira" — quebra o empilhamento por coluna
  // naquele ponto: tudo que veio antes fecha suas colunas, o widget
  // aparece numa faixa sozinho ocupando a largura toda do card, e o que
  // vem depois recomeça colunas novas (balanceadas de novo).
  function setMemberFullWidth(groupId, widgetId, value) {
    const group = groups.find(g => g.id === groupId)
    if (!group) return
    const fw = Object.assign({}, group.memberFullWidth || {})
    fw[widgetId] = value
    _updateGroup(groupId, { memberFullWidth: fw })
  }

  function memberIsFullWidth(group, widgetId) {
    return !!(group.memberFullWidth && group.memberFullWidth[widgetId])
  }

  // Alterna widgetId dentro do grupo groupId. Se ele já estiver em outro
  // grupo, é removido de lá primeiro (associação é exclusiva).
  function toggleMember(groupId, widgetId) {
    const g = groups.map(x => Object.assign({}, x, { members: x.members.slice() }))
    const target = g.find(x => x.id === groupId)
    if (!target) return

    const idx = target.members.indexOf(widgetId)
    if (idx !== -1) {
      target.members.splice(idx, 1)
    } else {
      g.forEach(other => {
        if (other.id === groupId) return
        const i = other.members.indexOf(widgetId)
        if (i !== -1) other.members.splice(i, 1)
      })
      target.members.push(widgetId)
    }
    groups = g
  }

  function moveMember(groupId, widgetId, dir) {
    const group = groups.find(g => g.id === groupId)
    if (!group) return
    const m = group.members.slice()
    const idx = m.indexOf(widgetId)
    if (idx === -1) return
    const newIdx = idx + dir
    if (newIdx < 0 || newIdx >= m.length) return
    const tmp = m[idx]; m[idx] = m[newIdx]; m[newIdx] = tmp
    _updateGroup(groupId, { members: m })
  }

  // true se o widget está em ALGUM grupo ativo — Widget.qml individuais
  // continuam chamando isGrouped("clock") do jeito que já chamavam.
  function isGrouped(widgetId) {
    return groups.some(g => g.enabled && g.members.indexOf(widgetId) !== -1)
  }

  function groupForWidget(widgetId) {
    const g = groups.find(g => g.enabled && g.members.indexOf(widgetId) !== -1)
    return g ? g.id : ""
  }

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/WidgetLayout.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter

      // Campos legados (modo antigo, um único grupo) — mantidos só pra
      // migrar automaticamente um WidgetLayout.json de antes desta mudança.
      property bool groupEnabled: false
      property int position: 4
      property int edgeMargin: 48
      property var members: []

      property var groups: []
      property var enabled: ({})

      onGroupsChanged: {
        if (JSON.stringify(groups) !== JSON.stringify(config.groups))
          config.groups = groups
      }
      onEnabledChanged: {
        if (JSON.stringify(enabled) !== JSON.stringify(config.enabled))
          config.enabled = enabled
      }

      // Dispara depois que os campos legados forem lidos do JSON antigo;
      // se `groups` já veio populado (JSON novo) isso é um no-op.
      onMembersChanged: config._migrateLegacy()
    }
  }

  function _migrateLegacy() {
    if (config.groups.length === 0 && adapter.groups.length === 0 && adapter.members.length > 0) {
      config.groups = [{
        id: _uid(),
        enabled: adapter.groupEnabled,
        position: adapter.position,
        edgeMargin: adapter.edgeMargin,
        members: adapter.members.slice(),
      }]
      // limpa os campos legados pra não remigrar depois que o usuário
      // apagar o grupo manualmente
      adapter.members = []
      adapter.groupEnabled = false
    }
  }

  onGroupsChanged: {
    if (JSON.stringify(groups) !== JSON.stringify(adapter.groups))
      adapter.groups = groups
  }
  onEnabledChanged: {
    if (JSON.stringify(enabled) !== JSON.stringify(adapter.enabled))
      adapter.enabled = enabled
  }

  Connections {
    target: StateDir
    function onReadyChanged() {
      if (StateDir.ready) file.reload()
    }
  }

  Component.onCompleted: if (StateDir.ready) file.reload()
}
