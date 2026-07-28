import QtQuick
import Quickshell
import Quickshell.Io

// ScreenLockConfig — API central de leitura/escrita das configs do lock screen.
//
// Mora no MESMO módulo local "screenlock" que ScreenLock.qml/LockContent.qml
// (ver qmldir dessa pasta) — por isso NÃO importa "qs": o singleton Colors já
// está disponível automaticamente (é o mesmo módulo, resolvido via symlink
// pro Colors.qml da raiz).
//
// Importante: o lock screen roda como processo ISOLADO (`qs -c` disparado
// pelo script scripts/screenlock), então essa config só precisa persistir em
// disco — não tem "live sync" com a instância principal, e não precisa: cada
// bloqueio é um processo novo que lê o JSON do zero. Quem edita ao vivo é a
// aba do ConfigWindow, que roda na instância PRINCIPAL usando essa MESMA
// classe (mesmo arquivo state/ScreenLock.json).
//
// LEITURA:  config.get("dpmsTimeoutMs", 90000)
// ESCRITA:  config.set("dpmsTimeoutMs", 60000)
// BOTÕES:   config.getButtons() / config.updateButton(id, {...}) / etc.
// GRUPOS:   config.getGroups() / config.addGroup() / config.toggleMember(...) / etc.

Item {
  id: root
  visible: false

  // Caminho baseado em Quickshell.shellDir — funciona IGUAL nos dois
  // processos (shell principal e o isolado do lock) DESDE QUE exista o
  // symlink `modules/default/screenlock/state -> ../../../state` (mesma
  // ideia do Colors.qml já ser symlink). Sem esse link, cada processo
  // aponta pra uma pasta "state" diferente e as configs feitas na UI nunca
  // chegam no lock de verdade — e o mesmo vale pros widgets reaproveitados
  // (TodoConfig, CalendarConfig, HabitsConfig... todos usam shellDir).
  property string jsonPath: Quickshell.shellDir + "/state/ScreenLock.json"
  property bool   configLoaded: false

  // Cache local — única fonte que get()/getButtons()/getGroups() leem
  // (mesmo motivo do PowerMenuConfig: ler adapter.xxx direto dentro de
  // outro binding causa "Binding loop detected").
  property var _buttonsCache:  []
  property var _settingsCache: ({})
  property var _groupsCache:   []

  signal buttonsChanged()
  signal groupsChanged()

  // ══════════════════════════════════════════════════════════════════════
  // DEFAULTS
  // ══════════════════════════════════════════════════════════════════════
  readonly property string _powerScript: Quickshell.env("HOME") + "/.config/hypr/scripts/power.sh"

  readonly property var defaultButtons: [
    { id: "dpms",     icon: "󰹑", label: "Apagar tela", action: "__displayOff",                   confirm: false, visible: true },
    { id: "suspend",  icon: "󰒲", label: "Suspender",   action: root._powerScript + " suspend",  confirm: false, visible: true },
    { id: "reboot",   icon: "󰑓", label: "Reiniciar",   action: root._powerScript + " reboot",   confirm: true,  visible: true },
    { id: "shutdown", icon: "󰐥", label: "Desligar",    action: root._powerScript + " shutdown", confirm: true,  visible: true },
  ]

  // ── Grupos — mesmo conceito do WidgetLayoutConfig do desktop (múltiplos
  // grupos simultâneos, cada um com posição/margem/offset/colunas/aparência
  // própria, mais uma lista `members` na ordem de empilhamento). A grande
  // diferença: aqui os "membros" possíveis incluem 3 ids especiais além dos
  // widgets normais — "clock" (relógio+data), "auth" (cápsula de senha +
  // usuário) e "buttons" (botões de energia). Um membro só pode estar em UM
  // grupo por vez (mesma regra do toggleMember do desktop).
  //
  // Default: 2 grupos, reproduzindo o visual de sempre — um centralizado
  // com relógio+senha, outro embaixo com os botões.
  readonly property var defaultGroups: [
    {
      id: "default-main", position: 4, edgeMargin: 48, offsetX: 0, offsetY: -20,
      columns: 1, memberColumns: {}, members: ["clock", "auth"],
      bgEnabled: false, bgColor: "surface_container", bgOpacity: 0.55,
      borderColor: "outline_variant", borderOpacity: 0.4, borderWidth: 1, radius: 16,
      columnSpacing: 20, itemSpacing: 26, padding: 20,
    },
    {
      id: "default-buttons", position: 7, edgeMargin: 40, offsetX: 0, offsetY: 0,
      columns: 1, memberColumns: {}, members: ["buttons"],
      bgEnabled: false, bgColor: "surface_container", bgOpacity: 0.45,
      borderColor: "outline_variant", borderOpacity: 0.4, borderWidth: 1, radius: 22,
      columnSpacing: 20, itemSpacing: 10, padding: 12,
    },
  ]

  readonly property var defaultSettings: ({
    // comportamento
    dpmsTimeoutMs:     90000,  // tempo de inatividade até apagar a tela
    pamWatchdogMs:      8000,  // timeout de segurança do PAM antes de abortar
    confirmTimeoutMs:   4000,  // tempo até cancelar confirmação pendente num botão de energia
    shakeOnFail:         true, // "balançar" a cápsula de senha ao errar
    showUsername:        true,
    showFailCount:        true,  // "Senha incorreta (N tentativas)" a partir da 3ª

    // wallpaper de fundo
    useSystemWallpaper: true,   // true = usa o cache do ml4w (comportamento atual)
    customWallpaperPath: "",    // usado só quando useSystemWallpaper = false

    // tamanhos (posição agora é por GRUPO — ver getGroups/addGroup/etc.)
    clockPixelSize:    96,
    datePixelSize:      16,
    capsuleWidth:      320,
    capsuleHeight:      56,
    buttonSize:         44,
    buttonSpacing:      10,

    // animação
    fadeInMs:          500,
    shakeMs:             50,

    // cores (tokens de paleta — resolvidos via Colors[token], mesmo padrão
    // do PowerMenuConfig)
    colorClockText:        "on_surface",
    colorDateText:         "on_surface_variant",
    colorAccent:           "primary",
    colorError:            "error",
    colorRunning:          "tertiary",
    colorCapsuleBg:        "surface_container",
    colorButtonBg:         "surface_container_high",
    scrimOpacity:          0.55,
  })

  // ── Resolução de token de paleta → cor real (mesmo padrão do BarConfig/PowerMenuConfig) ──
  function resolve(paletteKey) {
    if (!paletteKey) return Qt.color("transparent")
    return Colors[paletteKey] !== undefined ? Colors[paletteKey] : Qt.color("transparent")
  }

  // ══════════════════════════════════════════════════════════════════════
  // API PÚBLICA — settings (get/set genérico, flat)
  // ══════════════════════════════════════════════════════════════════════
  function get(key, def) {
    var s = root._settingsCache
    if (s && s[key] !== undefined) return s[key]
    if (root.defaultSettings[key] !== undefined) return root.defaultSettings[key]
    return def
  }

  function getColor(key) {
    return resolve(get(key, root.defaultSettings[key]))
  }

  function set(key, value) {
    var s = {}
    try { s = JSON.parse(JSON.stringify(root._settingsCache || {})) } catch(e) {}
    s[key] = value
    root._settingsCache = s
    adapter.settings = s
    file.writeAdapter()
  }

  function resetSettings() {
    root._settingsCache = {}
    adapter.settings = {}
    file.writeAdapter()
  }

  // ══════════════════════════════════════════════════════════════════════
  // API PÚBLICA — botões de energia (CRUD)
  // ══════════════════════════════════════════════════════════════════════
  function getButtons() {
    var b = root._buttonsCache
    if (!b || b.length === 0) return root.defaultButtons
    return b
  }

  function setButtons(list) {
    root._buttonsCache = list
    adapter.buttons = list
    file.writeAdapter()
    root.buttonsChanged()
  }

  function addButton(btn) {
    var list = getButtons().slice()
    if (!btn.id) btn.id = "custom_" + Date.now()
    list.push(btn)
    setButtons(list)
  }

  function removeButton(id) {
    var list = getButtons().filter(function(b) { return b.id !== id })
    setButtons(list)
  }

  function updateButton(id, patch) {
    var list = getButtons().slice()
    for (var i = 0; i < list.length; i++) {
      if (list[i].id === id) {
        var merged = {}
        for (var k  in list[i]) merged[k] = list[i][k]
        for (var k2 in patch)   merged[k2] = patch[k2]
        list[i] = merged
        break
      }
    }
    setButtons(list)
  }

  function moveButton(fromIdx, toIdx) {
    var list = getButtons().slice()
    if (fromIdx < 0 || fromIdx >= list.length) return
    if (toIdx   < 0 || toIdx   >= list.length) return
    var item = list.splice(fromIdx, 1)[0]
    list.splice(toIdx, 0, item)
    setButtons(list)
  }

  function resetButtons() {
    setButtons([])
  }

  // ══════════════════════════════════════════════════════════════════════
  // API PÚBLICA — grupos (CRUD) — mesmo modelo do WidgetLayoutConfig
  // ══════════════════════════════════════════════════════════════════════
  function getGroups() {
    var g = root._groupsCache
    if (!g || g.length === 0) return root.defaultGroups
    return g
  }

  function setGroups(list) {
    root._groupsCache = list
    adapter.groups = list
    file.writeAdapter()
    root.groupsChanged()
  }

  function _uid() {
    return "g" + Date.now().toString(36) + Math.floor(Math.random() * 1000)
  }

  function addGroup() {
    var g = getGroups().slice()
    g.push({
      id: _uid(), position: 4, edgeMargin: 48, offsetX: 0, offsetY: 0,
      columns: 1, memberColumns: {}, members: [],
      bgEnabled: false, bgColor: "surface_container", bgOpacity: 0.55,
      borderColor: "outline_variant", borderOpacity: 0.4, borderWidth: 1, radius: 14,
      columnSpacing: 20, itemSpacing: 20, padding: 20,
    })
    setGroups(g)
  }

  function removeGroup(groupId) {
    setGroups(getGroups().filter(function(g) { return g.id !== groupId }))
  }

  function _updateGroup(groupId, patch) {
    var list = getGroups().map(function(g) {
      if (g.id !== groupId) return g
      var merged = {}
      for (var k  in g)     merged[k] = g[k]
      for (var k2 in patch) merged[k2] = patch[k2]
      return merged
    })
    setGroups(list)
  }

  function setGroupField(groupId, key, value) {
    var patch = {}
    patch[key] = value
    _updateGroup(groupId, patch)
  }

  // Alterna memberId dentro do grupo groupId. Se já estiver em outro grupo,
  // é removido de lá primeiro (associação é exclusiva — mesma regra do
  // WidgetLayoutConfig do desktop).
  function toggleMember(groupId, memberId) {
    var list = getGroups().map(function(g) {
      var m = {}
      for (var k in g) m[k] = g[k]
      m.members = g.members.slice()
      return m
    })
    var target = list.find(function(g) { return g.id === groupId })
    if (!target) return

    var idx = target.members.indexOf(memberId)
    if (idx !== -1) {
      target.members.splice(idx, 1)
    } else {
      list.forEach(function(other) {
        if (other.id === groupId) return
        var i = other.members.indexOf(memberId)
        if (i !== -1) other.members.splice(i, 1)
      })
      target.members.push(memberId)
    }
    setGroups(list)
  }

  function moveMember(groupId, memberId, dir) {
    var group = getGroups().find(function(g) { return g.id === groupId })
    if (!group) return
    var m = group.members.slice()
    var idx = m.indexOf(memberId)
    if (idx === -1) return
    var newIdx = idx + dir
    if (newIdx < 0 || newIdx >= m.length) return
    var tmp = m[idx]; m[idx] = m[newIdx]; m[newIdx] = tmp
    setGroupField(groupId, "members", m)
  }

  function setMemberColumn(groupId, memberId, column) {
    var group = getGroups().find(function(g) { return g.id === groupId })
    if (!group) return
    var mc = {}
    for (var k in (group.memberColumns || {})) mc[k] = group.memberColumns[k]
    mc[memberId] = column
    setGroupField(groupId, "memberColumns", mc)
  }

  function memberColumn(group, memberId) {
    return (group.memberColumns && group.memberColumns[memberId]) || 1
  }

  // Em qual grupo (id) um membro está agora — "" se não estiver em nenhum.
  function groupForMember(memberId) {
    var g = getGroups().find(function(g) { return g.members.indexOf(memberId) !== -1 })
    return g ? g.id : ""
  }

  function resetGroups() {
    setGroups([])
  }

  // ══════════════════════════════════════════════════════════════════════
  // FILE — state/ScreenLock.json
  // ══════════════════════════════════════════════════════════════════════
  FileView {
    id: file
    path:         root.jsonPath
    watchChanges: false

    JsonAdapter {
      id: adapter
      property var buttons:  []
      property var settings: ({})
      property var groups:   []

      onButtonsChanged:  { root._buttonsCache = buttons; root.buttonsChanged() }
      onSettingsChanged: { root._settingsCache = settings }
      onGroupsChanged:   { root._groupsCache = groups; root.groupsChanged() }
    }

    onLoaded: {
      root.configLoaded  = true
      root._buttonsCache  = adapter.buttons
      root._settingsCache = adapter.settings
      root._groupsCache   = adapter.groups
    }
    onLoadFailed: {
      root.configLoaded = true
    }
  }

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
  }
  Component.onCompleted: mkdirProc.running = true
}
