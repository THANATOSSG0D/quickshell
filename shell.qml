import Quickshell
import "modules/widgets/clock"
import "modules/default/bar"
import './modules/default/osd' as OsdModule

Scope {
  ClockWidget {}

  // OsdModule.Osd instancia o OsdService internamente (id: osdService).
  // Precisamos passar essa referência ao Bar para que Volume.qml e
  // MediaPlayer.qml possam notificar o OSD diretamente, sem IPC externo.
  OsdModule.Osd {
    id: osd
  }

  Bar {
    id: bar
    // Injeta o OsdService assim que ambos estiverem prontos
    osdService: osd.osdService
  }
}
