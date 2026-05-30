#!/usr/bin/env node

/**
 * Cinegram Media Indexing Tool
 * 
 * Fetches media metadata from the TMDB API using a TMDB ID,
 * and inserts a mapped media listing (TMDB + Telegram channel ID + message ID)
 * into the Supabase database.
 */

const path = require("path");
// Read environment variables from the parent .env file in a robust, path-independent way
require("dotenv").config({ path: path.resolve(__dirname, "../.env") });
const { createClient } = require("@supabase/supabase-js");

// Define standard usage instructions
function printUsage() {
  console.log(`
\x1b[36m============================================================\x1b[0m
\x1b[1m\x1b[35m                 CINEGRAM MEDIA INDEXING TOOL\x1b[0m
\x1b[36m============================================================\x1b[0m

\x1b[1mUsage:\x1b[0m
  node indexMedia.js --channelId <id> --messageId <id> --tmdbId <id> --type <movie|tv|anime> [--quality <quality>]

\x1b[1mArguments:\x1b[0m
  \x1b[33m--channelId\x1b[0m  Telegram channel ID (e.g., -100123456789)  \x1b[31m[Required]\x1b[0m
  \x1b[33m--messageId\x1b[0m  Telegram message ID of the video file (e.g., 142)  \x1b[31m[Required]\x1b[0m
  \x1b[33m--tmdbId\x1b[0m     TMDB movie or show ID (e.g., 299534)  \x1b[31m[Required]\x1b[0m
  \x1b[33m--type\x1b[0m       Media type. Must be 'movie', 'tv', or 'anime'  \x1b[31m[Required]\x1b[0m
  \x1b[33m--quality\x1b[0m    Video quality (e.g., 1080p, 4K, HDR)  \x1b[32m[Optional, Default: 1080p]\x1b[0m

\x1b[1mExample:\x1b[0m
  node indexMedia.js --channelId -100123456789 --messageId 142 --tmdbId 299534 --type movie --quality 1080p
\x1b[36m============================================================\x1b[0m
  `);
}

// Custom simple CLI argument parser to support standard formats:
// E.g., --param value OR --param=value
const args = {};
for (let i = 2; i < process.argv.length; i++) {
  const arg = process.argv[i];
  if (arg.startsWith("--")) {
    const parts = arg.split("=");
    const name = parts[0].substring(2);
    if (parts.length > 1) {
      args[name] = parts.slice(1).join("=");
    } else {
      const next = process.argv[i + 1];
      // A value is considered valid if it exists and doesn't start with double dashes.
      // Negative numbers like -100123456789 start with single dash, which is fine!
      if (next && !next.startsWith("--")) {
        args[name] = next;
        i++;
      } else {
        args[name] = true;
      }
    }
  }
}

// Retrieve command line arguments
const channelId = args.channelId;
const messageId = args.messageId;
const tmdbId = args.tmdbId;
const type = args.type;
const quality = args.quality || "1080p";

// Validate required arguments
if (!channelId || !messageId || !tmdbId || !type) {
  console.error("\x1b[31mError: Missing required arguments.\x1b[0m");
  printUsage();
  process.exit(1);
}

// Validate media type
const allowedTypes = ["movie", "tv", "anime"];
const cleanType = type.toString().toLowerCase().trim();
if (!allowedTypes.includes(cleanType)) {
  console.error(`\x1b[31mError: Invalid type '${type}'. Type must be one of: ${allowedTypes.join(", ")}\x1b[0m`);
  printUsage();
  process.exit(1);
}

const cleanChannelId = channelId.toString().trim();
const cleanMessageId = messageId.toString().trim();
const cleanTmdbId = tmdbId.toString().trim();
const cleanQuality = quality.toString().trim();

// Retrieve environment credentials
const tmdbApiKey = process.env.TMDB_API_KEY;
const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_KEY;

if (!tmdbApiKey) {
  console.error("\x1b[31mError: TMDB_API_KEY is not defined in the parent .env file.\x1b[0m");
  process.exit(1);
}

if (!supabaseUrl || !supabaseKey) {
  console.error("\x1b[31mError: SUPABASE_URL or SUPABASE_KEY is missing in the parent .env file.\x1b[0m");
  process.exit(1);
}

// Main execution function
async function indexMedia() {
  try {
    // 1. Fetch metadata from TMDB API
    // Note: 'anime' uses the TMDB 'tv' type since anime series are indexed under TV shows on TMDB
    const tmdbType = cleanType === "movie" ? "movie" : "tv";
    const tmdbUrl = `https://api.themoviedb.org/3/${tmdbType}/${cleanTmdbId}?api_key=${tmdbApiKey}&language=en-US`;
    
    console.log(`\x1b[34m[TMDB] Fetching metadata for TMDB ID ${cleanTmdbId} (${tmdbType})...\x1b[0m`);
    
    const response = await fetch(tmdbUrl);
    if (!response.ok) {
      throw new Error(`TMDB API returned HTTP ${response.status}: ${response.statusText}`);
    }
    
    const data = await response.json();
    
    // Resolve specific metadata fields
    const title = data.title || data.name || data.original_title || data.original_name || "Unknown Title";
    const synopsis = data.overview || "No synopsis available.";
    const posterPath = data.poster_path ? `https://image.tmdb.org/t/p/w500${data.poster_path}` : null;
    const backdropPath = data.backdrop_path ? `https://image.tmdb.org/t/p/original${data.backdrop_path}` : null;
    
    console.log(`\x1b[32m[TMDB] Successfully resolved metadata for: "${title}"\x1b[0m`);
    
    // 2. Connect to Supabase Database
    console.log(`\x1b[34m[Supabase] Connecting to Supabase database...\x1b[0m`);
    const supabase = createClient(supabaseUrl, supabaseKey);
    
    // 3. Upsert media listing record
    console.log(`\x1b[34m[Supabase] Indexing listing in public.media_listings table...\x1b[0m`);
    const { data: listingData, error: dbError } = await supabase
      .from("media_listings")
      .upsert(
        [{
          tmdb_id: cleanTmdbId,
          title: title,
          type: cleanType,
          channel_id: cleanChannelId,
          message_id: cleanMessageId,
          quality: cleanQuality
        }],
        { onConflict: "channel_id,message_id" }
      )
      .select();
      
    if (dbError) {
      throw new Error(`Database error inserting listing: ${dbError.message}`);
    }
    
    if (!listingData || listingData.length === 0) {
      throw new Error("Upsert operation returned no data. Check your Supabase database triggers or policies.");
    }
    
    // 4. Beautiful Console Success Summary
    console.log(`
\x1b[32m============================================================\x1b[0m
\x1b[1m\x1b[32mSUCCESS: MEDIA LISTING INDEXED SUCCESSFULLY!\x1b[0m
\x1b[32m============================================================\x1b[0m

\x1b[1mMedia Details:\x1b[0m
  \x1b[35mDatabase ID:\x1b[0m   ${listingData[0].id}
  \x1b[35mTitle:\x1b[0m         \x1b[1m${title}\x1b[0m
  \x1b[35mTMDB ID:\x1b[0m       ${cleanTmdbId}
  \x1b[35mType:\x1b[0m          ${cleanType}
  \x1b[35mQuality:\x1b[0m       ${cleanQuality}

\x1b[1mTelegram Mapping:\x1b[0m
  \x1b[36mChannel ID:\x1b[0m    ${cleanChannelId}
  \x1b[36mMessage ID:\x1b[0m    ${cleanMessageId}

\x1b[1mTMDB Visuals & Metadata:\x1b[0m
  \x1b[33mPoster URL:\x1b[0m    ${posterPath || "N/A"}
  \x1b[33mBackdrop URL:\x1b[0m  ${backdropPath || "N/A"}
  \x1b[33mSynopsis:\x1b[0m      ${synopsis}

\x1b[32m============================================================\x1b[0m
    `);
    
  } catch (error) {
    console.error(`\n\x1b[31m[FATAL ERROR] Indexing failed: ${error.message}\x1b[0m`);
    console.error(`\x1b[33mPlease ensure your network connection, .env credentials, and Supabase schema are set up correctly.\x1b[0m\n`);
    process.exit(1);
  }
}

indexMedia();
