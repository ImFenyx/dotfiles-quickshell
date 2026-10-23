pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Emojis do Unicode p/ o launcher (modo ":"). Lista oficial do pacote
// unicode-emoji (emoji-test.txt: todos os fully-qualified, com grupo e nome em
// ingles) + nomes e palavras-chave do CLDR em portugues e ingles
// (unicode-cldr-annotations). Atualiza sozinho: os arquivos vem do pacman e sao
// vigiados, entao a versao nova do Unicode entra no proximo reload do arquivo.
// Bandeiras e outras sequencias nao tem nome em pt nesse pacote (ficam em ingles).
//
// So o emoji base vai p/ a lista; `tones` = [padrao, 5 tons de pele] quando o
// emoji tem variacoes (as de dois tons diferentes, como casais mistos, ficam de
// fora). Escolher um item emite `picked`: quem usa decide (popup de tom ou insere).
Singleton {
  id: root

  property bool wanted: false       // so le os arquivos no 1o uso
  property var items: []            // {e, glyph, title, sub, n, m, h, tones, act}
  property int tone: 0              // ultimo tom escolhido (0 = padrao), salvo em disco
  readonly property bool ready: items.length > 0
  property bool missing: false      // sem emoji-test.txt (pacote unicode-emoji nao instalado)

  signal picked(var item)

  readonly property string dataDir: "/usr/share/unicode/"
  readonly property var toneMarks: ["\u{1F3FB}", "\u{1F3FC}", "\u{1F3FD}", "\u{1F3FE}", "\u{1F3FF}"]

  function setTone(t) {
    tone = t;
    toneFile.setText(String(t));
  }

  // sem dicionario: "musica" casa "música" (mesma regra do launcher)
  function norm(s) {
    return s.toLowerCase().replace(/[áàâã]/g, "a").replace(/[éèê]/g, "e").replace(/[íï]/g, "i").replace(/[óôõö]/g, "o").replace(/[úü]/g, "u").replace(/ç/g, "c").replace(/ñ/g, "n");
  }
  // chave de comparacao: sem seletor de variacao (FE0F) e sem tom de pele
  function key(s) {
    let k = s.replace(/️/g, "");
    for (const t of toneMarks)
      k = k.split(t).join("");
    return k;
  }
  function unescapeXml(s) {
    return s.replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&");
  }

  // <annotation cp="😀">feliz | riso</annotation> + <annotation cp="😀" type="tts">rosto risonho</annotation>
  function annotations(xml) {
    const m = {};
    const re = /<annotation cp="([^"]+)"( type="tts")?>([^<]*)<\/annotation>/g;
    let r;
    while ((r = re.exec(xml)) !== null) {
      const k = key(unescapeXml(r[1]));
      const o = m[k] || (m[k] = {
          name: "",
          kw: ""
        });
      const t = unescapeXml(r[3]);
      if (r[2])
        o.name = t;
      else
        o.kw = t.split(" | ").join(" ");
    }
    return m;
  }

  function rebuild() {
    const test = testFile.text();
    if (test === "")
      return;
    const pt = annotations(ptFile.text());
    const en = annotations(enFile.text());
    const byKey = {};
    const out = [];
    let group = "";
    for (const l of test.split("\n")) {
      if (l.startsWith("# group: ")) {
        group = l.slice(9);
        continue;
      }
      // 1F600 ; fully-qualified # 😀 E1.0 grinning face
      const r = l.match(/; fully-qualified\s+# (\S+) E[\d.]+ (.+)$/);
      if (!r)
        continue;
      const e = r[1];
      const k = key(e);
      const tones = [...new Set([...e].filter(c => toneMarks.indexOf(c) >= 0))];
      if (tones.length > 0) {
        // variacao de tom: entra no `tones` do base (tom unico; misto fica de fora)
        const b = byKey[k];
        if (b && tones.length === 1) {
          if (!b.tones)
            b.tones = [b.e, b.e, b.e, b.e, b.e, b.e];
          b.tones[toneMarks.indexOf(tones[0]) + 1] = e;
        }
        continue;
      }
      const p = pt[k], g = en[k];
      const title = p && p.name ? p.name : r[2];
      const item = {
        e: e,
        glyph: e,
        title: title,
        sub: title !== r[2] ? r[2] : group,
        n: norm(title),
        m: norm(r[2]),
        h: norm([title, p ? p.kw : "", r[2], g ? g.kw : ""].join(" ")),
        tones: null,
        act: null
      };
      item.act = () => root.picked(item);
      byKey[k] = item;
      out.push(item);
    }
    items = out;
  }

  // termos ja normalizados; sem termo = os primeiros (carinhas), como o rofi
  function search(toks) {
    if (toks.length === 0)
      return items.slice(0, 200);
    const out = [];
    for (const it of items) {
      let s = 0;
      for (const t of toks) {
        const b = (it.n.startsWith(t) || it.m.startsWith(t)) ? 3 : (it.n.includes(t) || it.m.includes(t)) ? 2 : it.h.includes(t) ? 1 : 0;
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

  // os 3 arquivos chegam em momentos diferentes: junta num rebuild so
  Timer {
    id: rebuildLater
    interval: 50
    onTriggered: root.rebuild()
  }

  FileView {
    id: testFile
    path: root.wanted ? root.dataDir + "emoji/emoji-test.txt" : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: {
      root.missing = false;
      rebuildLater.restart();
    }
    onLoadFailed: root.missing = true
  }
  FileView {
    id: ptFile
    path: root.wanted ? root.dataDir + "cldr/common/annotations/pt.xml" : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: rebuildLater.restart()
  }
  FileView {
    id: enFile
    path: root.wanted ? root.dataDir + "cldr/common/annotations/en.xml" : ""
    printErrors: false
    watchChanges: true
    onFileChanged: reload()
    onLoaded: rebuildLater.restart()
  }
  FileView {
    id: toneFile
    path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickshell/emoji-tone"
    printErrors: false
    onLoaded: root.tone = Math.max(0, Math.min(5, parseInt(text(), 10) || 0))
  }
}
