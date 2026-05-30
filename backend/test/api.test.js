// Cinegram Automated API Integration Test Suite
// Verified with Jest and Supertest

process.env.NODE_ENV = "test";
process.env.PORT = "3001";
process.env.TELEGRAM_API_ID = "12345";
process.env.TELEGRAM_API_HASH = "mock_api_hash";
process.env.TELEGRAM_SESSION_STRING = "mock_session_string";
process.env.TMDB_API_KEY = "mock_tmdb_api_key";
process.env.SUPABASE_URL = "https://mock-supabase.co";
process.env.SUPABASE_KEY = "mock_supabase_key";

const request = require("supertest");

// ------------------------------------------------------------------
// Mock Telegram MTProto Library (telegram)
// ------------------------------------------------------------------
jest.mock("telegram", () => {
  class StringSession {
    constructor(sessionString) {
      this.sessionString = sessionString;
    }
  }

  class TelegramClient {
    constructor(session, apiId, apiHash, options) {
      this.session = session;
      this.apiId = apiId;
      this.apiHash = apiHash;
      this.options = options;
    }
    async connect() {
      return true;
    }
    async getMessages(peer, options) {
      // Mock returning a message with document media (1 MB video file)
      return [
        {
          media: {
            document: {
              id: 1234567890n,
              accessHash: 9876543210n,
              fileReference: Buffer.from("mock_file_reference"),
              size: 1024 * 1024, // 1 MB
              mimeType: "video/mp4",
            },
          },
        },
      ];
    }
    async invoke(query) {
      // query.limit is the chunk size requested
      const limit = Number(query.limit) || 1024;
      // Return buffer bytes filled with the character 'A' (hex 0x41)
      return {
        bytes: Buffer.alloc(limit, "A"),
      };
    }
  }

  const Api = {
    InputDocumentFileLocation: class InputDocumentFileLocation {
      constructor(fields) {
        Object.assign(this, fields);
      }
    },
    upload: {
      GetFile: class GetFile {
        constructor(fields) {
          Object.assign(this, fields);
        }
      },
    },
  };

  return { StringSession, TelegramClient, Api };
});

// ------------------------------------------------------------------
// Mock Supabase Postgres Client (@supabase/supabase-js)
// ------------------------------------------------------------------
let mockListings = [];
let mockWatchHistory = [];
let mockBookmarks = [];

jest.mock("@supabase/supabase-js", () => ({
  createClient: jest.fn(() => ({
    auth: {
      getUser: jest.fn(async (token) => {
        if (token === "valid-token") {
          return { data: { user: { id: "user-uuid-123" } }, error: null };
        }
        return { data: { user: null }, error: { message: "Invalid or expired token" } };
      }),
    },
    from: jest.fn((table) => {
      const tableChain = {};

      tableChain.select = jest.fn((columns) => {
        tableChain.eq = jest.fn((col, val) => {
          tableChain.eqQuery = tableChain.eqQuery || [];
          tableChain.eqQuery.push({ col, val });
          return tableChain;
        });

        tableChain.limit = jest.fn((num) => {
          tableChain.limitVal = num;
          return tableChain;
        });

        tableChain.single = jest.fn(async () => {
          const filtered = mockApplyFilters(table, tableChain.eqQuery);
          if (filtered.length === 0) {
            return { data: null, error: new Error("Not found") };
          }
          return { data: filtered[0], error: null };
        });

        tableChain.maybeSingle = jest.fn(async () => {
          const filtered = mockApplyFilters(table, tableChain.eqQuery);
          return { data: filtered[0] || null, error: null };
        });

        tableChain.order = jest.fn((col, opts) => {
          return tableChain;
        });

        // Promise chain resolver
        tableChain.then = (onFulfilled) => {
          let data = mockApplyFilters(table, tableChain.eqQuery);
          if (table === "watch_history" || table === "bookmarks") {
            // Populate nested media_listings relations dynamically
            data = data.map((item) => {
              const listing = mockListings.find((l) => l.id === item.media_listing_id);
              return {
                ...item,
                media_listings: listing || {
                  id: item.media_listing_id,
                  tmdb_id: "999",
                  title: "Fallback Content",
                  type: "movie",
                  channel_id: "mock-chan",
                  message_id: "mock-msg",
                  quality: "1080p",
                },
              };
            });
          }
          return Promise.resolve(onFulfilled({ data, error: null }));
        };

        return tableChain;
      });

      tableChain.upsert = jest.fn((arr, options) => {
        const records = Array.isArray(arr) ? arr : [arr];
        const results = [];
        for (const rec of records) {
          if (table === "media_listings") {
            const idx = mockListings.findIndex(
              (l) =>
                (l.channel_id === rec.channel_id && l.message_id === rec.message_id) ||
                l.tmdb_id === rec.tmdb_id
            );
            const newRec = {
              id: idx !== -1 ? mockListings[idx].id : `list-${mockListings.length + 1}`,
              created_at: new Date().toISOString(),
              ...rec,
            };
            if (idx !== -1) {
              mockListings[idx] = newRec;
            } else {
              mockListings.push(newRec);
            }
            results.push(newRec);
          } else if (table === "watch_history") {
            const idx = mockWatchHistory.findIndex(
              (w) => w.user_id === rec.user_id && w.media_listing_id === rec.media_listing_id
            );
            const newRec = {
              id: idx !== -1 ? mockWatchHistory[idx].id : `watch-${mockWatchHistory.length + 1}`,
              ...rec,
            };
            if (idx !== -1) {
              mockWatchHistory[idx] = newRec;
            } else {
              mockWatchHistory.push(newRec);
            }
            results.push(newRec);
          }
        }

        tableChain.select = jest.fn(() => ({
          then: (resolve) => resolve({ data: results, error: null }),
        }));

        return tableChain;
      });

      tableChain.insert = jest.fn((arr) => {
        const records = Array.isArray(arr) ? arr : [arr];
        const inserted = [];
        for (const rec of records) {
          if (table === "media_listings") {
            const newRec = { id: `list-${mockListings.length + 1}`, ...rec };
            mockListings.push(newRec);
            inserted.push(newRec);
          } else if (table === "bookmarks") {
            const newRec = {
              id: `book-${mockBookmarks.length + 1}`,
              created_at: new Date().toISOString(),
              ...rec,
            };
            mockBookmarks.push(newRec);
            inserted.push(newRec);
          }
        }

        tableChain.select = jest.fn(() => ({
          single: jest.fn(async () => ({ data: inserted[0], error: null })),
          then: (resolve) => resolve({ data: inserted, error: null }),
        }));

        tableChain.then = (onFulfilled) => {
          return Promise.resolve(onFulfilled({ data: inserted, error: null }));
        };

        return tableChain;
      });

      tableChain.delete = jest.fn(() => {
        tableChain.eq = jest.fn((col, val) => {
          if (table === "bookmarks" && col === "id") {
            mockBookmarks = mockBookmarks.filter((b) => b.id !== val);
          }
          return tableChain;
        });

        tableChain.then = (onFulfilled) => {
          return Promise.resolve(onFulfilled({ error: null }));
        };

        return tableChain;
      });

      tableChain.update = jest.fn((obj) => {
        tableChain.eq = jest.fn((col, val) => {
          const updatedRecords = [];
          for (const item of mockListings) {
            if (col === "id" && item.id === val) {
              Object.assign(item, obj);
              updatedRecords.push(item);
            }
          }
          tableChain.select = jest.fn(() => ({
            then: (resolve) => resolve({ data: updatedRecords, error: null }),
          }));
          tableChain.then = (onFulfilled) => {
            return Promise.resolve(onFulfilled({ data: updatedRecords, error: null }));
          };
          return tableChain;
        });
        return tableChain;
      });

      return tableChain;
    }),
  })),
}));

// Helper function to apply mock queries
function mockApplyFilters(table, eqQuery = []) {
  let list = [];
  if (table === "media_listings") list = [...mockListings];
  else if (table === "watch_history") list = [...mockWatchHistory];
  else if (table === "bookmarks") list = [...mockBookmarks];

  if (!eqQuery || eqQuery.length === 0) return list;

  return list.filter((item) => {
    return eqQuery.every(({ col, val }) => {
      if (col === "tmdb_id") return item.tmdb_id === val.toString();
      return item[col] === val;
    });
  });
}

// ------------------------------------------------------------------
// Mock TMDB Fetch Calls
// ------------------------------------------------------------------
const originalFetch = global.fetch;

beforeAll(() => {
  global.fetch = jest.fn();
});

afterAll(() => {
  global.fetch = originalFetch;
});

// Import the App and controllers
const app = require("../server");
const { TelegramClient } = require("telegram");

describe("Cinegram Backend API Integration Tests", () => {
  let mockTg;
  let mockDb;

  beforeEach(() => {
    // Reset database tables
    mockListings = [];
    mockWatchHistory = [];
    mockBookmarks = [];

    // Reset Fetch Mock
    global.fetch.mockReset();

    // Create fresh mock instances
    const { createClient } = require("@supabase/supabase-js");
    mockDb = createClient();
    mockTg = new TelegramClient(null, null, null, null);

    // Inject mocks into backend server
    app.setSupabase(mockDb);
    app.setTgClient(mockTg);
  });

  // ==========================================
  // 1. HEALTH ENDPOINT TEST
  // ==========================================
  describe("GET /health", () => {
    it("should return server status details", async () => {
      const response = await request(app).get("/health");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("status", "healthy");
      expect(response.body).toHaveProperty("telegram_connected", true);
      expect(response.body).toHaveProperty("supabase_configured", true);
      expect(response.body).toHaveProperty("tmdb_configured", true);
    });

    it("should return false for telegram_connected if client is missing", async () => {
      app.setTgClient(null);
      const response = await request(app).get("/health");

      expect(response.status).toBe(200);
      expect(response.body.telegram_connected).toBe(false);
    });
  });

  // ==========================================
  // 2. METADATA PROXY ENDPOINTS (TMDB)
  // ==========================================
  describe("GET /metadata/search", () => {
    it("should return mapped TMDB multi search results successfully", async () => {
      global.fetch.mockResolvedValueOnce({
        json: async () => ({
          results: [
            {
              id: 101,
              media_type: "movie",
              title: "Cinegram Movie",
              overview: "The best streaming application.",
              release_date: "2026-05-30",
              poster_path: "/mockPoster.jpg",
              backdrop_path: "/mockBackdrop.jpg",
              vote_average: 9.8,
              genre_ids: [1, 2],
            },
            {
              id: 102,
              media_type: "tv",
              name: "Cinegram TV Show",
              first_air_date: "2025-01-01",
              poster_path: null,
              vote_average: 8.5,
              genre_ids: [3],
            },
            {
              id: 103,
              media_type: "person", // Should be filtered out
              name: "Actor Name",
            },
          ],
        }),
      });

      const response = await request(app).get("/metadata/search?query=Cinegram");

      expect(response.status).toBe(200);
      expect(response.body.results).toHaveLength(2);
      expect(response.body.results[0]).toEqual({
        id: 101,
        type: "movie",
        title: "Cinegram Movie",
        original_title: undefined,
        overview: "The best streaming application.",
        release_date: "2026-05-30",
        release_year: "2026",
        poster_url: "https://image.tmdb.org/t/p/w500/mockPoster.jpg",
        backdrop_url: "https://image.tmdb.org/t/p/original/mockBackdrop.jpg",
        rating: 9.8,
        genres: [1, 2],
      });
    });

    it("should return 400 when search query parameter is missing", async () => {
      const response = await request(app).get("/metadata/search");
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty("error", "Query parameter is required");
    });
  });

  describe("GET /metadata/details", () => {
    it("should fetch movie details, credits, and YouTube trailer url", async () => {
      global.fetch.mockResolvedValueOnce({
        json: async () => ({
          id: 550,
          title: "Fight Club",
          overview: "An insomniac office worker...",
          release_date: "1999-10-15",
          poster_path: "/mockPoster.jpg",
          backdrop_path: null,
          vote_average: 8.4,
          runtime: 139,
          genres: [{ name: "Drama" }],
          videos: {
            results: [
              { type: "Teaser", site: "YouTube", key: "123" },
              { type: "Trailer", site: "YouTube", key: "dQw4w9WgXcQ" },
            ],
          },
          credits: {
            cast: [
              { name: "Brad Pitt", character: "Tyler Durden", profile_path: "/pitt.jpg" },
            ],
          },
        }),
      });

      const response = await request(app).get("/metadata/details?id=550&type=movie");

      expect(response.status).toBe(200);
      expect(response.body).toEqual({
        id: 550,
        type: "movie",
        title: "Fight Club",
        overview: "An insomniac office worker...",
        release_date: "1999-10-15",
        release_year: "1999",
        poster_url: "https://image.tmdb.org/t/p/w500/mockPoster.jpg",
        backdrop_url: null,
        rating: 8.4,
        runtime: 139,
        genres: ["Drama"],
        trailer_url: "https://www.youtube.com/watch?v=dQw4w9WgXcQ",
        cast: [
          {
            name: "Brad Pitt",
            character: "Tyler Durden",
            profile_url: "https://image.tmdb.org/t/p/w185/pitt.jpg",
          },
        ],
      });
    });

    it("should append seasons info if detail type is tv", async () => {
      global.fetch.mockResolvedValueOnce({
        json: async () => ({
          id: 99,
          name: "Loki",
          overview: "Marvel show",
          seasons: [
            {
              id: 200,
              name: "Season 1",
              season_number: 1,
              episode_count: 6,
              poster_path: "/season1.jpg",
              air_date: "2021-06-09",
            },
          ],
        }),
      });

      const response = await request(app).get("/metadata/details?id=99&type=tv");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("seasons");
      expect(response.body.seasons).toHaveLength(1);
      expect(response.body.seasons[0]).toEqual({
        id: 200,
        name: "Season 1",
        season_number: 1,
        episode_count: 6,
        poster_url: "https://image.tmdb.org/t/p/w185/season1.jpg",
        air_date: "2021-06-09",
      });
    });

    it("should return 400 if id or type parameter is missing", async () => {
      const response = await request(app).get("/metadata/details?id=550");
      expect(response.status).toBe(400);
    });
  });

  // ==========================================
  // 3. DATABASE MEDIA LISTINGS ENDPOINTS
  // ==========================================
  describe("Cinegram Media Listings Flow", () => {
    it("should register new media listings and retrieve them", async () => {
      // 1. Initial listings should be empty
      const initialRes = await request(app).get("/listings");
      expect(initialRes.status).toBe(200);
      expect(initialRes.body.listings).toHaveLength(0);

      // 2. Post a new listing
      const newListing = {
        tmdbId: 101,
        title: "Test Movie",
        type: "movie",
        channelId: "-100223344",
        messageId: 42,
        quality: "1080p",
      };

      const postRes = await request(app).post("/listings").send(newListing);
      expect(postRes.status).toBe(201);
      expect(postRes.body.message).toBe("Listing saved successfully!");
      expect(postRes.body.data[0]).toHaveProperty("id");

      // 3. Retrieve listings again
      const finalRes = await request(app).get("/listings");
      expect(finalRes.status).toBe(200);
      expect(finalRes.body.listings).toHaveLength(1);
      expect(finalRes.body.listings[0]).toMatchObject({
        tmdb_id: "101",
        title: "Test Movie",
        type: "movie",
        channel_id: "-100223344",
        message_id: 42,
        quality: "1080p",
      });
    });

    it("should return 400 when missing listing parameters", async () => {
      const response = await request(app).post("/listings").send({ title: "Incomplete" });
      expect(response.status).toBe(400);
      expect(response.body).toHaveProperty("error", "Missing required listing parameters.");
    });
  });

  // ==========================================
  // 3b. AI-POWERED SEMANTIC SEARCH ENDPOINTS
  // ==========================================
  describe("GET /listings/search (Semantic Natural Language)", () => {
    it("should return empty list if query is empty or missing", async () => {
      const res = await request(app).get("/listings/search");
      expect(res.status).toBe(200);
      expect(res.body.results).toHaveLength(0);
    });

    it("should rank mock results semantically by cosine similarity", async () => {
      const res = await request(app).get("/listings/search?q=space");
      expect(res.status).toBe(200);
      expect(res.body.results.length).toBeGreaterThan(0);
      expect(res.body.results[0].item.title).toBe("Interstellar");
    });

    it("should rank dream thief plot semantically to Inception", async () => {
      const res = await request(app).get("/listings/search?q=dream thief");
      expect(res.status).toBe(200);
      expect(res.body.results.length).toBeGreaterThan(0);
      expect(res.body.results[0].item.title).toBe("Inception");
    });
  });

  // ==========================================
  // 4. WATCH HISTORY / PROGRESS ENDPOINTS
  // ==========================================
  describe("Continue Watching Watch History Sync Flow", () => {
    it("should sync watch progress and fetch continue watching list", async () => {
      // 1. Setup an existing indexed listing first
      mockListings.push({
        id: "list-1",
        tmdb_id: "201",
        title: "Star Wars",
        type: "movie",
        channel_id: "-1001122",
        message_id: 5,
        quality: "4K UHD",
      });

      // 2. Post progress without authorization header (uses mock fallback user id)
      const progressPayload = {
        mediaId: 201,
        positionMs: 600000,
        durationMs: 7200000,
        progressPercent: 8.3,
      };

      const progressRes = await request(app).post("/progress").send(progressPayload);
      expect(progressRes.status).toBe(200);
      expect(progressRes.body.message).toBe("Progress synced successfully!");

      // 3. Retrieve continue watching items
      const continueRes = await request(app).get("/continue-watching");
      expect(continueRes.status).toBe(200);
      expect(continueRes.body.continueWatching).toHaveLength(1);
      expect(continueRes.body.continueWatching[0]).toMatchObject({
        listingId: "list-1",
        tmdbId: "201",
        title: "Star Wars",
        type: "movie",
        positionMs: 600000,
        durationMs: 7200000,
        progressPercent: 8.3,
      });
    });

    it("should support custom authorized users using token headers", async () => {
      mockListings.push({
        id: "list-2",
        tmdb_id: "202",
        title: "Inception",
        type: "movie",
        channel_id: "custom-chan",
        message_id: 11,
      });

      const progressPayload = {
        mediaId: 202,
        positionMs: 1500000,
        durationMs: 9000000,
        progressPercent: 16.6,
      };

      // Valid token -> resolves "user-uuid-123"
      const authProgressRes = await request(app)
        .post("/progress")
        .set("Authorization", "Bearer valid-token")
        .send(progressPayload);

      expect(authProgressRes.status).toBe(200);

      // Verify progress records contains user-uuid-123
      expect(mockWatchHistory[0].user_id).toBe("user-uuid-123");
    });

    it("should return 400 when missing progress parameters", async () => {
      const response = await request(app).post("/progress").send({ mediaId: 201 });
      expect(response.status).toBe(400);
    });
  });

  // ==========================================
  // 5. BOOKMARKS FLOW ENDPOINTS
  // ==========================================
  describe("Bookmarks Sync and Vault Flow", () => {
    it("should toggle bookmarking on/off and list all user bookmarks", async () => {
      const listingId = "list-99";
      mockListings.push({
        id: listingId,
        tmdb_id: "305",
        title: "Breaking Bad",
        type: "tv",
        channel_id: "show-channel",
        message_id: 88,
      });

      // 1. Initially bookmarks should be empty
      const initialBookmarksRes = await request(app).get("/bookmarks");
      expect(initialBookmarksRes.status).toBe(200);
      expect(initialBookmarksRes.body.bookmarks).toHaveLength(0);

      // 2. Toggle Bookmark: On
      const toggleOnRes = await request(app).post("/bookmarks").send({ mediaListingId: listingId });
      expect(toggleOnRes.status).toBe(200);
      expect(toggleOnRes.body.bookmarked).toBe(true);
      expect(toggleOnRes.body.message).toBe("Added to vault.");

      // 3. List current bookmarks
      const currentBookmarksRes = await request(app).get("/bookmarks");
      expect(currentBookmarksRes.status).toBe(200);
      expect(currentBookmarksRes.body.bookmarks).toHaveLength(1);
      expect(currentBookmarksRes.body.bookmarks[0]).toMatchObject({
        listingId: "list-99",
        tmdbId: "305",
        title: "Breaking Bad",
        type: "tv",
      });

      // 4. Toggle Bookmark: Off
      const toggleOffRes = await request(app).post("/bookmarks").send({ mediaListingId: listingId });
      expect(toggleOffRes.status).toBe(200);
      expect(toggleOffRes.body.bookmarked).toBe(false);
      expect(toggleOffRes.body.message).toBe("Removed from vault.");

      // 5. Ensure bookmarks list is now empty again
      const finalBookmarksRes = await request(app).get("/bookmarks");
      expect(finalBookmarksRes.body.bookmarks).toHaveLength(0);
    });

    it("should return 400 when toggling without listing ID parameter", async () => {
      const response = await request(app).post("/bookmarks").send({});
      expect(response.status).toBe(400);
    });
  });

  // ==========================================
  // 6. STREAMING PARTIAL RANGE REQUEST VALIDATIONS
  // ==========================================
  describe("Streaming partial / full range requests", () => {
    it("should fail with 400 if channelId or messageId is missing", async () => {
      const response = await request(app).get("/stream?channelId=-100123");
      expect(response.status).toBe(400);
    });

    it("should serve complete file (200 Status) when no range request is provided", async () => {
      const response = await request(app)
        .get("/stream?channelId=-100123&messageId=45")
        .expect(200);

      // Verify response headers
      expect(response.header["accept-ranges"]).toBe("bytes");
      expect(response.header["content-length"]).toBe("1048576"); // 1 MB complete file size
      expect(response.header["content-type"]).toBe("video/mp4");

      // Verify download chunk count (1 MB = 2 aligned chunks of 512KB size)
      // The body payload is filled with characters 'A'
      expect(response.body.length).toBe(1024 * 1024);
      expect(response.body.toString().substring(0, 10)).toBe("AAAAAAAAAA");
    });

    it("should serve partial range (206 Status) with aligned offsets & correct sizing", async () => {
      // Request first 4 KB
      const response = await request(app)
        .get("/stream?channelId=-100123&messageId=45")
        .set("Range", "bytes=0-4095")
        .expect(206);

      expect(response.header["accept-ranges"]).toBe("bytes");
      expect(response.header["content-range"]).toBe("bytes 0-4095/1048576");
      expect(response.header["content-length"]).toBe("4096");
      expect(response.body.length).toBe(4096);
    });

    it("should serve partial slice within range from a single chunk boundary", async () => {
      // Request bytes inside first 512 KB chunk
      const response = await request(app)
        .get("/stream?channelId=-100123&messageId=45")
        .set("Range", "bytes=1000-2999")
        .expect(206);

      expect(response.header["content-range"]).toBe("bytes 1000-2999/1048576");
      expect(response.header["content-length"]).toBe("2000"); // 2999 - 1000 + 1
      expect(response.body.length).toBe(2000);
    });

    it("should serve sliced response spanning multiple chunks seamlessly", async () => {
      // Request bytes spanning chunk boundary (e.g. from 500,000 to 600,000 bytes)
      // Note: first chunk offset is 0-524287 (512KB). Spans boundary at index 524288
      const response = await request(app)
        .get("/stream?channelId=-100123&messageId=45")
        .set("Range", "bytes=500000-600000")
        .expect(206);

      expect(response.header["content-range"]).toBe("bytes 500000-600000/1048576");
      expect(response.header["content-length"]).toBe("100001");
      expect(response.body.length).toBe(100001);
    });

    it("should return 416 range out of bounds", async () => {
      const response = await request(app)
        .get("/stream?channelId=-100123&messageId=45")
        .set("Range", "bytes=2000000-3000000")
        .expect(416);

      expect(response.header["content-range"]).toBe("bytes */1048576");
    });
  });

  // ==========================================
  // 7. BACKGROUND SCANNER REGEX FILENAME PARSING TESTS
  // ==========================================
  describe("Background Scanner Regex Filename Parsing", () => {
    const { parseFilename, getQuality } = require("../scannerService");

    it("should correctly parse movie filenames with years", () => {
      const result1 = parseFilename("Interstellar.2014.1080p.BluRay.x264.mkv");
      expect(result1).toEqual({
        title: "Interstellar",
        year: "2014",
        season: null,
        episode: null,
        type: "movie",
      });

      const result2 = parseFilename("The.Batman.2022.2160p.HEVC.mkv");
      expect(result2).toEqual({
        title: "The Batman",
        year: "2022",
        season: null,
        episode: null,
        type: "movie",
      });
    });

    it("should correctly parse TV series filenames with season and episode numbers", () => {
      const result1 = parseFilename("Stranger.Things.S04E01.1080p.web.x264.mkv");
      expect(result1).toEqual({
        title: "Stranger Things",
        year: null,
        season: 4,
        episode: 1,
        type: "tv",
      });

      const result2 = parseFilename("Breaking.Bad.Season.01.Episode.03.720p.mkv");
      expect(result2).toEqual({
        title: "Breaking Bad",
        year: null,
        season: 1,
        episode: 3,
        type: "tv",
      });
    });

    it("should correctly extract video quality", () => {
      expect(getQuality("Interstellar.2014.1080p.BluRay.x264.mkv")).toBe("1080p");
      expect(getQuality("The.Batman.2022.2160p.HEVC.mkv")).toBe("2160p");
      expect(getQuality("Stranger.Things.S04E01.4k.web.x264.mkv")).toBe("4k");
      expect(getQuality("No.Quality.Specified.mkv")).toBe("1080p");
    });
  });

  // ==========================================
  // 8. SCANNER API ENDPOINT TESTS
  // ==========================================
  describe("Scanner API Endpoints", () => {
    it("should trigger background scan successfully", async () => {
      const response = await request(app)
        .post("/scanner/trigger")
        .send({ channelId: "-100223344" });

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("message", "Scan triggered successfully");
      expect(response.body).toHaveProperty("active", true);
    });

    it("should fetch scanner status and unresolved list", async () => {
      // Mock an unresolved listing in the database first
      mockListings.push({
        id: "unresolved-uuid",
        tmdb_id: "0",
        title: "Unresolved Movie File.2026.1080p.mkv",
        type: "movie",
        channel_id: "-100223344",
        message_id: "99",
        quality: "1080p",
      });

      const response = await request(app).get("/scanner/status");

      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("active");
      expect(response.body.unresolved).toHaveLength(1);
      expect(response.body.unresolved[0]).toMatchObject({
        id: "unresolved-uuid",
        tmdb_id: "0",
        title: "Unresolved Movie File.2026.1080p.mkv",
      });
    });

    it("should resolve an unresolved listing successfully by querying TMDB mock details", async () => {
      mockListings.push({
        id: "unresolved-to-resolve",
        tmdb_id: "0",
        title: "Unresolved.Movie.mkv",
        type: "movie",
        channel_id: "-100223344",
        message_id: "101",
        quality: "1080p",
      });

      global.fetch.mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          id: 777,
          title: "Resolved Awesome Movie",
          overview: "A resolved movie overview",
        }),
      });

      const response = await request(app)
        .post("/listings/resolve")
        .send({
          listingId: "unresolved-to-resolve",
          tmdbId: "777",
          type: "movie",
        });

      expect(response.status).toBe(200);
      expect(response.body.message).toBe("Listing resolved successfully!");
      expect(response.body.data[0]).toMatchObject({
        id: "unresolved-to-resolve",
        tmdb_id: "777",
        title: "Resolved Awesome Movie",
      });
    });
  });

  // ==========================================
  // 9. SUB-PROFILE PARTITIONING / MULTI-USER SEPARATION
  // ==========================================
  describe("Sub-profile Partitioning / Multi-user Separation", () => {
    it("should assert posting watch histories for same video under different sub-profile headers results in completely partitioned progress streams", async () => {
      // 1. Setup an existing indexed listing first
      mockListings.push({
        id: "list-profile-test",
        tmdb_id: "500",
        title: "Profile Partition Test Movie",
        type: "movie",
        channel_id: "chan-profile",
        message_id: 77,
      });

      // 2. Post progress under "profile-a"
      const progressPayloadA = {
        mediaId: 500,
        positionMs: 10000,
        durationMs: 7200000,
        progressPercent: 0.1,
      };
      const resA = await request(app)
        .post("/progress")
        .set("x-cinegram-profile", "profile-a")
        .send(progressPayloadA);
      expect(resA.status).toBe(200);

      // 3. Post progress under "profile-b" (same movie, different position)
      const progressPayloadB = {
        mediaId: 500,
        positionMs: 20000,
        durationMs: 7200000,
        progressPercent: 0.2,
      };
      const resB = await request(app)
        .post("/progress")
        .set("x-cinegram-profile", "profile-b")
        .send(progressPayloadB);
      expect(resB.status).toBe(200);

      // 4. Post progress under "default" profile (same movie, different position)
      const progressPayloadDefault = {
        mediaId: 500,
        positionMs: 30000,
        durationMs: 7200000,
        progressPercent: 0.3,
      };
      const resDefault = await request(app)
        .post("/progress")
        .send(progressPayloadDefault);
      expect(resDefault.status).toBe(200);

      // 5. Retrieve continue watching for "profile-a"
      const continueA = await request(app)
        .get("/continue-watching")
        .set("x-cinegram-profile", "profile-a");
      expect(continueA.status).toBe(200);
      expect(continueA.body.continueWatching).toHaveLength(1);
      expect(continueA.body.continueWatching[0].positionMs).toBe(10000);

      // 6. Retrieve continue watching for "profile-b"
      const continueB = await request(app)
        .get("/continue-watching")
        .set("x-cinegram-profile", "profile-b");
      expect(continueB.status).toBe(200);
      expect(continueB.body.continueWatching).toHaveLength(1);
      expect(continueB.body.continueWatching[0].positionMs).toBe(20000);

      // 7. Retrieve continue watching for "default"
      const continueDefault = await request(app)
        .get("/continue-watching");
      expect(continueDefault.status).toBe(200);
      expect(continueDefault.body.continueWatching).toHaveLength(1);
      expect(continueDefault.body.continueWatching[0].positionMs).toBe(30000);
    });

    it("should assert bookmarks are completely partitioned by sub-profile headers with no overlap", async () => {
      // 1. Setup list
      const listingId = "list-bookmark-test";
      mockListings.push({
        id: listingId,
        tmdb_id: "505",
        title: "Bookmark Partition Test Movie",
        type: "movie",
        channel_id: "chan-bookmark-test",
        message_id: 88,
      });

      // 2. Toggle Bookmark: On for "profile-a"
      const toggleResA = await request(app)
        .post("/bookmarks")
        .set("x-cinegram-profile", "profile-a")
        .send({ mediaListingId: listingId });
      expect(toggleResA.status).toBe(200);
      expect(toggleResA.body.bookmarked).toBe(true);

      // 3. Retrieve bookmarks for "profile-b" (should be empty)
      const listResB = await request(app)
        .get("/bookmarks")
        .set("x-cinegram-profile", "profile-b");
      expect(listResB.status).toBe(200);
      expect(listResB.body.bookmarks).toHaveLength(0);

      // 4. Retrieve bookmarks for "default" (should be empty)
      const listResDefault = await request(app)
        .get("/bookmarks");
      expect(listResDefault.status).toBe(200);
      expect(listResDefault.body.bookmarks).toHaveLength(0);

      // 5. Retrieve bookmarks for "profile-a" (should contain the bookmarked listing)
      const listResA = await request(app)
        .get("/bookmarks")
        .set("x-cinegram-profile", "profile-a");
      expect(listResA.status).toBe(200);
      expect(listResA.body.bookmarks).toHaveLength(1);
      expect(listResA.body.bookmarks[0].listingId).toBe(listingId);
    });
  });

  // ==========================================
  // 10. M3U PARSING & IPTV ENDPOINT TESTS
  // ==========================================
  describe("M3U Playlist Parser & IPTV Endpoints", () => {
    const { parseM3U } = require("../m3uParser");

    it("should correctly parse raw M3U text into formatted channel objects", () => {
      const rawM3U = `
#EXTM3U
#EXTINF:-1 tvg-id="NasaTV" tvg-name="NASA TV" tvg-logo="https://example.com/nasa.png" group-title="Science",NASA HD TV
http://example.com/nasa.m3u8
#EXTINF:-1 group-title="News",Bloomberg Live
https://liveproduseast.global.ssl.fastly.net/ch/us/master.m3u8
      `;
      const channels = parseM3U(rawM3U);
      expect(channels).toHaveLength(2);
      expect(channels[0]).toEqual({
        name: "NASA HD TV",
        logo: "https://example.com/nasa.png",
        url: "http://example.com/nasa.m3u8",
        group: "Science"
      });
      expect(channels[1]).toEqual({
        name: "Bloomberg Live",
        logo: "",
        url: "https://liveproduseast.global.ssl.fastly.net/ch/us/master.m3u8",
        group: "News"
      });
    });

    it("should return pre-bundled free-to-air news/documentary channels by default out of the box", async () => {
      const response = await request(app).get("/iptv/channels");
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("groups");
      expect(response.body.groups).toHaveProperty("Science");
      expect(response.body.groups).toHaveProperty("News");
      expect(response.body.groups.Science).toHaveLength(1);
      expect(response.body.groups.Science[0].name).toBe("NASA HD TV");
    });

    it("should import new M3U playlists and fetch the merged/updated channel list", async () => {
      const rawM3U = `
#EXTM3U
#EXTINF:-1 tvg-logo="https://upload.wikimedia.org/wikipedia/commons/4/40/Al_Jazeera_English_logo.svg" group-title="News",Al Jazeera English
https://live-am.hosting.aljazeera.com/aje/index.m3u8
      `;

      const importRes = await request(app)
        .post("/iptv/import")
        .send({ m3uText: rawM3U });

      expect(importRes.status).toBe(200);
      expect(importRes.body.importedCount).toBe(1);

      const fetchRes = await request(app).get("/iptv/channels");
      expect(fetchRes.status).toBe(200);
      expect(fetchRes.body.groups.News).toHaveLength(3); // Bloomberg, DW, and Al Jazeera
      expect(fetchRes.body.groups.News.some(c => c.name === "Al Jazeera English")).toBe(true);
    });

    it("should handle M3U URL importing by mocking dynamic URL fetch calls", async () => {
      global.fetch.mockResolvedValueOnce({
        ok: true,
        text: async () => `
#EXTM3U
#EXTINF:-1 group-title="Movies",Action Cinema
http://cinema.example.com/stream.m3u8
        `
      });

      const importRes = await request(app)
        .post("/iptv/import")
        .send({ url: "http://example.com/myplaylist.m3u" });

      expect(importRes.status).toBe(200);
      expect(importRes.body.importedCount).toBe(1);

      const fetchRes = await request(app).get("/iptv/channels");
      expect(fetchRes.body.groups).toHaveProperty("Movies");
      expect(fetchRes.body.groups.Movies[0].name).toBe("Action Cinema");
    });

    it("should return 400 if import parameters are missing", async () => {
      const response = await request(app).post("/iptv/import").send({});
      expect(response.status).toBe(400);
    });
  });

  // ==========================================
  // 11. DYNAMIC SCANNER SOURCES CONFIGURATION TESTS
  // ==========================================
  describe("Dynamic Telegram Channel Sources Configuration", () => {
    it("should retrieve the default dynamically configured channels list", async () => {
      const response = await request(app).get("/scanner/channels");
      expect(response.status).toBe(200);
      expect(response.body).toHaveProperty("channels");
      expect(response.body.channels).toHaveLength(3);
      expect(response.body.channels[0]).toHaveProperty("type", "movie");
    });

    it("should update/configure channels dynamically and run sequential scans", async () => {
      const updatedChannels = [
        { id: "-100777777", type: "movie", name: "Custom Movies Channel" },
        { id: "-100888888", type: "anime", name: "Custom Anime Channel" }
      ];

      const updateRes = await request(app)
        .post("/scanner/channels")
        .send({ channels: updatedChannels });

      expect(updateRes.status).toBe(200);
      expect(updateRes.body.channels).toHaveLength(2);
      expect(updateRes.body.channels[1]).toEqual({
        id: "-100888888",
        type: "anime",
        name: "Custom Anime Channel"
      });

      // Assert retrieving channels matches the updated list
      const getRes = await request(app).get("/scanner/channels");
      expect(getRes.body.channels).toEqual(updatedChannels);
    });

    it("should fail updating channels with 400 when missing parameter or not an array", async () => {
      const response = await request(app).post("/scanner/channels").send({});
      expect(response.status).toBe(400);
    });
  });
});

