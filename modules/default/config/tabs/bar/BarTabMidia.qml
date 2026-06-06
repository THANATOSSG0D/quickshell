import QtQuick
import QtQuick.Layouts
import '../../components' as C

C.CfgScroll {
  id: root

  required property string localMpTextMode
  required property int    localMpScrollSpeed
  required property int    localMpScrollWidth
  required property bool   localMpBgEnabled
  required property string pkMpBgColor
  required property string pkMpBgActive
  required property string pkMpText
  required property string pkMpDim
  required property string pkMpTextActive
  required property string pkMpDimActive
  required property var    colors
  required property color  colorAccent
  required property color  colorTextDim
  required property color  colorText
  required property color  colorProgressBg
  required property color  colorSidebar
  required property color  colorDivider
  required property var    overlay

  signal changed(var opts)

  C.CfgSection { title: "MODO DE TEXTO"; colorTextDim: root.colorTextDim }
  Row {
    spacing: 6
    Repeater {
      model: [
        { id: "artistAndTitle", label: "Artista + Título" },
        { id: "title",          label: "Só título"        },
        { id: "artist",         label: "Só artista"       },
      ]
      delegate: C.CfgChip {
        required property var modelData
        label: modelData.label; active: root.localMpTextMode === modelData.id
        colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
        onChipClicked: root.changed({ mpTextMode: modelData.id })
      }
    }
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "SCROLL"; colorTextDim: root.colorTextDim }

  C.CfgSlider {
    label: "Velocidade"; value: root.localMpScrollSpeed
    from: 10; to: 120; step: 5; unit: "px/s"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ mpScrollSpeed: v })
  }
  C.CfgSlider {
    label: "Largura"; value: root.localMpScrollWidth
    from: 60; to: 300; step: 10; unit: "px"
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorProgressBg: root.colorProgressBg
    onMoved: (v) => root.changed({ mpScrollWidth: v })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "FUNDO"; colorTextDim: root.colorTextDim }

  C.CfgToggle {
    label: "Fundo habilitado"; checked: root.localMpBgEnabled
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    onToggled: root.changed({ mpBgEnabled: !root.localMpBgEnabled })
  }

  C.CfgDiv { colorDivider: root.colorDivider }
  C.CfgSection { title: "CORES"; colorTextDim: root.colorTextDim }

  C.CfgPalette {
    label: "Fundo"; value: root.pkMpBgColor; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabMidia] pkMpBgColor →", v); root.changed({ pkMpBgColor: v }) }
  }
  C.CfgPalette {
    label: "Fundo ativo"; value: root.pkMpBgActive; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabMidia] pkMpBgActive →", v); root.changed({ pkMpBgActive: v }) }
  }
  C.CfgPalette {
    label: "Texto"; value: root.pkMpText; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabMidia] pkMpText →", v); root.changed({ pkMpText: v }) }
  }
  C.CfgPalette {
    label: "Dim"; value: root.pkMpDim; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabMidia] pkMpDim →", v); root.changed({ pkMpDim: v }) }
  }
  C.CfgPalette {
    label: "Texto ativo"; value: root.pkMpTextActive; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabMidia] pkMpTextActive →", v); root.changed({ pkMpTextActive: v }) }
  }
  C.CfgPalette {
    label: "Dim ativo"; value: root.pkMpDimActive; colors: root.colors; overlay: root.overlay
    colorAccent: root.colorAccent; colorTextDim: root.colorTextDim
    colorText: root.colorText; colorSidebar: root.colorSidebar; colorDivider: root.colorDivider
    onEdited: (v) => { console.log("[BarTabMidia] pkMpDimActive →", v); root.changed({ pkMpDimActive: v }) }
  }
}
