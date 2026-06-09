import QtQuick
import '../../components' as C

C.CfgScroll {
  id: root
  required property var   config
  required property var   overlay
  required property var   colors
  required property color colorAccent
  required property color colorTextDim
  required property color colorText
  required property color colorDivider
  required property color colorSidebar
  required property color colorProgressBg

  signal changed(var opts)
  function g(key) { return config ? config[key] : undefined }

  C.CfgSection { title: "DIMENSÕES"; colorTextDim: root.colorTextDim }
  C.CfgSlider {
    label: "Tamanho"; value: root.g("barSize") || 30
    from: 20; to: 60; step: 2; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ barSize: v })
  }
  C.CfgSlider {
    label: "Margem"; value: root.g("barMargin") || 3
    from: 0; to: 20; step: 1; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ barMargin: v })
  }
  C.CfgSlider {
    label: "Largura pílula"; value: root.g("pillWidth") || 400
    from: 200; to: 1400; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ pillWidth: v })
  }
  C.CfgSlider {
    label: "Espaçamento mín."; value: root.g("pillMinSpacing") || 20
    from: 0; to: 100; step: 5; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ pillMinSpacing: v })
  }
}
