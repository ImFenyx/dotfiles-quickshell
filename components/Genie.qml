import QtQuick

// Efeito "magic lamp" (genie) do macOS/KDE: o painel nasce de um ponto de
// origem (a linha do menu pai), vira um funil e se abre ate o tamanho final;
// ao fechar faz o caminho inverso, sugado de volta para a origem.
//
// Como: o conteudo (source) e fatiado em colunas verticais (ShaderEffectSource
// com sourceRect) e cada coluna e reposicionada/esticada. A origem fica no
// lado do pai; colunas longe dela abrem primeiro e o "pescoco" perto da origem
// por ultimo (lag), o que desenha a curva em S do funil. Sem shader proprio
// (nada de .qsb para compilar). So as fatias aparecem durante a animacao: o
// conteudo real fica oculto (hideSource) e volta a ser o que se ve e clica
// quando progress chega a 1.
//
// Este item deve ocupar exatamente a area final do conteudo (0,0,W,H) e as
// coordenadas de origem sao locais a ele (podem ficar fora de [0,W]).
Item {
  id: genie

  required property Item source
  property real progress: 1        // 0 = colapsado na origem, 1 = aberto
  property real originX: 0         // origem, coordenadas locais
  property real originY: 0
  property int dir: 1              // +1: abre p/ direita (origem a esquerda); -1: oposto
  property real originHeight: 32   // altura do pescoco na origem (altura da linha do pai)
  property int slices: 24          // mais fatias = borda do funil mais lisa (e 1 render da arvore por fatia por quadro)
  property real lag: 0.55          // 0 = sem funil; maior = pescoco mais comprido
  // true = as fatias re-renderizam o conteudo a cada quadro (use enquanto ele
  // ainda pode mudar, ex.: abrindo, com o menu do app carregando). false = o
  // conteudo e capturado UMA vez por fatia: durante o fechamento ele e estatico,
  // e re-renderizar 48 vezes por quadro era trabalho jogado fora.
  property bool live: true

  readonly property bool animating: progress > 0.001 && progress < 0.999

  width: source.width
  height: source.height

  function sstep(t) {
    const c = Math.max(0, Math.min(1, t));
    return c * c * (3 - 2 * c);
  }
  // x final (coordenada local) de uma posicao u = distancia a partir da origem, 0..1
  function finalX(u) {
    return dir > 0 ? u * width : (1 - u) * width;
  }

  // as fatias so existem enquanto anima (criadas na largada, destruidas ao fim)
  Repeater {
    model: genie.animating ? genie.slices : 0

    ShaderEffectSource {
      id: col
      required property int index

      readonly property real ua: genie.dir > 0 ? index / genie.slices : 1 - (index + 1) / genie.slices
      readonly property real ub: ua + 1 / genie.slices
      readonly property real uc: ua + 0.5 / genie.slices
      // abertura local: colunas distantes da origem (uc alto) abrem antes
      readonly property real q: genie.sstep(genie.progress * (1 + genie.lag) - (1 - uc) * genie.lag)
      // espalhamento horizontal: de colado na origem ate a posicao final
      readonly property real spread: genie.sstep(genie.progress)
      readonly property real xa: genie.originX + (genie.finalX(ua) - genie.originX) * spread
      readonly property real xb: genie.originX + (genie.finalX(ub) - genie.originX) * spread

      sourceItem: genie.source
      sourceRect: Qt.rect(index * genie.width / genie.slices, 0, genie.width / genie.slices, genie.height)
      visible: genie.animating
      live: genie.live && genie.animating
      hideSource: genie.animating

      // +1px de sobreposicao evita frestas entre colunas vizinhas
      x: Math.min(xa, xb) - 0.5
      width: Math.abs(xb - xa) + 1
      height: genie.originHeight + (genie.height - genie.originHeight) * q
      y: genie.originY + (genie.height / 2 - genie.originY) * q - height / 2
      opacity: Math.min(1, genie.progress * 6)
    }
  }
}
