require("dotenv").config({ path: "../.env" });
const { TelegramClient } = require("telegram");
const { StringSession } = require("telegram/sessions");
const input = require("input");

const apiId = parseInt(process.env.TELEGRAM_API_ID);
const apiHash = process.env.TELEGRAM_API_HASH;

if (!apiId || !apiHash) {
  console.error("ERROR: TELEGRAM_API_ID or TELEGRAM_API_HASH is missing from the .env file!");
  process.exit(1);
}

const stringSession = new StringSession(""); // Start a new session

(async () => {
  console.log("Connecting to Telegram...");
  const client = new TelegramClient(stringSession, apiId, apiHash, {
    connectionRetries: 5,
  });

  try {
    await client.start({
      phoneNumber: async () => await input.text("Enter your phone number (e.g. +1234567890): "),
      password: async () => await input.text("Enter your 2FA password (leave empty if not enabled): "),
      phoneCode: async () => await input.text("Enter the SMS/Telegram code you received: "),
      onError: (err) => console.error("Error during authentication:", err),
    });

    console.log("\n==================================================");
    console.log("         SUCCESSFULLY CONNECTED TO TELEGRAM!      ");
    console.log("==================================================");
    
    const sessionString = client.session.save();
    
    console.log("\nYOUR SECURE TELEGRAM_SESSION_STRING IS:\n");
    console.log(sessionString);
    console.log("\n==================================================");
    console.log("1. Copy the long session string above.");
    console.log("2. Paste it in your .env file at the root of the project as:");
    console.log("   TELEGRAM_SESSION_STRING=\"your_copied_string_here\"");
    console.log("==================================================\n");

  } catch (error) {
    console.error("An error occurred during execution:", error);
  } finally {
    await client.disconnect();
    process.exit(0);
  }
})();
