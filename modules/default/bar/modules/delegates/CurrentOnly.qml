import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "." as Comp

// ════════════════════════════════════════════════════════════════════════
// CURRENT ONLY — só mostra os ícones da workspace ATIVA.
//
// Reaproveita o Icons.qml por dentro (mesmo lookup de ícone/sorting),
// mas só para a workspace ativa. Toda workspace INATIVA colapsa pra
// 0x0 — não reserva espaço nenhum no GridLayout do módulo (ver
// Workspaces.qml: implicitWidth/Height do wrapper vêm direto do
// delegate, então 0 aqui = 0 lá).
//
// Resultado prático: o módulo de workspaces vira só "os ícones da
// janela que eu tô usando agora", sem números/pontos pras outras.
//
// O Loader só fica `active` quando a workspace é a ativa — as
// inativas nem pagam o custo do lookup de ícone (que só importa
// quando ela virar a atual).
// ════════════════════════════════════════════════════════════════════════

Item {
  id: root

  property var modelData: null

  property bool   isHorizontal: true
  property int    iconSize:        18
  property bool   monochrome:      false
  property color  monoColor:       "white"
  property color  monoColorActive: "red"
  property int    iconSpacing:     3
  property string sortOrder:       "position"
  property int    barPosition:     2
  property bool   showTooltip:     true
  property color  urgentColor:     "#f38ba8"

  readonly property bool _wsActive: modelData ? modelData.active : false

  // Inativa → 0x0 (não empurra ninguém no layout).
  // Ativa   → tamanho real do Icons.qml carregado dentro do Loader.
  implicitWidth:  (root._wsActive && iconsLoader.item) ? iconsLoader.item.implicitWidth  : 0
  implicitHeight: (root._wsActive && iconsLoader.item) ? iconsLoader.item.implicitHeight : 0

  Loader {
    id: iconsLoader
    anchors.left: parent.left
    anchors.top:  parent.top
    active: root._wsActive
    sourceComponent: iconsComp
  }

  Component {
    id: iconsComp
    Comp.Icons {}
  }

  Binding { target: iconsLoader.item; property: "modelData";       value: root.modelData;       when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "isHorizontal";    value: root.isHorizontal;    when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "iconSize";        value: root.iconSize;        when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "monochrome";      value: root.monochrome;      when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "monoColor";       value: root.monoColor;       when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "monoColorActive"; value: root.monoColorActive; when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "iconSpacing";     value: root.iconSpacing;     when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "sortOrder";       value: root.sortOrder;       when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "barPosition";     value: root.barPosition;     when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "showTooltip";     value: root.showTooltip;     when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "showNumber";      value: false;                when: iconsLoader.item !== null }
  Binding { target: iconsLoader.item; property: "urgentColor";     value: root.urgentColor;     when: iconsLoader.item !== null }
}
