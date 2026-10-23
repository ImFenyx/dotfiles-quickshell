import QtQuick

// MouseArea que mostra/move/esconde o tooltip da tela (TipWindow).
// Substitui o trio onEntered/onPositionChanged/onExited copiado 7x.
MouseArea {
  id: root

  property var tipWindow: null     // TipWindow da tela
  property string tipText: ""      // vazio = sem tooltip
  property bool mono: false
  // true = o tooltip acompanha o mouse (cada movimento move a caixa dentro da
  // janela fullscreen do tip: segue 1:1 sem reconfigure de layer-shell)
  property bool follow: true
  // emitido antes de mostrar (ex.: atualizar o texto sob demanda)
  signal tipRequested

  hoverEnabled: true

  // dado relido no tipRequested chega depois do show(): atualiza o tip aberto
  onTipTextChanged: {
    if (containsMouse && tipWindow && tipText !== "")
      tipWindow.tipText = tipText;
  }
  onEntered: {
    root.tipRequested();
    if (root.tipWindow && root.tipText !== "")
      root.tipWindow.show(root.tipText, mapToGlobal(width / 2, height / 2), root.mono);
  }
  onPositionChanged: event => {
    if (root.follow && root.tipWindow)
      root.tipWindow.move(mapToGlobal(event.x, event.y));
  }
  onExited: {
    if (root.tipWindow)
      root.tipWindow.hide();
  }
}
