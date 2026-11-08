// Busca de apps do launcher, sem QML nem Quickshell: o Launcher.qml importa
// (`import "LauncherSearch.js" as Search`) e o Node testa o mesmo arquivo
// (tests/launcher-search-test.js). Os apps chegam como dados: {id, name,
// genericName, comment, execString, categories, keywords}.
//
// Indice 1x por mudanca nos .desktop (indexEntry); por tecla roda includes() puro
// (o fzf v2 levava 150-800 ms p/ 500 entradas, medido em log; substring ~ms) e o
// fuzzy proprio, que so olha o nome e so entra em termo que nao casou exato.

// sem dicionario: "musica" casa "música", "navegador" ja vem localizado
function norm(s) {
  return s.toLowerCase().replace(/[áàâã]/g, "a").replace(/[éèê]/g, "e").replace(/[íï]/g, "i").replace(/[óôõö]/g, "o").replace(/[úü]/g, "u").replace(/ç/g, "c").replace(/ñ/g, "n");
}

function tokens(query) {
  return norm(query.trim()).split(/\s+/).filter(x => x !== "");
}

// stemming leve p/ categorias: "gaming"->"gam" casa "Game", "games"->"game".
// So tenta base >=3 letras (nao esvazia "os"->"o"). Um grupo de variantes por termo.
function alternatives(toks) {
  return toks.map(x => {
    const v = [x];
    for (const sfx of ["ing", "ed", "es", "s"]) {
      if (x.length > 3 && x.endsWith(sfx) && x.length - sfx.length >= 3)
        v.push(x.slice(0, -sfx.length));
    }
    return v;
  });
}

function entryText(e) {
  return [e.name, e.genericName, e.comment, e.execString, (e.categories || []).join(" "), (e.keywords || []).join(" ")].join(" ");
}

// distancia de edicao <= 1 (troca, falta, sobra ou duas letras invertidas), O(n)
function near(a, b) {
  if (a === b)
    return true;
  const la = a.length, lb = b.length;
  if (Math.abs(la - lb) > 1)
    return false;
  let i = 0;
  while (i < la && i < lb && a[i] === b[i])
    i++;
  if (la === lb)
    return a.slice(i + 1) === b.slice(i + 1) || (a[i] === b[i + 1] && a[i + 1] === b[i] && a.slice(i + 2) === b.slice(i + 2));
  return la > lb ? a.slice(i + 1) === b.slice(i) : a.slice(i) === b.slice(i + 1);
}

// alvos do fuzzy: o nome e o fim do id, que acha app de nome traduzido
// ("nautlus" -> org.gnome.Nautilus = Arquivos), com 2 pontos a menos
function fuzzyTargets(n, id) {
  const t = [n];
  const tail = norm(String(id).split(".").pop());
  if (tail !== n && /^[a-z0-9-]+$/.test(tail))
    t.push(tail);
  return t.map((x, i) => ({
        n: x,
        w: x.split(/[\s._-]+/),
        m: x.replace(/./g, (c, k) => k === 0 || /[\s._-]/.test(x[k - 1]) ? "1" : "0"), // 1 = inicio de palavra
        d: i === 0 ? 0 : 2
      }));
}

// um app do indice: so dados (quem usa pendura o resto, ex.: o item da lista)
function indexEntry(a) {
  const n = norm(a.name);
  return {
    id: a.id,
    key: a.name.toLowerCase(),      // desempate alfabetico
    n: n,
    w: n.split(/[\s._-]+/),
    fz: fuzzyTargets(n, a.id),
    k: norm((a.genericName || "") + " " + (a.keywords || []).join(" ")),
    h: norm(entryText(a))
  };
}

// Fuzzy so quando o termo nao casa exato em campo nenhum, e abaixo de qualquer
// acerto exato (< 15). Typo: termo de 5+ letras, 1a letra certa, 1 erro contra o
// inicio de uma palavra ("spotfy", "fierfox"). Subsequencia: letras em ordem no nome
// a partir de um inicio de palavra ("frfx" -> Firefox, "vsc" -> Visual Studio Code);
// acerto em inicio de palavra ou colado no anterior vale mais.
function fuzzy(it, t) {
  const L = t.length;
  if (L < 2)
    return -1;
  let best = -1;
  for (const g of it.fz) {
    if (L >= 5) {
      for (let k = 0; k < g.w.length; ++k) {
        const w = g.w[k];
        if (w[0] === t[0] && (near(t, w.slice(0, L)) || near(t, w.slice(0, L + 1)) || near(t, w.slice(0, L - 1))))
          best = Math.max(best, (k === 0 ? 12 : 10) - g.d);
      }
    }
    const n = g.n, m = g.m;
    for (let p0 = 0; p0 < n.length; ++p0) {
      if (m[p0] !== "1" || n[p0] !== t[0])
        continue;
      let prev = p0, bonus = 0, j = 1;
      for (; j < L; ++j) {
        const p = n.indexOf(t[j], prev + 1);
        if (p < 0)
          break;
        if (m[p] === "1" || p === prev + 1)
          bonus++;
        prev = p;
      }
      if (j === L)
        best = Math.max(best, 4 + Math.min(6, bonus) - g.d);
    }
  }
  return best;
}

// pontua por campo (modelo noctalia app_provider): prefixo do nome > prefixo de
// palavra > nome > generico/keywords > resto > fuzzy no nome. -1 = algum termo nao casa.
// Com busca o uso so desempata (teto 20; 3 se algum termo so casou no fuzzy, p/ nao
// passar acerto exato); sem busca ordena pelo uso. freq = {id: pontos} (frecency.sh).
function rank(it, alts, freq) {
  let s = 0;
  let fz = false;
  for (const v of alts) {
    let b = -1;
    for (const t of v)
      b = Math.max(b, it.n.startsWith(t) ? 100 : it.w.some(w => w.startsWith(t)) ? 80 : it.n.includes(t) ? 60 : it.k.includes(t) ? 40 : it.h.includes(t) ? 15 : -1);
    if (b < 0) {
      b = fuzzy(it, v[0]);
      fz = true;
    }
    if (b < 0)
      return -1;
    s += b;
  }
  const f = freq[it.id] || 0;
  return s + (alts.length > 0 ? Math.min(f, fz ? 3 : 20) : f);
}

// entradas do indice que casam, da melhor p/ a pior (empate: ordem alfabetica)
function search(index, query, freq) {
  const alts = alternatives(tokens(query));
  const out = [];
  for (const it of index) {
    const s = rank(it, alts, freq);
    if (s >= 0)
      out.push({
        it: it,
        s: s
      });
  }
  out.sort((a, b) => (b.s - a.s) || ((a.it.key < b.it.key) ? -1 : 1));
  return out.map(x => x.it);
}

if (typeof module !== "undefined")
  module.exports = {
    norm,
    tokens,
    alternatives,
    entryText,
    near,
    fuzzyTargets,
    indexEntry,
    fuzzy,
    rank,
    search
  };
