pragma Singleton
import QtQuick

// TooltipSettings — fallback/defaults GLOBAIS para os 7 tooltips de hover
// da barra: BarTooltip, ClockTooltip, MediaTooltip, NotifTooltip,
// QsTooltip, VolumeTooltip, WsTooltip.
//
// Por que existir: cada Tooltip acima é `pragma Singleton` (1 instância
// pra shell inteira). A config de verdade é por PAINEL (bar e dock têm
// cada um a sua, ver Bar.qml — Loader "barContentRoot" expõe
// cfgTooltipEnabled/WidthMode/MaxWidth/FixedWidth/Align/Offset a partir
// do próprio barState.config daquela instância). Cada tooltip resolve
// isso em runtime com a função _cfg(startItem, key, default), que sobe a
// árvore de pais a partir do item hoverado até achar o barContentRoot do
// painel a que ele pertence. Os valores aqui em TooltipSettings só
// entram em jogo como default caso _cfg não encontre nenhum
// barContentRoot acima do item (não deveria acontecer em uso normal).
//
// Props:
//   enabled   — liga/desliga TODOS os tooltips de uma vez
//   widthMode — "auto"  → o tooltip encaixa na largura do conteúdo,
//                         crescendo só até o teto de maxWidth (nunca
//                         mais que isso, mesmo com um nome de música/
//                         notificação enorme)
//             | "fixed" → o tooltip usa sempre fixedWidth, não importa
//                         o conteúdo — texto de uma linha elide, texto
//                         multi-palavra (ex: corpo de notificação) quebra
//                         linha dentro dessa largura
//   maxWidth   — teto de segurança usado só no modo "auto"
//   fixedWidth — largura única usada só no modo "fixed"
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
//              conteúdo antes de entrar no resolveWidth(...). Um valor
//              único compartilhado pelos 7 tooltips, pra manter a
//              largura consistente entre eles.
QtObject {
  property bool   enabled:        true
  property string widthMode:      "auto"  // "auto" | "fixed"
  property int    maxWidth:       320
  property int    fixedWidth:     220
  property string align:          "module"
  property int    offset:         0
  property int    contentPadding: 24

  // Resolve a largura da caixa do tooltip conforme o modo:
  //   "fixed" → sempre fixedWidth, ignora o conteúdo completamente
  //   "auto"  → o quanto o conteúdo precisar (naturalWidth), até o
  //             teto maxWidth — passe Infinity como naturalWidth
  //             quando só quiser o teto em si (ex: largura de elide
  //             de um texto que ainda não tem tamanho natural
  //             conhecido de antemão)
  function resolveWidth(mode, fixedWidth, maxWidth, naturalWidth) {
    return mode === "fixed" ? fixedWidth : Math.min(maxWidth, naturalWidth)
  }
}
