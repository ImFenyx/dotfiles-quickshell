pragma Singleton

import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Daemon de notificacoes da shell (org.freedesktop.Notifications). Substitui o
// swaync: so um programa pode ser dono desse nome no D-Bus, entao swaync,
// dunst e mako precisam estar parados.
//
// `list` guarda tudo (mais nova primeiro). Transient (`ephemeral`) so vive
// enquanto o toast dura: nao entra no historico, na contagem nem nos grupos.
// `groups` e o que o centro mostra: um grupo por app, ordenado por prioridade
// (urgencia) e depois cronologia; dentro do grupo, a mesma regra.
// `count` segue como string ("" = zero) porque o botao da barra mostra o texto.
Singleton {
  id: root

  property var list: []                  // NotifItem
  property var groups: []                // NotifGroup, na ordem de exibicao
  readonly property var popups: list.filter(n => n.popup)
  readonly property var history: list.filter(n => !n.ephemeral)
  readonly property int total: history.length
  readonly property string count: total > 0 ? String(total) : ""

  // nao perturbar: sem toast e sem som (criticas furam). O historico continua enchendo.
  property bool dnd: false
  property bool sound: true
  // toast sem timeout proprio (expireTimeout < 0)
  property int defaultTimeout: 6000

  property var groupMap: ({})
  property real lastSound: 0

  function toggleDnd() {
    dnd = !dnd;
    if (dnd)
      hidePopups();
  }

  function toggleSound() {
    sound = !sound;
  }

  function hidePopups() {
    for (const n of list.slice()) {
      if (n.popup)
        n.hidePopup();
    }
  }

  function clearAll() {
    for (const n of list.slice())
      n.dismiss();
  }

  function dismissGroup(g) {
    for (const n of g.items.slice())
      n.dismiss();
  }

  // tira da lista. O objeto vive bem mais que qualquer animacao de saida: o
  // ScriptModel descarta objetos destruidos, e isso esvaziava o toast no meio
  // do slide (a aba encolhia vazia).
  function drop(item) {
    if (!item)
      return;
    item.popup = false;
    if (list.indexOf(item) >= 0) {
      list = list.filter(n => n !== item);
      regroup();
    }
    item.destroy(8000);
  }

  // prioridade (urgencia) > cronologia (mais nova primeiro)
  function byPriority(a, b) {
    return (b.urgency - a.urgency) || (b.time - a.time);
  }

  // Recalcula os grupos mantendo o objeto de cada app (a lista anima, nao recria).
  function regroup() {
    const buckets = {};
    for (const n of list) {
      if (n.ephemeral)
        continue;
      (buckets[n.groupKey] = buckets[n.groupKey] || []).push(n);
    }

    const map = groupMap;
    const out = [];
    for (const key in buckets) {
      let g = map[key];
      if (!g) {
        g = groupComp.createObject(root, {
          key: key
        });
        map[key] = g;
      }
      g.items = buckets[key].sort(byPriority);
      out.push(g);
    }
    for (const key in map) {
      if (!buckets[key]) {
        map[key].destroy(8000);
        delete map[key];
      }
    }
    out.sort((a, b) => (b.urgency - a.urgency) || (b.latest - a.latest));
    groups = out;
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

  // Som: o do app (sound-file / sound-name) ou um padrao do tema freedesktop.
  // Browsers e a maioria dos apps nao mandam som nenhum, entao o padrao e que
  // faz diferenca. Baixa urgencia fica muda (so toca se o app pediu).
  function playSound(item) {
    if (!sound || item.suppressSound)
      return;
    let arg = item.soundArg;
    if (arg === "") {
      if (item.urgency === 0)
        return;
      arg = item.urgency === 2 ? "dialog-warning" : "message-new-instant";
    }
    const now = Date.now();
    if (now - lastSound < 250)
      return;
    lastSound = now;
    Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/notif-sound.sh"), arg]);
  }

  function add(n) {
    n.tracked = true;
    const quiet = dnd && n.urgency !== NotificationUrgency.Critical;
    const item = itemComp.createObject(root, {
      notification: n,
      popup: !quiet
    });

    // mesma tag "synchronous" do mesmo app: a nova substitui a antiga
    if (item.tag !== "") {
      for (const o of list.slice()) {
        if (o.tag === item.tag && o.groupKey === item.groupKey)
          o.dismiss();
      }
    }

    list = [item, ...list];
    regroup();

    if (quiet) {
      // transient em "nao perturbe" some sem rastro; as demais vao pro historico
      if (item.ephemeral)
        item.expireNow();
      return;
    }
    playSound(item);
  }

  Component {
    id: itemComp
    NotifItem {}
  }

  Component {
    id: groupComp
    NotifGroup {}
  }

  NotificationServer {
    keepOnReload: false
    actionsSupported: true
    actionIconsSupported: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    bodyImagesSupported: true
    imageSupported: true
    persistenceSupported: true
    inlineReplySupported: true
    // capacidades extras que a shell implementa (GetCapabilities)
    extraHints: ["sound", "x-canonical-private-synchronous"]
    onNotification: n => root.add(n)
  }
}
