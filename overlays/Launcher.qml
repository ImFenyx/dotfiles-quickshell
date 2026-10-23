import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Widgets
import qs.components

// Launcher (substitui rofi drun, rofi-emoji e rofi-cliphist): dockado
// baixo-centro, fundido na borda, abre p/ cima. Busca multi-termo + frecency +
// teclado/mouse. Modos pelo 1o caractere (ou direto pelo IPC):
//   (nada) apps    = calculadora (qalc)    : emoji    # clipboard (cliphist)    @ janelas
// Todo modo devolve itens {icon | glyph (+ nerd), title, sub, act}; Enter/clique roda act.
PopupBase {
  id: root

  fromBottom: true
  tuck: 1                 // mesma cor da borda = sem hairline
  panelWidth: 600
  padTop: 12
  padBottom: 8
  padX: 18
  // k=18: moldura EdgeFrame (8px, mesma cor) esconde a base do scoop;
  // sobram ~10px visiveis = paridade com os menus.
  bendK: 18
  asyncShape: false
  backdropFocus: false    // o foco e do TextInput

  property int selectedIndex: 0
  property var freq: ({})

  readonly property var prefixes: ({
      "=": "calc",
      ":": "emoji",
      "#": "clip",
      "@": "win"
    })
  readonly property string mode: prefixes[searchInput.text.charAt(0)] || "apps"
  readonly property string query: mode === "apps" ? searchInput.text : searchInput.text.slice(1)

  // abre no modo do prefixo; mesmo modo ja aberto = fecha (atalho alterna)
  function toggle(prefix) {
    const p = prefix || "";
    if (open && mode === (prefixes[p] || "apps")) {
      close();
      return;
    }
    if (!open) {
      clipTab = "text";
      if (!hzBuilt)
        rebuildIndex();
      freqLoadProc.running = false;
      freqLoadProc.running = true;
      open = true;
    }
    searchInput.text = p;
    selectedIndex = 0;
    loadMode();     // reabrir no mesmo modo nao muda `mode`: recarrega aqui
  }

  // dados do modo: emoji le o arquivo no 1o uso; clipboard rele a cada entrada
  function loadMode() {
    if (mode === "emoji")
      emojiWanted = true;
    else if (mode === "clip") {
      clipProc.running = false;
      clipProc.running = true;
    }
  }
  onModeChanged: loadMode()
  onQueryChanged: {
    if (mode === "calc")
      calcDebounce.restart();
  }

  function entryText(e) {
    return [e.name, e.genericName, e.comment, e.execString, (e.categories || []).join(" "), (e.keywords || []).join(" ")].join(" ");
  }
  // sem dicionario: "musica" casa "música", "navegador" ja vem localizado
  function norm(s) {
    return s.toLowerCase().replace(/[áàâã]/g, "a").replace(/[éèê]/g, "e").replace(/[íï]/g, "i").replace(/[óôõö]/g, "o").replace(/[úü]/g, "u").replace(/ç/g, "c").replace(/ñ/g, "n");
  }
  function tokens() {
    return norm(query.trim()).split(/\s+/).filter(x => x !== "");
  }
  function copyText(s) {
    close();
    Quickshell.execDetached(["wl-copy", "--", s]);
  }

  // ---- apps ----
  // haystacks precomputados 1x: por keystroke roda includes() puro (fzf v2
  // media 150-800ms p/ 500 entradas, medido em log; substring ~ms)
  property var appHay: []
  property var sortName: ({})
  property bool hzBuilt: false
  property bool appsSeen: false

  function rebuildIndex() {
    const apps = DesktopEntries.applications.values.filter(a => !a.noDisplay && a.execString !== "");
    const sn = {};
    const hay = [];
    for (const a of apps) {
      sn[a.id] = a.name.toLowerCase();
      const n = norm(a.name);
      hay.push({
        e: a,
        h: norm(entryText(a)),
        n: n,
        w: n.split(/[\s._-]+/),
        k: norm((a.genericName || "") + " " + (a.keywords || []).join(" ")),
        // item fixo por app: o ScriptModel reaproveita o delegate pela identidade
        item: {
          // IconImage nao resolve nome de tema sozinho; iconPath() gera image:// com fallback
          icon: Quickshell.iconPath(a.icon, "application-x-executable"),
          title: a.name,
          sub: a.genericName || a.comment || "",
          act: () => root.launch(a)
        }
      });
    }
    sortName = sn;
    appHay = hay;
    hzBuilt = true;
    if (hay.length > 0)
      appsSeen = true;
  }

  function appResults() {
    if (!hzBuilt || appHay.length === 0)
      return [];
    // stemming leve p/ categorias: "gaming"->"gam" casa "Game", "games"->"game".
    // So tenta base >=3 letras (nao esvazia "os"->"o").
    const alts = tokens().map(x => {
      const v = [x];
      for (const sfx of ["ing", "ed", "es", "s"]) {
        if (x.length > 3 && x.endsWith(sfx) && x.length - sfx.length >= 3)
          v.push(x.slice(0, -sfx.length));
      }
      return v;
    });
    const out = [];
    for (const it of appHay) {
      const s = rank(it, alts);
      if (s >= 0)
        out.push({
          it: it,
          s: s
        });
    }
    out.sort((a, b) => (b.s - a.s) || ((sortName[a.it.e.id] < sortName[b.it.e.id]) ? -1 : 1));
    return out.map(x => x.it.item);
  }
  // pontua por campo (modelo noctalia app_provider): prefixo do nome > prefixo de
  // palavra > nome > generico/keywords > resto. -1 = algum termo nao casa.
  // Com busca o uso so desempata (teto 20); sem busca ordena pelo uso.
  function rank(it, alts) {
    let s = 0;
    for (const v of alts) {
      let b = -1;
      for (const t of v)
        b = Math.max(b, it.n.startsWith(t) ? 100 : it.w.some(w => w.startsWith(t)) ? 80 : it.n.includes(t) ? 60 : it.k.includes(t) ? 40 : it.h.includes(t) ? 15 : -1);
      if (b < 0)
        return -1;
      s += b;
    }
    const f = freq[it.e.id] || 0;
    return s + (alts.length > 0 ? Math.min(f, 20) : f);
  }

  Connections {
    target: DesktopEntries
    function onApplicationsChanged() {
      // preguicoso: so reindexa com menu aberto; senao marca p/ proxima abertura
      if (root.open)
        root.rebuildIndex();
      else
        root.hzBuilt = false;
    }
  }

  function launch(entry) {
    freq[entry.id] = (freq[entry.id] || 0) + 1;
    Quickshell.execDetached(["sh", Quickshell.shellPath("scripts/frecency.sh"), "hit", entry.id]);
    close();
    if (entry.runInTerminal)
      Quickshell.execDetached(Config.terminal.concat(entry.command));
    else
      entry.execute();
  }

  Process {
    id: freqLoadProc
    command: ["sh", Quickshell.shellPath("scripts/frecency.sh")]
    stdout: StdioCollector {
      onStreamFinished: {
        const m = {};
        for (const l of text.trim().split("\n")) {
          const p = l.split("\t");
          if (p.length >= 2 && p[0] !== "")
            m[p[0]] = parseInt(p[1], 10) || 0;
        }
        root.freq = m;
      }
    }
  }

  // ---- calculadora (qalc) ----
  property string calcResult: ""

  function calcResults() {
    const q = query.trim();
    if (q === "")
      return [];
    return [
      {
        glyph: Icons.calculator,
        nerd: true,
        title: calcResult !== "" ? calcResult : "…",
        sub: q + "   ·   Enter copia",
        act: () => {
          if (root.calcResult !== "")
            root.copyText(root.calcResult);
        }
      }
    ];
  }

  Timer {
    id: calcDebounce
    interval: 150
    onTriggered: {
      root.calcResult = "";
      calcProc.running = false;
      if (root.query.trim() !== "")
        calcProc.running = true;
    }
  }
  Process {
    id: calcProc
    command: ["qalc", "-t", "--", root.query.trim()]
    stdout: StdioCollector {
      // avisos (ex.: cambio desatualizado) vem antes: o resultado e a ultima linha
      onStreamFinished: root.calcResult = text.trim().split("\n").pop()
    }
  }

  // ---- emoji (lista do rofi-emoji: emoji, grupo, subgrupo, nome, keywords) ----
  property bool emojiWanted: false   // so le o arquivo (~600KB) no 1o uso
  property var emojis: []

  FileView {
    path: root.emojiWanted ? "/usr/share/rofi-emoji/all_emojis.txt" : ""
    printErrors: false
    onLoaded: {
      const out = [];
      for (const l of text().split("\n")) {
        const f = l.split("\t");
        if (f.length < 4)
          continue;
        const e = f[0];
        out.push({
          glyph: e,
          title: f[3],
          sub: f[1],
          n: root.norm(f[3]),
          h: root.norm(f[3] + " " + (f[4] || "")),
          act: () => root.pickEmoji(e)
        });
      }
      root.emojis = out;
    }
  }

  function emojiResults() {
    const toks = tokens();
    if (toks.length === 0)
      return emojis.slice(0, 200);
    const out = [];
    for (const it of emojis) {
      let s = 0;
      for (const t of toks) {
        const b = it.n.startsWith(t) ? 3 : it.n.includes(t) ? 2 : it.h.includes(t) ? 1 : 0;
        if (b === 0) {
          s = 0;
          break;
        }
        s += b;
      }
      if (s > 0)
        out.push({
          it: it,
          s: s
        });
    }
    out.sort((a, b) => b.s - a.s);
    return out.slice(0, 100).map(x => x.it);
  }
  // como o rofi-emoji (modo insert): copia e digita na janela que volta a ter o foco
  function pickEmoji(e) {
    close();
    Quickshell.execDetached(["sh", "-c", "wl-copy -- \"$1\"; sleep 0.15; wtype -- \"$1\"", "sh", e]);
  }

  // ---- clipboard (cliphist: "id<TAB>preview", mais novo primeiro) ----
  // Duas abas como no rofi-cliphist: texto e imagens (grade com miniatura).
  // Alt+t / Alt+i trocam; Alt+d apaga; Alt+p / Alt+n apagam as de cima / de baixo
  // da selecionada, na aba (e busca) atual.
  property var clips: []
  property string clipTab: "text"   // "text" | "images"
  property var thumbs: ({})         // id -> url da miniatura (scripts/cliphist-thumbs.sh)
  property var delQueue: []         // ids esperando o `cliphist delete`
  readonly property bool imageGrid: mode === "clip" && clipTab === "images"

  onClipTabChanged: {
    selectedIndex = 0;
    if (clipTab === "images")
      loadThumbs();
  }

  Process {
    id: clipProc
    command: ["cliphist", "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        const out = [];
        for (const l of text.split("\n")) {
          const i = l.indexOf("\t");
          if (i <= 0)
            continue;
          const id = l.slice(0, i);
          const preview = l.slice(i + 1);
          // "[[ binary data 492 KiB png 747x528 ]]" -> 492 KiB, png, 747x528
          const bin = preview.match(/^\[\[ binary data (\S+ \S+) (\S+) (\S+) \]\]$/);
          out.push({
            id: id,
            img: bin !== null,
            glyph: Icons.clipboard,
            nerd: true,
            title: bin ? bin[2] + "  " + bin[3] : preview,
            sub: bin ? bin[1] : "",
            h: root.norm(preview),
            act: () => root.pickClip(id)
          });
        }
        root.clips = out;
        if (root.clipTab === "images")
          root.loadThumbs();
      }
    }
  }

  // decodifica as imagens que faltam (1x por id) e limpa o cache das apagadas
  function loadThumbs() {
    if (!thumbProc.running)
      thumbProc.running = true;
  }
  Process {
    id: thumbProc
    command: ["sh", Quickshell.shellPath("scripts/cliphist-thumbs.sh")]
    stdout: SplitParser {
      onRead: line => {
        const i = line.indexOf("\t");
        if (i <= 0)
          return;
        const m = Object.assign({}, root.thumbs);
        m[line.slice(0, i)] = "file://" + line.slice(i + 1);
        root.thumbs = m;
      }
    }
  }

  function clipResults() {
    const img = clipTab === "images";
    const toks = tokens();
    return clips.filter(it => it.img === img && toks.every(t => it.h.includes(t)));
  }
  function pickClip(id) {
    close();
    Quickshell.execDetached(["sh", "-c", "cliphist decode \"$1\" | wl-copy", "sh", id]);
  }

  // some da lista na hora; o cliphist apaga em fila e a lista e relida no fim
  function clipDelete(items) {
    if (items.length === 0)
      return;
    const del = new Set(items.map(it => it.id));
    clips = clips.filter(c => !del.has(c.id));
    delQueue = delQueue.concat([...del]);
    flushDel();
  }
  function flushDel() {
    if (clipDelProc.running || delQueue.length === 0)
      return;
    clipDelProc.command = ["sh", "-c", "printf '%s\\n' \"$@\" | cliphist delete", "sh"].concat(delQueue);
    delQueue = [];
    clipDelProc.running = true;
  }
  Process {
    id: clipDelProc
    onExited: {
      root.flushDel();
      if (!running && root.mode === "clip") {
        clipProc.running = false;
        clipProc.running = true;
      }
    }
  }

  // ---- janelas (Hyprland) ----
  function winResults() {
    const toks = tokens();
    const out = [];
    for (const t of Hyprland.toplevels.values) {
      const app = t.wayland ? t.wayland.appId : "";
      if (toks.length > 0 && !toks.every(x => norm(t.title + " " + app).includes(x)))
        continue;
      const de = app !== "" ? DesktopEntries.heuristicLookup(app) : null;
      const addr = t.address;
      out.push({
        icon: Quickshell.iconPath(de ? de.icon : app, "application-x-executable"),
        title: t.title,
        sub: (de ? de.name : app) + (t.workspace ? "   ·   workspace " + t.workspace.name : ""),
        act: () => {
          root.close();
          Hyprland.dispatch("hl.dsp.focus({ window = \"address:0x" + addr + "\" })");
        }
      });
    }
    return out;
  }

  property var results: mode === "calc" ? calcResults() : mode === "emoji" ? emojiResults() : mode === "clip" ? clipResults() : mode === "win" ? winResults() : appResults()

  readonly property string emptyText: mode === "calc" ? "Digite uma conta (ex.: 2*3, 10 km to mi)" : mode === "emoji" ? (emojis.length > 0 ? "Nada encontrado" : "Carregando…") : mode === "clip" ? (clips.length > 0 ? "Nada encontrado" : "Clipboard vazio") : mode === "win" ? "Nenhuma janela" : (appsSeen ? "Nada encontrado" : "Procurando…")

  function moveSel(d) {
    if (results.length === 0)
      return;
    selectedIndex = Math.max(0, Math.min(results.length - 1, selectedIndex + d));
    (imageGrid ? imageView : resultsList).positionViewAtIndex(selectedIndex, ListView.Contain);
  }

  // lista (ou grade de imagens) + scrollbar fina por cima (sem QtQuick.Controls)
  Item {
    visible: root.results.length > 0
    Layout.fillWidth: true
    Layout.preferredHeight: root.imageGrid ? 432 : 318

    ListView {
      id: resultsList
      anchors.fill: parent
      visible: !root.imageGrid
      clip: true
      // ScriptModel reaproveita os delegates por identidade (array puro recriava a cada tecla)
      model: ScriptModel {
        values: root.imageGrid ? [] : root.results
      }
      spacing: 2
      delegate: Item {
        id: row
        required property var modelData
        required property int index
        property bool selected: root.selectedIndex === index

        width: ListView.view.width
        implicitHeight: 38

        Rectangle {
          anchors.fill: parent
          radius: 8
          color: row.selected ? Theme.surface1 : (rowArea.containsMouse ? Theme.surface0 : "transparent")
        }
        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: 10
          anchors.rightMargin: 10
          spacing: 10
          // icone (apps, janelas) ou glifo (emoji, nerd font)
          Item {
            Layout.preferredWidth: 26
            Layout.preferredHeight: 26
            Layout.alignment: Qt.AlignVCenter
            IconImage {
              anchors.fill: parent
              visible: !!row.modelData.icon
              asynchronous: true
              source: row.modelData.icon || ""
            }
            UiText {
              anchors.centerIn: parent
              visible: !row.modelData.icon
              color: Theme.mauve
              font.family: row.modelData.nerd ? Theme.iconFont : Theme.uiFont
              font.pointSize: 15
              text: row.modelData.glyph || ""
            }
          }
          ColumnLayout {
            Layout.fillWidth: true
            Layout.alignment: Qt.AlignVCenter
            spacing: 0
            UiText {
              Layout.fillWidth: true
              elide: Text.ElideRight
              maximumLineCount: 1
              textFormat: Text.PlainText
              text: row.modelData.title
            }
            UiText {
              visible: text !== ""
              Layout.fillWidth: true
              color: Theme.overlay0
              font.pointSize: 9
              font.weight: Font.Normal
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: row.modelData.sub || ""
            }
          }
        }
        MouseArea {
          id: rowArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.selectedIndex = row.index
          onClicked: row.modelData.act()
        }
      }
    }

    // aba de imagens do clipboard: grade 3 colunas com miniatura
    GridView {
      id: imageView
      anchors.fill: parent
      visible: root.imageGrid
      clip: true
      cellWidth: width / 3
      cellHeight: 144
      model: ScriptModel {
        values: root.imageGrid ? root.results : []
      }
      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property string src: root.thumbs[modelData.id] || ""

        width: GridView.view.cellWidth
        height: GridView.view.cellHeight

        Rectangle {
          anchors.fill: parent
          anchors.margins: 4
          radius: 10
          color: Theme.surface0
          border.width: 2
          border.color: root.selectedIndex === cell.index ? Theme.mauve : (cellArea.containsMouse ? Theme.surface1 : "transparent")

          ClippingRectangle {
            anchors.fill: parent
            anchors.margins: 4
            radius: 7
            color: "transparent"
            Image {
              id: thumb
              anchors.fill: parent
              source: cell.src
              fillMode: Image.PreserveAspectFit
              asynchronous: true
              sourceSize.width: 360
              sourceSize.height: 270
            }
          }
          // ainda decodificando (1a vez) ou falhou: formato e tamanho
          UiText {
            anchors.centerIn: parent
            visible: thumb.status !== Image.Ready
            color: Theme.overlay0
            font.pointSize: 9
            text: cell.modelData.title + "\n" + cell.modelData.sub
            horizontalAlignment: Text.AlignHCenter
          }
        }
        MouseArea {
          id: cellArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.selectedIndex = cell.index
          onClicked: cell.modelData.act()
        }
      }
    }

    Item {
      readonly property Flickable view: root.imageGrid ? imageView : resultsList
      visible: view.contentHeight > view.height
      anchors.top: parent.top
      anchors.right: parent.right
      anchors.rightMargin: -6
      width: 4
      height: parent.height
      Rectangle {
        anchors.fill: parent
        radius: 2
        color: Theme.surface0
      }
      Rectangle {
        width: parent.width
        y: parent.view.visibleArea.yPosition * parent.height
        height: Math.max(24, parent.view.visibleArea.heightRatio * parent.height)
        radius: 2
        color: Theme.surface1
      }
    }
  }

  Item {
    visible: root.results.length === 0
    Layout.fillWidth: true
    Layout.preferredHeight: 318
    UiText {
      anchors.centerIn: parent
      color: Theme.overlay0
      font.weight: Font.Normal
      text: root.emptyText
    }
  }

  // atalhos do clipboard (como o cabecalho do rofi-cliphist)
  UiText {
    visible: root.mode === "clip"
    Layout.fillWidth: true
    Layout.leftMargin: 4
    Layout.bottomMargin: 2
    color: Theme.overlay0
    font.pointSize: 9
    font.weight: Font.Normal
    elide: Text.ElideRight
    text: (root.imageGrid ? "Alt+t  texto" : "Alt+i  imagens") + "     Alt+d  apagar     Alt+p  apagar as de cima     Alt+n  apagar as de baixo"
  }

  Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 42
    radius: 10
    color: Theme.surface1
    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: 12
      anchors.rightMargin: 12
      spacing: 10
      Glyph {
        font.pointSize: 13
        text: root.mode === "calc" ? Icons.calculator : root.mode === "emoji" ? Icons.smile : root.mode === "clip" ? Icons.clipboard : root.mode === "win" ? Icons.window : Icons.search
      }
      TextInput {
        id: searchInput
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        color: Theme.text
        font.family: Theme.uiFont
        font.pointSize: 12
        focus: root.open
        Keys.onEscapePressed: root.close()
        Keys.onPressed: event => {
          const r = root.results;
          const sel = Math.min(root.selectedIndex, r.length - 1);
          // atalhos do clipboard (paridade rofi-cliphist)
          if (root.mode === "clip" && (event.modifiers & Qt.AltModifier)) {
            if (event.key === Qt.Key_I)
              root.clipTab = "images";
            else if (event.key === Qt.Key_T)
              root.clipTab = "text";
            else if (event.key === Qt.Key_D && sel >= 0)
              root.clipDelete([r[sel]]);
            else if (event.key === Qt.Key_P && sel > 0) {
              root.clipDelete(r.slice(0, sel));
              root.selectedIndex = 0;
            } else if (event.key === Qt.Key_N && sel >= 0)
              root.clipDelete(r.slice(sel + 1));
            else
              return;
            root.selectedIndex = Math.max(0, Math.min(root.selectedIndex, root.results.length - 1));
            event.accepted = true;
            return;
          }
          // grade de imagens: setas andam na grade (3 colunas)
          const step = root.imageGrid ? 3 : 1;
          if (root.imageGrid && (event.key === Qt.Key_Left || event.key === Qt.Key_Right)) {
            root.moveSel(event.key === Qt.Key_Left ? -1 : 1);
            event.accepted = true;
          } else if (event.key === Qt.Key_Up) {
            root.moveSel(-step);
            event.accepted = true;
          } else if (event.key === Qt.Key_Down) {
            root.moveSel(step);
            event.accepted = true;
          } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
            if (sel >= 0)
              r[sel].act();
            event.accepted = true;
          }
        }
        onTextChanged: root.selectedIndex = 0

        // vazio: lembra os prefixos dos modos
        UiText {
          anchors.verticalCenter: parent.verticalCenter
          visible: searchInput.text === ""
          color: Theme.overlay0
          font.pointSize: 11
          font.weight: Font.Normal
          text: "Apps      =  calculadora      :  emoji      #  clipboard      @  janelas"
        }
      }
    }
  }
}
