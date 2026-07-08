pragma Singleton
import QtQuick

// TooltipSettings — fallback/defaults GLOBAIS para os 7 tooltips de hover
// da barra: BarTooltip, ClockTooltip, MediaTooltip, NotifTooltip,
// QsTooltip, VolumeTooltip, WsTooltip.
//
// Por que existir: cada Tooltip acima é `pragma Singleton` (1 instância
// pra shell inteira). A config de verdade é por PAINEL (bar e dock têm
// cada um a sua, ver Bar.qml — Loader "barContentRoot" expõe
// cfgTooltipEnabled/MinWidth/MaxWidth/Align/Offset a partir do próprio
// barState.config daquela instância). Cada tooltip resolve isso em
// runtime com a função _cfg(startItem, key, default), que sobe a árvore
// de pais a partir do item hoverado até achar o barContentRoot do
// painel a que ele pertence. Os valores aqui em TooltipSettings só
// entram em jogo como default caso _cfg não encontre nenhum
// barContentRoot acima do item (não deveria acontecer em uso normal).
//
// Props:
//   enabled  — liga/desliga TODOS os tooltips de uma vez
//   minWidth — largura mínima (o conteúdo pode empurrar além disso se
//              precisar de mais espaço, até o teto de maxWidth)
//   maxWidth — largura máxima — a partir daqui o conteúdo passa a
//              elidir (título/nome de uma linha só) ou quebrar linha
//              (texto multi-palavra, ex: corpo de notificação) em vez
//              de continuar empurrando a caixa. Sem isso um nome de
//              música/notificação muito grande deixava o tooltip do
//              tamanho da tela inteira.
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
//              conteúdo antes do Math.max(minWidth, ...). Um valor
//              único compartilhado pelos 7 tooltips, pra manter a
//              largura consistente entre eles.
QtObject {
  property bool   enabled:        true
  property int    minWidth:       160
  property int    maxWidth:       320
  property string align:          "module"
  property int    offset:         0
  property int    contentPadding: 24
}
