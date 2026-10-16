import QtQuick

// MouseArea que mostra/move/esconde o tooltip da tela (TipWindow).
// Substitui o trio onEntered/onPositionChanged/onExited copiado 7x.
MouseArea {
  id: root

  property var tipWindow: null     // TipWindow da tela
  property string tipText: ""      // vazio = sem tooltip
  property bool mono: false
  // emitido antes de mostrar (ex.: atualizar o texto sob demanda)
  signal tipRequested

  hoverEnabled: true

  onEntered: {
    root.tipRequested();
    if (root.tipWindow && root.tipText !== "")
      root.tipWindow.show(root.tipText, mapToGlobal(width / 2, height / 2), root.mono);
  }
  onPositionChanged: event => {
    if (root.tipWindow)
      root.tipWindow.move(mapToGlobal(event.x, event.y));
  }
  onExited: {
    if (root.tipWindow)
      root.tipWindow.hide();
  }
}
