pragma Singleton
import QtQuick

// TooltipSettings — ponte global (pragma Singleton) para os parâmetros
// COMPARTILHADOS por todos os tooltips de hover da barra: BarTooltip,
// ClockTooltip, MediaTooltip, NotifTooltip, QsTooltip, VolumeTooltip,
// WsTooltip.
//
// Por que existir: cada Tooltip acima é `pragma Singleton` (1 instância
// pra shell inteira), mas BarConfig vive dentro de BarState, que por sua
// vez é instanciado dentro de Bar.qml (não dá pra importar BarConfig
// diretamente de dentro de outro singleton). Bar.qml faz o binding
// reativo (via Binding{}) dessas 4 props a partir de barState.config —
// ver bloco "TooltipSettings" logo após "BarState { id: barState }".
//
// Props:
//   enabled  — liga/desliga TODOS os tooltips de uma vez
//   minWidth — largura mínima comum a todos (cada tooltip ainda pode
//              crescer além disso se o conteúdo precisar de mais espaço)
//   align    — "module" (padrão: tooltip aparece junto do item sob o
//              cursor, comportamento de sempre)
//            | "section" (centralizado na seção do módulo hoverado —
//              esquerda/centro/direita na horizontal, topo/meio/rodapé
//              na vertical — em vez do item específico. Cada tema marca
//              o container de cada seção com objectName "barSectionLeft"
//              /"barSectionCenter"/"barSectionRight"/"barSectionTop"/
//              "barSectionMiddle"/"barSectionBottom"; o tooltip sobe a
//              árvore de pais a partir do item hoverado até achar o
//              primeiro objectName que comece com "barSection")
//            | "bar" (tooltip sempre centralizado na barra inteira,
//              independente de qual item foi hoverado — sobe a árvore
//              de pais do item até achar o container raiz da barra,
//              objectName "barContentRoot", setado em Bar.qml)
//   offset   — px extra de distância entre a barra e o tooltip (0 =
//              comportamento original, colado na borda da barra)
//   contentPadding — padding horizontal somado ao implicitWidth do
//              conteúdo antes do Math.max(minWidth, ...). Antes cada um
//              dos 7 tooltips tinha um número mágico diferente (16/28/28/
//              24/26/20/24), então o mesmo texto saía com larguras
//              ligeiramente diferentes dependendo de qual módulo mostrou
//              o tooltip. Agora é um valor único — mexeu aqui, os 7
//              ficam consistentes.
QtObject {
  property bool   enabled:        true
  property int    minWidth:       160
  property string align:          "module"
  property int    offset:         0
  property int    contentPadding: 24
}
