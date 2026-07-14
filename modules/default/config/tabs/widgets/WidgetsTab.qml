import QtQuick

// ── WidgetsTab ────────────────────────────────────────────────────────────
// Router da aba "Widgets" do ConfigWindow. A ordem dos cases tem que bater
// com a ordem de _allModules["widgets"].subtabs em ConfigWindow.qml:
//   0 Relógio · 1 Lista de tarefas · 2 Calendário · 3 Clima ·
//   4 CPU · 5 RAM · 6 GPU · 7 Rede · 8 Disco · 9 Sistema · 10 Processos ·
//   11 Bluetooth · 12 Combinar
//
// Cada sub-aba (WidgetsTabClock/Todo/Calendar/Weather/CPU/RAM/GPU/Network/
// Disk/System/Process/Bluetooth.qml, mesma pasta) abre sua PRÓPRIA
// instância do Config daquele widget — sincroniza com a instância dentro
// do respectivo Widget.qml pelo mesmo JSON em state/, via FileView +
// watchChanges. Não precisa passar nada pelo shell.qml.

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

  anchors.fill: parent

  // Ordem tem que bater com _allModules["widgets"].subtabs em ConfigWindow.qml:
  //   0 Relógio · 1 Lista de tarefas · 2 Calendário · 3 Clima ·
  //   4 CPU · 5 RAM · 6 GPU · 7 Rede · 8 Disco · 9 Sistema · 10 Processos ·
  //   11 Bluetooth · 12 Combinar

  Loader {
    id: subLoader
    anchors.fill: parent
    sourceComponent: {
      switch (root.activeSubtab) {
        case 0:  return _clockTab
        case 1:  return _todoTab
        case 2:  return _calendarTab
        case 3:  return _weatherTab
        case 4:  return _cpuTab
        case 5:  return _ramTab
        case 6:  return _gpuTab
        case 7:  return _networkTab
        case 8:  return _diskTab
        case 9:  return _systemTab
        case 10: return _processTab
        case 11: return _bluetoothTab
        case 12: return _combineTab
        default: return _clockTab
      }
    }
  }

  Component {
    id: _clockTab
    WidgetsTabClock {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _todoTab
    WidgetsTabTodo {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _calendarTab
    WidgetsTabCalendar {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _weatherTab
    WidgetsTabWeather {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _cpuTab
    WidgetsTabCPU {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _ramTab
    WidgetsTabRAM {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _gpuTab
    WidgetsTabGPU {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _networkTab
    WidgetsTabNetwork {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _diskTab
    WidgetsTabDisk {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _systemTab
    WidgetsTabSystem {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _processTab
    WidgetsTabProcess {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _bluetoothTab
    WidgetsTabBluetooth {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
  Component {
    id: _combineTab
    WidgetsTabCombine {
      overlay: root.overlay; colors: root.colors
      colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
      colorText: root.colorText; colorDivider: root.colorDivider
      colorSidebar: root.colorSidebar; colorProgressBg: root.colorProgressBg
    }
  }
}
