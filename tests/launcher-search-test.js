// Busca do launcher (overlays/LauncherSearch.js): propriedades, nao fotografias.
// Cada teste diz a regressao que pega. Roda com: node --test tests/
const test = require("node:test");
const assert = require("node:assert/strict");
const S = require("../overlays/LauncherSearch.js");

const app = (id, name, extra = {}) => ({ id, name, genericName: "", comment: "", execString: id, categories: [], keywords: [], ...extra });
const APPS = [
  app("org.mozilla.firefox", "Firefox", { genericName: "Navegador", categories: ["Network", "WebBrowser"] }),
  app("code", "Visual Studio Code", { genericName: "Editor de texto", keywords: ["vscode"] }),
  app("spotify", "Spotify", { categories: ["Audio", "Music"] }),
  app("org.gnome.Nautilus", "Arquivos", { comment: "Acesse e organize arquivos" }),
  app("steam", "Steam", { categories: ["Game"] }),
  app("org.kde.elisa", "Música", { categories: ["Audio"] }),
  app("org.kde.filelight", "Filelight", { comment: "Uso de disco" }),
  app("org.prismlauncher.PrismLauncher", "Prism Launcher", { categories: ["Game"] }),
  app("zed", "Zed", { genericName: "Editor de texto" }),
  app("kitty", "kitty", { genericName: "Terminal", categories: ["TerminalEmulator"] }),
];
const INDEX = APPS.map(S.indexEntry);
const names = (q, freq = {}) => S.search(INDEX, q, freq).map(it => S.norm(APPS.find(a => a.id === it.id).name));
const first = (q, freq) => names(q, freq)[0];

test("niveis: inicio do nome > inicio de palavra > meio do nome > generico > resto", () => {
  // pega: pesos trocados no rank (ex.: keyword valendo mais que o nome)
  const n = S.indexEntry(app("x", "Code Studio", { genericName: "studio", comment: "zzz" }));
  const score = q => S.rank(n, S.alternatives(S.tokens(q)), {});
  assert.equal(score("code"), 100);
  assert.equal(score("studio"), 80);
  assert.equal(score("ode"), 60);
  assert.equal(score("zzz"), 15);
  assert.equal(score("nada"), -1);
});

test("varios termos: todos precisam casar e os pontos somam", () => {
  // pega: termos virando OU em vez de E
  assert.deepEqual(names("editor zed"), ["zed"]);
  assert.deepEqual(names("editor inexistente"), []);
});

test("acento nao importa", () => {
  // pega: norm() deixando de tirar acento (o "musica" do usuario nao acha "Música")
  assert.equal(first("musica"), "musica");
  assert.equal(S.norm("Ação Música"), "acao musica");
});

test("plural e gerundio em ingles casam a categoria", () => {
  // pega: o stemming de "games"/"gaming" sumir
  for (const q of ["games", "gaming"])
    assert.ok(names(q).includes("steam"), q);
  // e base curta nao e cortada ("os" nao vira "o")
  assert.deepEqual(S.alternatives(["os"]), [["os"]]);
});

test("fuzzy acha letras em ordem e siglas", () => {
  // pega: o fuzzy de subsequencia quebrar
  assert.equal(first("frfx"), "firefox");
  assert.equal(first("vsc"), "visual studio code");
  assert.equal(first("prsm"), "prism launcher");
});

test("fuzzy aceita 1 erro de digitacao so com 5+ letras", () => {
  // pega: o limite de 5 letras sumir (com 4, "fire" puxava Filelight)
  assert.equal(first("spotfy"), "spotify");
  assert.equal(first("fierfox"), "firefox");
  assert.ok(!names("fire").includes("filelight"));   // "fire" -> "file" e 1 erro, mas 4 letras
});

test("fuzzy usa o fim do id para nome traduzido", () => {
  // pega: fuzzyTargets parar de olhar o id (Nautilus se chama "Arquivos")
  assert.equal(first("nautlus"), "arquivos");
});

test("fuzzy nunca passa um acerto exato, nem com muito uso", () => {
  // pega: o teto de 3 pontos de uso no fuzzy sumir
  const freq = { spotify: 500 };
  // "acesse" casa exato no comentario do Arquivos (15); "spotfy" so no fuzzy do Spotify
  const r = S.search(INDEX, "acesse", freq).map(it => it.id);
  assert.equal(r[0], "org.gnome.Nautilus");
  const it = INDEX.find(x => x.id === "spotify");
  assert.ok(S.rank(it, S.alternatives(["spotfy"]), freq) <= 12 + 3);
});

test("uso desempata a busca com teto 20 e ordena a lista vazia", () => {
  // pega: o uso dominar a busca, ou a lista sem busca nao seguir o uso
  const freq = { zed: 1000, code: 5 };
  // "editor": os dois casam no generico (40); quem tem mais uso ganha
  assert.equal(first("editor", freq), "zed");
  // sem busca: ordem do uso
  assert.deepEqual(names("", freq).slice(0, 2), ["zed", "visual studio code"]);
  // com busca, uso alto nao passa um nivel acima (inicio do nome 100 > palavra 80 + 20)
  const zed = INDEX.find(x => x.id === "zed");
  assert.equal(S.rank(zed, S.alternatives(["editor"]), freq), 40 + 20);
});

test("empate sai em ordem alfabetica", () => {
  // pega: sort instavel ou desempate trocado
  assert.deepEqual(names("audio"), ["musica", "spotify"]);
});

test("near(): distancia de edicao ate 1", () => {
  // pega: casos de borda do typo (inversao, falta, sobra)
  assert.ok(S.near("steam", "steam"));
  assert.ok(S.near("staem", "steam"));   // duas invertidas
  assert.ok(S.near("stem", "steam"));    // falta
  assert.ok(S.near("steaam", "steam"));  // sobra
  assert.ok(S.near("stexm", "steam"));   // troca
  assert.ok(!S.near("stxxm", "steam"));
  assert.ok(!S.near("st", "steam"));
});
