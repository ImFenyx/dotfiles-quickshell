pragma Singleton

import Quickshell
import Quickshell.Services.Mpris
import QtQuick
import qs.components

// Midia em reproducao (MPRIS): musica, video no mpv/vlc, aba do navegador...
// `active` e o player mostrado: o que o usuario fixou (cycle), senao o que esta
// tocando, senao o primeiro. O MPRIS nao diz se e musica ou video, entao
// `kind` e uma heuristica (app, depois URL da faixa).
Singleton {
  id: root

  // playerctld so espelha os outros players
  readonly property var players: Mpris.players.values.filter(p => (p.dbusName || "").indexOf("playerctld") < 0)
  property var pinned: null

  readonly property var active: {
    const ps = players;
    if (pinned && ps.indexOf(pinned) >= 0)
      return pinned;
    for (let i = 0; i < ps.length; ++i) {
      if (ps[i].playbackState === MprisPlaybackState.Playing)
        return ps[i];
    }
    return ps.length > 0 ? ps[0] : null;
  }

  readonly property bool has: active !== null
  readonly property bool playing: has && active.playbackState === MprisPlaybackState.Playing
  readonly property string title: has ? (active.trackTitle || "") : ""
  readonly property string artist: has ? (active.trackArtist || "") : ""
  readonly property string art: has ? (active.trackArtUrl || "") : ""
  readonly property string player: has ? (active.identity || "") : ""
  readonly property bool canPrev: has && active.canGoPrevious
  readonly property bool canNext: has && active.canGoNext
  readonly property bool canToggle: has && active.canTogglePlaying
  readonly property bool canSeek: has && active.canSeek && active.positionSupported
  readonly property real length: has && active.lengthSupported ? active.length : 0
  readonly property real position: has && active.positionSupported ? active.position : 0

  readonly property string kind: classify(active)
  readonly property string kindLabel: kind === "music" ? "Música" : (kind === "video" ? "Vídeo" : "Mídia")
  readonly property string kindIcon: kind === "music" ? Icons.music : (kind === "video" ? Icons.video : Icons.mediaGeneric)

  function classify(p) {
    if (!p)
      return "";
    const id = ((p.dbusName || "") + " " + (p.identity || "") + " " + (p.desktopEntry || "")).toLowerCase();
    const meta = p.metadata || {};
    const url = String(meta["xesam:url"] || "").toLowerCase();
    if (/spotify|rhythmbox|amberol|lollypop|elisa|strawberry|clementine|cmus|mpd|musikcube|ncspot|deadbeef|audacious|tidal|deezer|ytmusic|youtube-music|feishin|supersonic/.test(id))
      return "music";
    if (/mpv|vlc|celluloid|totem|haruna|smplayer|kodi|stremio|mplayer|parole|jellyfin|plex/.test(id))
      return "video";
    if (/music\.youtube|open\.spotify|soundcloud|deezer|tidal|bandcamp|music\.apple/.test(url))
      return "music";
    if (/youtube\.com|youtu\.be|twitch\.tv|netflix|primevideo|vimeo|disneyplus|hbomax|max\.com|crunchyroll|dailymotion|\.mp4|\.mkv|\.webm|\.avi|\.mov/.test(url))
      return "video";
    return "media";
  }

  function togglePlaying() {
    if (canToggle)
      active.togglePlaying();
  }
  function previous() {
    if (canPrev)
      active.previous();
  }
  function next() {
    if (canNext)
      active.next();
  }
  function seek(sec) {
    if (canSeek)
      active.position = Math.max(0, Math.min(sec, length));
  }
  // com mais de um player: passa para o proximo
  function cycle() {
    const ps = players;
    if (ps.length < 2)
      return;
    pinned = ps[(ps.indexOf(active) + 1) % ps.length];
  }
  // a posicao nao notifica sozinha: quem exibe chama isto a cada segundo
  function tick() {
    if (has)
      active.positionChanged();
  }
}
