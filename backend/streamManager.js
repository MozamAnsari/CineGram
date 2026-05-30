const { Api } = require("telegram");

const CHUNK_SIZE = 512 * 1024; // 512 KB chunk size (must be divisible by 4096)
const CONCURRENT_WORKERS = 4;  // Number of parallel chunk downloads

/**
 * Handle direct streaming from a Telegram channel message.
 * Supports standard HTTP Range requests, aligned to Telegram's 4KB MTProto constraint.
 */
async function handleStream(client, channelId, messageId, req, res) {
  try {
    // 1. Resolve the message containing the video document
    let peer;
    if (channelId.startsWith("-100")) {
      peer = BigInt(channelId);
    } else {
      peer = channelId;
    }

    console.log(`[Stream] Fetching message ID ${messageId} from channel ${channelId}`);
    const messages = await client.getMessages(peer, { ids: [parseInt(messageId)] });
    
    if (!messages || messages.length === 0 || !messages[0].media || !messages[0].media.document) {
      console.error(`[Stream] Media document not found in message ${messageId}`);
      return res.status(404).send("Media document not found.");
    }

    const doc = messages[0].media.document;
    const fileSize = Number(doc.size);
    const mimeType = doc.mimeType || "video/mp4";

    console.log(`[Stream] File: size=${fileSize} bytes, mimeType=${mimeType}`);

    // Create the input location for GramJS MTProto calls
    const fileLocation = new Api.InputDocumentFileLocation({
      id: doc.id,
      accessHash: doc.accessHash,
      fileReference: doc.fileReference,
      thumbSize: "",
    });

    // 2. Parse HTTP Range header
    let startBytes = 0;
    let endBytes = fileSize - 1;
    const rangeHeader = req.headers.range;

    if (rangeHeader) {
      const parts = rangeHeader.replace(/bytes=/, "").split("-");
      startBytes = parseInt(parts[0], 10);
      endBytes = parts[1] ? parseInt(parts[1], 10) : fileSize - 1;
      
      // Safety bounds check
      if (startBytes >= fileSize || endBytes >= fileSize || startBytes > endBytes) {
        res.writeHead(416, { "Content-Range": `bytes */${fileSize}` });
        return res.end();
      }

      res.status(206);
      res.setHeader("Content-Range", `bytes ${startBytes}-${endBytes}/${fileSize}`);
      console.log(`[Stream] Range request: ${startBytes} to ${endBytes} (${endBytes - startBytes + 1} bytes)`);
    } else {
      res.status(200);
      console.log(`[Stream] Full file request: 0 to ${endBytes}`);
    }

    const requestedLength = endBytes - startBytes + 1;
    res.setHeader("Accept-Ranges", "bytes");
    res.setHeader("Content-Length", requestedLength);
    res.setHeader("Content-Type", mimeType);

    // 3. Setup Streaming Pipeline
    let isClientClosed = false;

    req.on("close", () => {
      console.log("[Stream] Client disconnected, canceling workers...");
      isClientClosed = true;
    });

    // Telegram MTProto constraints:
    // - Offset must be a multiple of 4096 (4KB)
    // - Limit must be a multiple of 4096 and <= 1048576 (1MB)
    const alignTo4KB = (val, roundUp = false) => {
      const remainder = val % 4096;
      if (remainder === 0) return val;
      return roundUp ? val + (4096 - remainder) : val - remainder;
    };

    // Calculate aligned offsets
    const alignedStart = alignTo4KB(startBytes, false); 
    const alignedEnd = Math.min(alignTo4KB(endBytes + 1, true), fileSize);

    console.log(`[Stream] Aligned range: ${alignedStart} to ${alignedEnd}`);

    // Create chunks queue
    const chunks = [];
    for (let offset = alignedStart; offset < alignedEnd; offset += CHUNK_SIZE) {
      const limit = Math.min(CHUNK_SIZE, alignedEnd - offset);
      chunks.push({ offset, limit, index: chunks.length });
    }

    console.log(`[Stream] Created ${chunks.length} aligned chunks to download.`);

    // Active workers cache and state
    let nextChunkToWrite = 0;
    const completedChunks = new Map(); // index -> Buffer
    let activeDownloadsCount = 0;
    let currentQueueIndex = 0;

    return new Promise((resolve) => {
      const downloadNext = async () => {
        if (isClientClosed || currentQueueIndex >= chunks.length) return;

        const chunk = chunks[currentQueueIndex++];
        activeDownloadsCount++;

        try {
          // Request chunk from Telegram
          const buffer = await client.invoke(
            new Api.upload.GetFile({
              location: fileLocation,
              offset: BigInt(chunk.offset),
              limit: chunk.limit,
            })
          );

          if (isClientClosed) return;

          completedChunks.set(chunk.index, buffer.bytes);
          activeDownloadsCount--;

          // Attempt to flush completed chunks to client response in order
          flushQueue();
          
          // Spawn next download
          downloadNext();
        } catch (err) {
          console.error(`[Stream] Error downloading chunk index ${chunk.index}:`, err);
          activeDownloadsCount--;
          if (!isClientClosed) {
            // Put chunk back to retries or abort stream
            res.destroy();
            resolve();
          }
        }
      };

      const flushQueue = () => {
        while (completedChunks.has(nextChunkToWrite)) {
          if (isClientClosed) return;

          let rawBuffer = completedChunks.get(nextChunkToWrite);
          completedChunks.delete(nextChunkToWrite);

          const currentChunk = chunks[nextChunkToWrite];

          // Determine slicing parameters for client range boundaries
          let sliceStart = 0;
          let sliceEnd = rawBuffer.length;

          // For the first chunk, slice off bytes before the startBytes
          if (nextChunkToWrite === 0) {
            sliceStart = startBytes - currentChunk.offset;
          }

          // For the last chunk, slice off bytes after the endBytes
          if (nextChunkToWrite === chunks.length - 1) {
            const lastChunkOffset = currentChunk.offset;
            sliceEnd = (endBytes - lastChunkOffset) + 1;
          }

          // Write slice
          if (sliceStart > 0 || sliceEnd < rawBuffer.length) {
            rawBuffer = rawBuffer.subarray(sliceStart, sliceEnd);
          }

          res.write(rawBuffer);
          nextChunkToWrite++;
        }

        // Check if finished
        if (nextChunkToWrite === chunks.length) {
          res.end();
          console.log("[Stream] Streaming completed successfully.");
          resolve();
        }
      };

      // Start initial parallel workers
      for (let i = 0; i < Math.min(CONCURRENT_WORKERS, chunks.length); i++) {
        downloadNext();
      }
    });

  } catch (err) {
    console.error("[Stream] Fatal stream error:", err);
    if (!res.headersSent) {
      res.status(500).send("Internal Streaming Error");
    }
  }
}

module.exports = { handleStream };
