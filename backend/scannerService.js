const path = require("path");
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });

// Scanner status state in memory with real-time progress details
let scannerState = {
  active: false,
  lastRun: null,
  progress: {
    totalChannels: 0,
    currentChannel: 0,
    currentChannelName: "",
    processedItems: 0,
    resolvedItems: 0,
    status: "idle", // "idle", "scanning", "completed", "error"
    logs: []
  }
};

// Dynamic channel configurations (Movies, TV Shows, Anime) persistently loaded
const fs = require("fs");
const channelsJsonPath = path.resolve(__dirname, "./channels.json");

let dynamicChannels = [];
if (fs.existsSync(channelsJsonPath)) {
  try {
    dynamicChannels = JSON.parse(fs.readFileSync(channelsJsonPath, "utf8"));
    console.log(`[Scanner] Loaded ${dynamicChannels.length} persistent channels from channels.json`);
  } catch (err) {
    console.error("[Scanner] Error loading channels.json:", err);
  }
} else {
  dynamicChannels = [
    { id: process.env.TELEGRAM_CHANNEL_MOVIES || "-100223344", type: "movie", name: "Movies" },
    { id: process.env.TELEGRAM_CHANNEL_TV || "-100223345", type: "tv", name: "TV Shows" },
    { id: process.env.TELEGRAM_CHANNEL_ANIME || "-100223346", type: "anime", name: "Anime" }
  ];
}

function getDynamicChannels() {
  return dynamicChannels;
}

function setDynamicChannels(channels) {
  if (Array.isArray(channels)) {
    dynamicChannels = channels;
  }
}

/**
 * Clean torrent-style filenames using regex rules.
 * Extracts clean Titles, Years, and season/episode patterns.
 */
function parseFilename(filename) {
  if (!filename) {
    return { title: "Unknown", year: null, season: null, episode: null, type: "movie" };
  }

  // Remove extension (e.g. .mp4, .mkv)
  let cleanName = filename.replace(/\.(mp4|mkv|avi|mov|flv|wmv)$/i, "");
  
  // Replace underscores and hyphens with dots to standardise boundaries
  cleanName = cleanName.replace(/[_-]/g, ".");
  
  let title = cleanName;
  let year = null;
  let season = null;
  let episode = null;
  let type = "movie";
  
  // 1. Check for SxxEee or Season.xx.Episode.xx patterns
  const seasonEpisodeMatch = cleanName.match(/^(.*?)\.?[sS](\d+)[eE](\d+)/i);
  const seasonEpisodeMatch2 = cleanName.match(/^(.*?)\.?[sS]eason\.?(\d+)\.?[eE]pisode\.?(\d+)/i);
  
  if (seasonEpisodeMatch) {
    title = seasonEpisodeMatch[1];
    season = parseInt(seasonEpisodeMatch[2], 10);
    episode = parseInt(seasonEpisodeMatch[3], 10);
    type = "tv";
  } else if (seasonEpisodeMatch2) {
    title = seasonEpisodeMatch2[1];
    season = parseInt(seasonEpisodeMatch2[2], 10);
    episode = parseInt(seasonEpisodeMatch2[3], 10);
    type = "tv";
  } else {
    // 2. Check for 4-digit year (1900-2099)
    const yearMatch = cleanName.match(/^(.*?)[.(-]?(19\d{2}|20\d{2})[.)-]?/i);
    if (yearMatch) {
      title = yearMatch[1];
      year = yearMatch[2];
      type = "movie";
    }
  }
  
  // Clean up title: replace dots with spaces, trim excess spaces
  title = title.replace(/\./g, " ");
  
  // Strip common torrent/quality terms if they somehow lingered
  const qualityKeywords = [
    /\b(1080p|720p|4k|2160p|bluray|web-dl|webrip|web|hdtv|hevc|x264|x265|h264|h265|hdr|aac|dd5\.1|dts|remux|dvdrip|brrip)\b/i
  ];
  qualityKeywords.forEach(regex => {
    title = title.replace(regex, "");
  });
  
  // Clean spaces and trim
  title = title.replace(/\s+/g, " ").trim();
  
  // Title Case conversion
  title = title
    .split(" ")
    .map(word => {
      if (!word) return "";
      return word.charAt(0).toUpperCase() + word.slice(1).toLowerCase();
    })
    .filter(Boolean)
    .join(" ");

  return {
    title: title || "Unknown",
    year,
    season,
    episode,
    type,
  };
}

/**
 * Extracts quality from filename
 */
function getQuality(filename) {
  if (!filename) return "1080p";
  const qualityMatch = filename.match(/\b(2160p|1080p|720p|4k|4K|8k|8K|bluray|dvdrip)\b/i);
  if (qualityMatch) {
    return qualityMatch[1].toLowerCase();
  }
  return "1080p";
}

/**
 * Resolves standard filename from message attributes or text
 */
function getFilenameFromMessage(message) {
  if (!message) return null;
  if (message.file && message.file.name) {
    return message.file.name;
  }
  if (message.media && message.media.document && message.media.document.attributes) {
    for (const attr of message.media.document.attributes) {
      if (attr.fileName) {
        return attr.fileName;
      }
    }
  }
  if (message.message) {
    const msg = message.message.trim();
    if (msg.match(/\.(mp4|mkv|avi|mov|flv|wmv)$/i)) {
      return msg;
    }
    if (message.media && (message.media.document || message.media.video || message.file)) {
      return msg;
    }
  }
  return null;
}

/**
 * Performs background channel scanning
 */
async function runScan(tgClient, supabase, targetChannelId) {
  if (scannerState.active) {
    console.log("[Scanner] A scan is already in progress.");
    return;
  }

  scannerState.active = true;
  scannerState.lastRun = new Date().toISOString();

  let channelsToScan = [];
  if (targetChannelId) {
    const matched = dynamicChannels.find(c => c.id.toString() === targetChannelId.toString());
    channelsToScan.push({
      id: targetChannelId,
      type: matched ? matched.type : null,
      name: matched ? matched.name : "Target Channel"
    });
  } else {
    channelsToScan = [...dynamicChannels];
  }

  scannerState.progress = {
    totalChannels: channelsToScan.length,
    currentChannel: 0,
    currentChannelName: "",
    processedItems: 0,
    resolvedItems: 0,
    status: "scanning",
    logs: [`[${new Date().toLocaleTimeString()}] Started scanning ${channelsToScan.length} channel(s)...`]
  };

  try {
    const tmdbApiKey = process.env.TMDB_API_KEY;

    for (const chan of channelsToScan) {
      scannerState.progress.currentChannel++;
      scannerState.progress.currentChannelName = chan.name || chan.id.toString();
      scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Accessing Telegram Channel: "${scannerState.progress.currentChannelName}"`);
      console.log(`[Scanner] Scanning Telegram channel: ${chan.id} (${chan.type || "unknown type"})`);
      
      let peer;
      if (typeof chan.id === "string" && chan.id.startsWith("-100")) {
        peer = BigInt(chan.id);
      } else if (typeof chan.id === "number") {
        peer = BigInt(chan.id);
      } else {
        peer = chan.id;
      }

      // Fetch the 50 most recent messages from the channel (resolving input entity first for Telethon/GramJS stability)
      let messages = [];
      try {
        const entity = await tgClient.getEntity(peer);
        messages = await tgClient.getMessages(entity, { limit: 50 });
      } catch (entityErr) {
        console.error(`[Scanner] Peer resolution error for channel ID ${chan.id}:`, entityErr.message || entityErr.toString());
        scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Peer resolution error for channel: ${chan.id}. Resolving via peer cache fallback...`);
        // Fallback to direct getMessages if getEntity fails
        try {
          messages = await tgClient.getMessages(peer, { limit: 50 });
        } catch (fbErr) {
          console.error(`[Scanner] Fallback getMessages failed for channel ID ${chan.id}:`, fbErr.message || fbErr.toString());
          scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Failed to scan channel ${chan.id}: ${fbErr.message}`);
          continue;
        }
      }
      console.log(`[Scanner] Fetched ${messages.length} messages from Telegram channel ${chan.id}`);
      scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Fetched ${messages.length} messages. Filtering video content...`);

      for (const msg of messages) {
        const filename = getFilenameFromMessage(msg);
        if (!filename) continue;

        const messageId = msg.id.toString();
        console.log(`[Scanner] Processing video message ID ${messageId}: "${filename}"`);
        scannerState.progress.processedItems++;
        scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Found video file: "${filename}"`);

        // Check if already indexed in database (with valid tmdb_id !== '0')
        const { data: existing } = await supabase
          .from("media_listings")
          .select("id, tmdb_id")
          .eq("channel_id", chan.id.toString())
          .eq("message_id", messageId)
          .maybeSingle();

        if (existing && existing.tmdb_id !== "0") {
          console.log(`[Scanner] Message ID ${messageId} is already resolved. Skipping.`);
          scannerState.progress.resolvedItems++;
          scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] File "${filename}" already indexed. Skipped.`);
          continue;
        }

        // Parse filename
        const parsed = parseFilename(filename);
        const quality = getQuality(filename);

        let tmdbId = "0";
        let resolvedTitle = parsed.title;
        let resolvedType = chan.type || parsed.type || "movie";

        if (tmdbApiKey) {
          try {
            let tmdbUrl;
            if (resolvedType === "tv" || resolvedType === "anime") {
              tmdbUrl = `https://api.themoviedb.org/3/search/tv?api_key=${tmdbApiKey}&query=${encodeURIComponent(parsed.title)}&language=en-US`;
            } else {
              tmdbUrl = `https://api.themoviedb.org/3/search/movie?api_key=${tmdbApiKey}&query=${encodeURIComponent(parsed.title)}&language=en-US`;
            }

            const response = await fetch(tmdbUrl);
            if (response.ok) {
              const data = await response.json();
              let results = data.results || [];

              // If a year was parsed, filter results to improve accuracy
              if (parsed.year && results.length > 0) {
                const yearStr = parsed.year.toString();
                const filtered = results.filter(item => {
                  const dateStr = item.release_date || item.first_air_date || "";
                  return dateStr.startsWith(yearStr);
                });
                if (filtered.length > 0) {
                  results = filtered;
                }
              }

              // Rank by popularity score
              results.sort((a, b) => (b.popularity || 0) - (a.popularity || 0));

              if (results.length > 0) {
                const bestMatch = results[0];
                tmdbId = bestMatch.id.toString();
                resolvedTitle = bestMatch.title || bestMatch.name;
                console.log(`[Scanner] Successfully resolved "${filename}" to TMDB: "${resolvedTitle}" (ID: ${tmdbId})`);
                scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Resolved: "${resolvedTitle}" (TMDB: ${tmdbId})`);
              } else {
                console.log(`[Scanner] No TMDB results for: "${parsed.title}". Saving as unresolved.`);
                scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] No TMDB match found for: "${parsed.title}". Indexing as unresolved...`);
              }
            } else {
              console.error(`[Scanner] TMDB Search API returned HTTP ${response.status}`);
            }
          } catch (tmdbErr) {
            console.error(`[Scanner] TMDB query error for "${parsed.title}":`, tmdbErr);
          }
        } else {
          console.warn("[Scanner] TMDB_API_KEY is not defined. Indexing as unresolved.");
          scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] TMDB Key missing. Saved as unresolved.`);
        }

        // Upsert listing record
        const { error: dbErr } = await supabase
          .from("media_listings")
          .upsert(
            [{
              tmdb_id: tmdbId,
              title: resolvedTitle,
              type: resolvedType,
              channel_id: chan.id.toString(),
              message_id: messageId,
              quality: quality
            }],
            { onConflict: "channel_id,message_id" }
          );

        if (dbErr) {
          console.error(`[Scanner] Database upsert error for message ID ${messageId}:`, dbErr.message);
          scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Supabase DB Error: ${dbErr.message}`);
          if (dbErr.message.toLowerCase().includes("row-level security") || dbErr.message.toLowerCase().includes("policy")) {
            console.warn("==================================================");
            console.warn("SUPABASE RLS WARNING: Anonymous write blocked!");
            console.warn("Please run this command in your Supabase SQL Editor:");
            console.warn("ALTER TABLE public.media_listings DISABLE ROW LEVEL SECURITY;");
            console.warn("==================================================");
            scannerState.progress.logs.push(`[RLS ALERT] Run 'ALTER TABLE public.media_listings DISABLE ROW LEVEL SECURITY;' in your Supabase SQL editor to allow writes.`);
          }
        } else {
          scannerState.progress.resolvedItems++;
        }
      }
    }
    scannerState.progress.status = "completed";
    scannerState.progress.logs.push(`[${new Date().toLocaleTimeString()}] Index sync complete! Processed: ${scannerState.progress.processedItems}, Success: ${scannerState.progress.resolvedItems}`);
  } catch (err) {
    console.error("[Scanner] Error during background channel scan:", err);
    scannerState.progress.status = "error";
    scannerState.progress.logs.push(`[ERROR] Background channel scan failed: ${err.message || err.toString()}`);
  } finally {
    scannerState.active = false;
    console.log("[Scanner] Background channel scan completed.");
  }
}

module.exports = {
  scannerState,
  parseFilename,
  getQuality,
  runScan,
  getDynamicChannels,
  setDynamicChannels
};
