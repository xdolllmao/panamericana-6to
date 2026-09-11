// Vercel serverless function: busca canciones.
// Intenta Spotify (Client Credentials, secreto server-side). Si Spotify no
// esta configurado o falla (p. ej. 403 "premium required" en apps nuevas),
// cae a iTunes Search API (gratis, sin auth) devolviendo el mismo formato.
// El link de "play" siempre apunta a Spotify (open.spotify.com).

let cachedToken = null;
let tokenExp = 0;

async function getSpotifyToken() {
  if (cachedToken && Date.now() < tokenExp) return cachedToken;
  const id = process.env.SPOTIFY_CLIENT_ID;
  const secret = process.env.SPOTIFY_CLIENT_SECRET;
  const auth = Buffer.from(`${id}:${secret}`).toString("base64");
  const res = await fetch("https://accounts.spotify.com/api/token", {
    method: "POST",
    headers: {
      Authorization: "Basic " + auth,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: "grant_type=client_credentials",
  });
  if (!res.ok) throw new Error("token_" + res.status);
  const data = await res.json();
  cachedToken = data.access_token;
  tokenExp = Date.now() + (data.expires_in - 60) * 1000;
  return cachedToken;
}

async function searchSpotify(q) {
  if (!process.env.SPOTIFY_CLIENT_ID || !process.env.SPOTIFY_CLIENT_SECRET) return null;
  const token = await getSpotifyToken();
  const url = "https://api.spotify.com/v1/search?type=track&limit=8&q=" + encodeURIComponent(q);
  const r = await fetch(url, { headers: { Authorization: "Bearer " + token } });
  if (!r.ok) return null; // 403 premium-required, etc → dejamos que caiga a iTunes
  const data = await r.json();
  const items = (data.tracks && data.tracks.items) || [];
  if (!items.length) return [];
  return items.map((t) => ({
    id: "sp_" + t.id,
    name: t.name,
    artists: (t.artists || []).map((a) => a.name).join(", "),
    cover: (t.album && t.album.images && t.album.images[0] && t.album.images[0].url) || null,
    url: (t.external_urls && t.external_urls.spotify) || "https://open.spotify.com/track/" + t.id,
    source: "spotify",
  }));
}

async function searchITunes(q) {
  const url =
    "https://itunes.apple.com/search?media=music&entity=song&limit=8&term=" +
    encodeURIComponent(q);
  const r = await fetch(url);
  if (!r.ok) throw new Error("itunes_" + r.status);
  const data = await r.json();
  const items = data.results || [];
  return items.map((t) => {
    const query = encodeURIComponent(`${t.trackName} ${t.artistName}`);
    return {
      id: "it_" + t.trackId,
      name: t.trackName,
      artists: t.artistName,
      // artwork 100x100 → subir a 300x300 para mejor calidad
      cover: (t.artworkUrl100 || "").replace("100x100bb", "300x300bb") || null,
      // link de play: abre Spotify con la busqueda de la cancion (1 tap para reproducir)
      url: "https://open.spotify.com/search/" + query,
      source: "itunes",
    };
  });
}

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  const q = ((req.query && req.query.q) || "").toString().trim();
  if (!q) {
    res.status(400).json({ error: "missing_q" });
    return;
  }
  try {
    let tracks = null;
    try {
      tracks = await searchSpotify(q);
    } catch (e) {
      tracks = null;
    }
    if (!tracks || !tracks.length) {
      tracks = await searchITunes(q);
    }
    res.status(200).json({ tracks });
  } catch (e) {
    res.status(500).json({ error: "search_failed", detail: String(e && e.message) });
  }
};
