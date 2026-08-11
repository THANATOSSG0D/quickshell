import QtQuick
import Quickshell
import Quickshell.Io
import qs.singletons

// ── MediaPlayerConfig ────────────────────────────────────────────────────
// Config do widget de player único: mostra o player MPRIS ativo (ou o
// preferido, se `preferredPlayerId` bater com identity/desktopEntry). Se
// nenhum player estiver rodando, mostra um placeholder que abre o app via
// `launchCommand` ao ser clicado. Mesmo esqueleto de BluetoothConfig.

Item {
  id: config
  visible: false

  property int position: 4
  property int edgeMargin: 48

  property int    fontSizeValue: 14
  property string colorValue: "primary"
  property string colorLabel: "on_surface"
  property string colorLine:  "outline"

  property int fixedWidth:  260
  property int fixedHeight: 190

  property bool showCoverArt: true
  property bool showProgress: true
  property bool showShuffleRepeat: true
  property bool showVisualizer:    true
  property bool rotateCoverArt:    true
  property bool marqueeText:       true

  // identity ou desktopEntry do player preferido; vazio = automático
  // (prioriza um player tocando agora, senão pega o primeiro disponível)
  property string preferredPlayerId: ""

  // comando executado (via `sh -c`) quando nenhum player está aberto
  property string launchCommand: ""
  property string appLabel: "Media Player"

  FileView {
    id: file
    path: Quickshell.shellDir + "/state/MediaPlayerWidget.json"
    watchChanges: true
    onFileChanged: reload()
    onAdapterUpdated: writeAdapter()

    JsonAdapter {
      id: adapter
      property int position:   4
      property int edgeMargin: 48

      property int    fontSizeValue: 14
      property string colorValue: "primary"
      property string colorLabel: "on_surface"
      property string colorLine:  "outline"

      property int fixedWidth:  260
      property int fixedHeight: 190

      property bool showCoverArt: true
      property bool showProgress: true
      property bool showShuffleRepeat: true
      property bool showVisualizer:    true
      property bool rotateCoverArt:    true
      property bool marqueeText:       true

      property string preferredPlayerId: ""
      property string launchCommand: ""
      property string appLabel: "Media Player"

      onPositionChanged:          config.position          = position
      onEdgeMarginChanged:        config.edgeMargin        = edgeMargin
      onFontSizeValueChanged:     config.fontSizeValue     = fontSizeValue
      onColorValueChanged:        config.colorValue        = colorValue
      onColorLabelChanged:        config.colorLabel        = colorLabel
      onColorLineChanged:         config.colorLine         = colorLine
      onFixedWidthChanged:        config.fixedWidth        = fixedWidth
      onFixedHeightChanged:       config.fixedHeight       = fixedHeight
      onShowCoverArtChanged:      config.showCoverArt      = showCoverArt
      onShowProgressChanged:      config.showProgress      = showProgress
      onShowShuffleRepeatChanged: config.showShuffleRepeat = showShuffleRepeat
      onShowVisualizerChanged:    config.showVisualizer    = showVisualizer
      onRotateCoverArtChanged:    config.rotateCoverArt    = rotateCoverArt
      onMarqueeTextChanged:       config.marqueeText       = marqueeText
      onPreferredPlayerIdChanged: config.preferredPlayerId = preferredPlayerId
      onLaunchCommandChanged:     config.launchCommand     = launchCommand
      onAppLabelChanged:          config.appLabel          = appLabel
    }
  }

  onPositionChanged:          adapter.position          = position
  onEdgeMarginChanged:        adapter.edgeMargin        = edgeMargin
  onFontSizeValueChanged:     adapter.fontSizeValue     = fontSizeValue
  onColorValueChanged:        adapter.colorValue        = colorValue
  onColorLabelChanged:        adapter.colorLabel        = colorLabel
  onColorLineChanged:         adapter.colorLine         = colorLine
  onFixedWidthChanged:        adapter.fixedWidth        = fixedWidth
  onFixedHeightChanged:       adapter.fixedHeight       = fixedHeight
  onShowCoverArtChanged:      adapter.showCoverArt      = showCoverArt
  onShowProgressChanged:      adapter.showProgress      = showProgress
  onShowShuffleRepeatChanged: adapter.showShuffleRepeat = showShuffleRepeat
  onShowVisualizerChanged:    adapter.showVisualizer    = showVisualizer
  onRotateCoverArtChanged:    adapter.rotateCoverArt    = rotateCoverArt
  onMarqueeTextChanged:       adapter.marqueeText       = marqueeText
  onPreferredPlayerIdChanged: adapter.preferredPlayerId = preferredPlayerId
  onLaunchCommandChanged:     adapter.launchCommand     = launchCommand
  onAppLabelChanged:          adapter.appLabel          = appLabel

  Timer {
    id: initTimer
    interval: 300
    onTriggered: file.writeAdapter()
  }

  // garante que o JSON existe no disco mesmo se o usuário nunca
  // mexer em nenhum slider/toggle desse widget — sem isso,
  // writeAdapter() só dispara quando alguma propriedade muda, e o
  // arquivo nunca chega a ser criado (fica warnando pra sempre)
  Component.onCompleted: StateDir.whenReady(() => {
    file.reload()
    initTimer.start()
  })
}
