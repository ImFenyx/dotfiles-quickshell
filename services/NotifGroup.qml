import QtQuick

// Grupo de notificacoes do mesmo app (estilo macOS). Objeto persistente: o
// Notifs so troca `items`, entao a identidade (e o `expanded`) sobrevive e a
// lista anima em vez de recriar tudo. Dentro do grupo: prioridade > cronologia.
QtObject {
  id: root

  property string key: ""
  property var items: []            // NotifItem, ja ordenados
  property bool expanded: false

  readonly property int count: items.length
  readonly property string appName: count > 0 ? items[0].appName : ""
  readonly property string icon: {
    for (const n of items) {
      if (n.icon !== "")
        return n.icon;
    }
    return "";
  }
  // maior urgencia entre os itens (0 baixa, 1 normal, 2 critica)
  readonly property int urgency: {
    let u = 0;
    for (const n of items)
      u = Math.max(u, n.urgency);
    return u;
  }
  readonly property real latest: {
    let t = 0;
    for (const n of items)
      t = Math.max(t, n.time.getTime());
    return t;
  }

  onCountChanged: {
    if (count <= 1)
      expanded = false;
  }
}
