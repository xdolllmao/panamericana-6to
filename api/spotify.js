// Vercel serverless function: busca canciones en Spotify.
// Usa Client Credentials (server-side) — el secreto nunca llega al browser.
// Requiere env vars en Vercel: SPOTIFY_CLIENT_ID y SPOTIFY_CLIENT_SECRET.

let cachedToken = null;
let tokenExp = 0;

async function getToken() {
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
  if (!res.ok) throw new Error("token_failed_" + res.status);
  const data = await res.json();
  cachedToken = data.access_token;
  tokenExp = Date.now() + (data.expires_in - 60) * 1000;
  return cachedToken;
}

module.exports = async (req, res) => {
  res.setHeader("Access-Control-Allow-Origin", "*");
  const q = ((req.query && req.query.q) || "").toString().trim();
  if (!q) {
    res.status(400).json({ error: "missing_q" });
    return;
  }
  if (!process.env.SPOTIFY_CLIENT_ID || !process.env.SPOTIFY_CLIENT_SECRET) {
    res.status(500).json({ error: "spotify_not_configured" });
    return;
  }
  try {
    const token = await getToken();
    const url =
      "https://api.spotify.com/v1/search?type=track&limit=8&market=SV&q=" +
      encodeURIComponent(q);
    const r = await fetch(url, { headers: { Authorization: "Bearer " + token } });
    if (!r.ok) throw new Error("search_" + r.status);
    const data = await r.json();
    const tracks = ((data.tracks && data.tracks.items) || []).map((t) => ({
      id: t.id,
      name: t.name,
      artists: (t.artists || []).map((a) => a.name).join(", "),
      cover:
        (t.album && t.album.images && t.album.images[0] && t.album.images[0].url) ||
        null,
      url:
        (t.external_urls && t.external_urls.spotify) ||
        "https://open.spotify.com/track/" + t.id,
    }));
    res.status(200).json({ tracks });
  } catch (e) {
    res.status(500).json({ error: "search_failed", detail: String(e && e.message) });
  }
};
