pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Daemon de notificacoes da shell (org.freedesktop.Notifications). Substitui o
// swaync: so um programa pode ser dono desse nome no D-Bus, entao swaync,
// dunst e mako precisam estar parados.
//
// `list` guarda tudo (mais nova primeiro) = o que o centro mostra. `popups` e o
// subconjunto que aparece como toast. `count` segue como string ("" = zero)
// porque o botao da barra mostra o texto direto.
Singleton {
  id: root

  property var list: []                  // NotifItem
  readonly property var popups: list.filter(n => n.popup)
  readonly property int total: list.length
  readonly property string count: total > 0 ? String(total) : ""

  // nao perturbar: sem toast (criticas furam). O historico continua enchendo.
  property bool dnd: false
  // toast sem timeout proprio (expireTimeout < 0)
  property int defaultTimeout: 6000

  function toggleDnd() {
    dnd = !dnd;
    if (dnd)
      hidePopups();
  }

  function hidePopups() {
    for (const n of list)
      n.popup = false;
  }

  function clearAll() {
    for (const n of list.slice())
      n.dismiss();
  }

  // tira da lista; o objeto vive mais um pouco p/ a animacao de saida terminar
  function drop(item) {
    if (!item)
      return;
    item.popup = false;
    if (list.indexOf(item) >= 0)
      list = list.filter(n => n !== item);
    item.destroy(800);
  }

  // url p/ Image: image-data/caminho do app > appIcon (caminho ou nome do tema)
  // > icone do .desktop. "" = sem icone (a UI desenha a inicial do app).
  function resolveIcon(n) {
    if (n.image)
      return n.image;
    const names = [n.appIcon, n.desktopEntry];
    for (const name of names) {
      if (!name)
        continue;
      if (name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:"))
        return name;
      const p = Quickshell.iconPath(name, true);
      if (p)
        return p;
    }
    return "";
  }

  function add(n) {
    n.tracked = true;
    const show = !dnd || n.urgency === NotificationUrgency.Critical;
    const item = itemComp.createObject(root, {
      notification: n,
      popup: show
    });
    list = [item, ...list];
  }

  Component {
    id: itemComp
    NotifItem {}
  }

  NotificationServer {
    keepOnReload: false
    actionsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: false
    bodyImagesSupported: false
    imageSupported: true
    persistenceSupported: true
    onNotification: n => root.add(n)
  }
}
