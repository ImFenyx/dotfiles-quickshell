import Quickshell
import Quickshell.Services.Notifications
import QtQuick

// Uma notificacao rastreada. Os campos sao copiados (snapshot) para a UI
// continuar valida durante a animacao de saida, quando o objeto do servidor
// ja foi fechado. Quem cria e remove e o singleton Notifs.
//
// `popup` = aparece como toast. Sair do toast (timeout, clique, centro aberto)
// NAO apaga: ela continua na lista do centro ate ser dispensada.
QtObject {
  id: root

  required property var notification     // Quickshell Notification
  property bool popup: false
  property bool hovered: false           // mouse em cima do toast: pausa o timer
  property bool closed: false
  readonly property date time: new Date()

  // ---- snapshot ----
  property string appName: ""
  property string summary: ""
  property string body: ""
  property string icon: ""               // url pronta p/ Image ("" = sem icone)
  property int urgency: 1                // 0 baixa, 1 normal, 2 critica
  property real expire: -1               // segundos; <0 = padrao do servidor, 0 = nunca
  property bool ephemeral: false         // hint transient do app: nao vai p/ o historico
  property bool resident: false
  property var defaultAction: null       // acao "default" (clique no corpo)
  property var buttons: []               // demais acoes: botoes

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

  function sync() {
    const n = notification;
    if (!n)
      return;
    appName = n.appName || "";
    summary = n.summary || "";
    body = n.body || "";
    urgency = n.urgency;
    expire = n.expireTimeout;
    ephemeral = n.transient === true;
    resident = n.resident === true;
    icon = Notifs.resolveIcon(n);

    let def = null;
    const btns = [];
    for (let i = 0; i < n.actions.length; ++i) {
      const a = n.actions[i];
      if (a.identifier === "default")
        def = a;
      else
        btns.push(a);
    }
    defaultAction = def;
    buttons = btns;
  }

  // app reenviou a mesma notificacao (replaces_id): atualiza e volta a aparecer
  function refresh() {
    sync();
    if (!closed && !Notifs.dnd)
      popup = true;
  }

  function hidePopup() {
    popup = false;
    hovered = false;
    // transient (ex.: "volume 40%") nao merece ficar no historico
    if (ephemeral)
      dismiss();
  }

  function invoke(action) {
    try {
      action.invoke();
    } catch (e) {}
  }

  // clique no corpo: acao padrao (e dispensa); sem ela, so tira o toast
  function activate() {
    if (defaultAction) {
      invoke(defaultAction);
      if (!resident)
        dismiss();
      else
        popup = false;
    } else {
      popup = false;
    }
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
    onTriggered: root.hidePopup()
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
    function onActionsChanged() {
      root.sync();
    }
    // fechada pelo app (CloseNotification) ou por dismiss()
    function onClosed(reason) {
      root.closed = true;
      Notifs.drop(root);
    }
  }
}
