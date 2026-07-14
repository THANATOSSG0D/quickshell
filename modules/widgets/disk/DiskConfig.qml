import QtQuick
import Quickshell
import Quickshell.Io

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  // Ponto de montagem PRINCIPAL — não tem campo de texto na UI ainda pra
  // trocar esse aqui especificamente (só os extras, abaixo, que têm),
  // mas dá pra editar direto no JSON em state/DiskWidget.json se quiser.
  property string mountPoint: "/"

  // Discos/pontos de montagem EXTRAS (ex: um HD externo em /mnt/hd) —
  // esses sim têm UI pra adicionar/remover na aba de config. Aparecem
  // como linhas compactas abaixo do disco principal.
  property var extraMounts: []

  function addMount(path) {
    const p = path.trim()
    if (p === "" || extraMounts.indexOf(p) !== -1 || p === mountPoint) return
    extraMounts = extraMounts.concat([p])
  }

  function removeMount(path) {
    extraMounts = extraMounts.filter(m => m !== path)
  }

  property int    fontSizeValue: 32
  property string colorValue: "primary"
  property string colorWrite: "outline"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  200
  property int fixedHeight: 110

  property bool showHistory: true
  property bool showIO:      true

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/DiskWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property string mountPoint: "/"
      property var    extraMounts: []

      property int    fontSizeValue: 32
      property string colorValue: "primary"
      property string colorWrite: "outline"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  200
      property int fixedHeight: 110

      property bool showHistory: true
      property bool showIO:      true

      onPositionChanged:      config.position      = position
      onEdgeMarginChanged:    config.edgeMargin    = edgeMargin
      onMountPointChanged:    config.mountPoint    = mountPoint
      onExtraMountsChanged: {
        if (JSON.stringify(extraMounts) !== JSON.stringify(config.extraMounts))
          config.extraMounts = extraMounts
      }
      onFontSizeValueChanged: config.fontSizeValue = fontSizeValue
      onColorValueChanged:    config.colorValue    = colorValue
      onColorWriteChanged:    config.colorWrite    = colorWrite
      onColorLabelChanged:    config.colorLabel    = colorLabel
      onColorLineChanged:     config.colorLine     = colorLine
      onFixedWidthChanged:    config.fixedWidth    = fixedWidth
      onFixedHeightChanged:   config.fixedHeight   = fixedHeight
      onShowHistoryChanged:   config.showHistory   = showHistory
      onShowIOChanged:        config.showIO        = showIO
    }
  }

  onPositionChanged:      adapter.position      = position
  onEdgeMarginChanged:    adapter.edgeMargin    = edgeMargin
  onMountPointChanged:    adapter.mountPoint    = mountPoint
  onExtraMountsChanged: {
    if (JSON.stringify(extraMounts) !== JSON.stringify(adapter.extraMounts))
      adapter.extraMounts = extraMounts
  }
  onFontSizeValueChanged: adapter.fontSizeValue = fontSizeValue
  onColorValueChanged:    adapter.colorValue    = colorValue
  onColorWriteChanged:    adapter.colorWrite    = colorWrite
  onColorLabelChanged:    adapter.colorLabel    = colorLabel
  onColorLineChanged:     adapter.colorLine     = colorLine
  onFixedWidthChanged:    adapter.fixedWidth    = fixedWidth
  onFixedHeightChanged:   adapter.fixedHeight   = fixedHeight
  onShowHistoryChanged:   adapter.showHistory   = showHistory
  onShowIOChanged:        adapter.showIO        = showIO

  Process {
    id: mkdirProc
    command: ["mkdir", "-p", Quickshell.shellDir + "/state"]
    onExited: {
      file.reload()
      // garante que o JSON existe no disco mesmo se o usuário nunca
      // mexer em nenhum slider/toggle desse widget — sem isso,
      // writeAdapter() só dispara quando alguma propriedade muda, e o
      // arquivo nunca chega a ser criado (fica warnando pra sempre)
      initTimer.start()
    }
  }

  Timer {
    id: initTimer
    interval: 300
    onTriggered: file.writeAdapter()
  }

  Component.onCompleted: mkdirProc.running = true
}
