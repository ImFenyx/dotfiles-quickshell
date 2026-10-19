import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Uma notificacao rastreada. Os campos sao copiados (snapshot) para a UI
// continuar valida durante a animacao de saida, quando o objeto do servidor
// ja foi fechado. Quem cria e remove e o singleton Notifs.
//
// `popup` = aparece como toast. Sair do toast (timeout, clique, centro aberto)
// NAO apaga: ela continua na lista do centro ate ser dispensada. Excecao: as
// `ephemeral` (hint transient) so existem enquanto o toast dura.
QtObject {
  id: root

  required property var notification     // Quickshell Notification
  property bool popup: false
  property bool hovered: false           // mouse em cima do toast: pausa o timer
  property bool replying: false          // campo de resposta com foco
  property bool closed: false
  property date time: new Date()

  // ---- snapshot ----
  property string appName: ""
  property string groupKey: ""
  property string summary: ""
  property string body: ""               // ja limpo (sem <img>, \n -> <br>)
  property string bodyImage: ""          // 1a imagem local do corpo (file://)
  property string icon: ""               // url pronta p/ Image ("" = sem icone)
  property int urgency: 1                // 0 baixa, 1 normal, 2 critica
  property real expire: -1               // segundos; <0 = padrao do servidor, 0 = nunca
  property bool ephemeral: false         // hint transient: nao vai p/ o historico
  property bool resident: false          // hint resident: fica depois de uma acao
  property int progress: -1              // hint "value" (0..100); -1 = sem barra
  property string tag: ""                // synchronous/stack-tag: a nova substitui a antiga
  property bool suppressSound: false
  property string soundArg: ""           // sound-file ou sound-name do app
  property bool hasReply: false          // resposta inline
  property string replyHint: ""
  property bool actionIcons: false       // hint action-icons: o id da acao e nome de icone
  property var defaultAction: null       // acao "default" (clique no corpo)
  property var buttons: []               // [{id, text, action}] demais acoes

  // "agora", "5 min", "2 h", "3 d" (Time.date muda a cada minuto)
  readonly property string ago: {
    const s = Math.floor((Time.date - time) / 1000);
    if (s < 60)
      return "agora";
    if (s < 3600)
      return Math.floor(s / 60) + " min";
    if (s < 86400)
      return Math.floor(s / 3600) + " h";
    return Math.floor(s / 86400) + " d";
  }

  // tempo do toast em ms; 0 = fica ate dispensar (critica ou timeout 0)
  readonly property int timeoutMs: {
    if (urgency === 2 || expire === 0)
      return 0;
    if (expire < 0)
      return Notifs.defaultTimeout;
    return Math.max(4000, Math.min(expire * 1000, 20000));
  }

  // Corpo: o spec so promete <b> <i> <u> <a> <img>. O Qt (StyledText) cobre
  // os quatro primeiros; <img> vira miniatura propria (so arquivo local, nada
  // de rede) e \n vira <br>.
  function cleanBody(raw) {
    let img = "";
    let s = String(raw || "").replace(/<img\b[^>]*>/gi, tag => {
      const m = tag.match(/src\s*=\s*["']([^"']+)["']/i);
      const src = m ? m[1] : "";
      if (img === "" && (src.startsWith("/") || src.startsWith("file://")))
        img = src.startsWith("/") ? "file://" + src : src;
      const alt = tag.match(/alt\s*=\s*["']([^"']*)["']/i);
      return alt ? alt[1] : "";
    });
    s = s.replace(/\r?\n/g, "<br>");
    return {
      text: s,
      image: img
    };
  }

  function sync() {
    const n = notification;
    if (!n)
      return;
    const h = n.hints || {};

    appName = n.appName || "";
    groupKey = String(n.desktopEntry || n.appName || "?").toLowerCase();
    summary = n.summary || "";
    const b = cleanBody(n.body);
    body = b.text;
    bodyImage = b.image;
    urgency = n.urgency;
    expire = n.expireTimeout;
    ephemeral = n.transient === true || h["transient"] === true || h["transient"] === 1;
    resident = n.resident === true;
    icon = Notifs.resolveIcon(n);

    const v = Number(h["value"]);
    progress = (h["value"] === undefined || isNaN(v)) ? -1 : Math.max(0, Math.min(100, Math.round(v)));

    tag = String(h["x-canonical-private-synchronous"] || h["synchronous"] || h["x-dunst-stack-tag"] || h["x-rcd-stack-tag"] || "");

    const ss = h["suppress-sound"];
    suppressSound = ss === true || ss === 1 || ss === "true";
    soundArg = h["sound-file"] ? String(h["sound-file"]) : (h["sound-name"] ? String(h["sound-name"]) : "");

    hasReply = n.hasInlineReply === true;
    replyHint = n.inlineReplyPlaceholder || "";
    actionIcons = n.hasActionIcons === true;

    let def = null;
    const btns = [];
    for (let i = 0; i < n.actions.length; ++i) {
      const a = n.actions[i];
      if (a.identifier === "default")
        def = a;
      else
        btns.push({
          id: a.identifier,
          text: a.text,
          action: a
        });
    }
    defaultAction = def;
    buttons = btns;
  }

  // app reenviou a mesma notificacao (replaces_id): atualiza e volta a aparecer
  function refresh() {
    sync();
    time = new Date();
    if (!closed && (!Notifs.dnd || urgency === 2))
      popup = true;
    Notifs.regroup();
  }

  // o toast acabou sozinho. Transient nao fica: avisa o app que expirou.
  function timedOut() {
    popup = false;
    hovered = false;
    if (ephemeral)
      expireNow();
  }

  // o toast saiu por outro motivo (clique, centro aberto, nao perturbe)
  function hidePopup() {
    popup = false;
    hovered = false;
    if (ephemeral)
      dismiss();
  }

  function invoke(action) {
    try {
      action.invoke();
    } catch (e) {}
  }

  // clique no corpo com acao padrao: roda e dispensa (a menos de resident)
  function activate() {
    if (!defaultAction)
      return;
    invoke(defaultAction);
    if (!resident)
      dismiss();
    else
      hidePopup();
  }

  function reply(text) {
    if (!hasReply || text.trim() === "")
      return;
    try {
      notification.sendInlineReply(text);
    } catch (e) {}
    if (!resident)
      dismiss();
  }

  function expireNow() {
    try {
      notification.expire();
    } catch (e) {}
    Notifs.drop(root);
  }

  function dismiss() {
    try {
      notification.dismiss();
    } catch (e) {}
    // garante a remocao mesmo que o servidor nao emita closed
    Notifs.drop(root);
  }

  Component.onCompleted: sync()

  readonly property Timer popupTimer: Timer {
    interval: root.timeoutMs
    running: root.popup && !root.hovered && root.timeoutMs > 0
    onTriggered: root.timedOut()
  }

  readonly property Connections conn: Connections {
    target: root.notification
    ignoreUnknownSignals: true

    function onSummaryChanged() {
      root.refresh();
    }
    function onBodyChanged() {
      root.refresh();
    }
    function onAppIconChanged() {
      root.refresh();
    }
    function onImageChanged() {
      root.refresh();
    }
    function onUrgencyChanged() {
      root.refresh();
    }
    function onHintsChanged() {
      root.sync();
    }
    function onActionsChanged() {
      root.sync();
    }
    // fechada pelo app (CloseNotification) ou por dismiss()/expire()
    function onClosed(reason) {
      root.closed = true;
      Notifs.drop(root);
    }
  }
}
