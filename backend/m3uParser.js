/**
 * Utility to parse M3U playlists
 */

/**
 * Parses M3U playlist content into an array of channel objects.
 * @param {string} m3uText - The raw M3U text content.
 * @returns {Array<{name: string, logo: string, url: string, group: string}>}
 */
function parseM3U(m3uText) {
  if (!m3uText) return [];
  const lines = m3uText.split(/\r?\n/);
  const channels = [];
  let currentChannel = null;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i].trim();
    if (!line) continue;

    if (line.startsWith("#EXTINF:")) {
      currentChannel = {};
      
      // Extract group-title
      const groupMatch = line.match(/group-title="([^"]+)"/i) || line.match(/group-title='([^']+)'/i);
      currentChannel.group = groupMatch ? groupMatch[1] : "Uncategorized";

      // Extract logo
      const logoMatch = line.match(/tvg-logo="([^"]+)"/i) || line.match(/tvg-logo='([^']+)'/i);
      currentChannel.logo = logoMatch ? logoMatch[1] : "";

      // Extract name from tvg-name first
      const nameAttrMatch = line.match(/tvg-name="([^"]+)"/i) || line.match(/tvg-name='([^']+)'/i);
      let name = nameAttrMatch ? nameAttrMatch[1] : "";

      // Fallback: extract name after the last comma
      const commaIndex = line.lastIndexOf(",");
      if (commaIndex !== -1) {
        const afterComma = line.substring(commaIndex + 1).trim();
        if (afterComma) {
          name = afterComma;
        }
      }

      currentChannel.name = name || "Unknown Channel";
    } else if (line.startsWith("#")) {
      // Skip other tag lines like #EXTM3U, #EXTVLCOPT, etc.
      continue;
    } else {
      // It's a stream URL
      if (currentChannel) {
        currentChannel.url = line;
        channels.push(currentChannel);
        currentChannel = null;
      }
    }
  }

  return channels;
}

module.exports = {
  parseM3U
};
