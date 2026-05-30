const autocannon = require("autocannon");
const { spawn } = require("child_process");
const http = require("http");

console.log("🚀 Starting Cinegram High-Concurrency Performance Benchmark Harness...");

// 1. Stand up a temporary Express instance on port 3001 to run load tests
const port = 3001;
const env = { ...process.env, PORT: port.toString(), SUPABASE_URL: "http://localhost:54321", SUPABASE_KEY: "mockKey" };
const child = spawn("node", ["server.js"], { env, cwd: __dirname });

child.stdout.on("data", (data) => {
  // Silence server output to keep benchmark console clean unless error
});

child.stderr.on("data", (data) => {
  console.error(`[Server Error] ${data}`);
});

// Helper to poll if temporary server is live
function checkServer(attempts = 15, delay = 1000) {
  return new Promise((resolve, reject) => {
    const request = http.get(`http://localhost:${port}/health`, (res) => {
      if (res.statusCode === 200) {
        resolve();
      } else {
        retry();
      }
    });

    request.on("error", () => {
      retry();
    });

    function retry() {
      if (attempts > 0) {
        setTimeout(() => {
          checkServer(attempts - 1, delay).then(resolve, reject);
        }, delay);
      } else {
        reject(new Error("Cinegram Express server failed to boot on port " + port));
      }
    }
  });
}

// 2. Main benchmarking execution loop
checkServer()
  .then(async () => {
    console.log("⚡ Cinegram server verified online! Mounting autocannon stress test...");

    const instance = autocannon({
      url: `http://localhost:${port}/health`,
      connections: 50, // 50 concurrent sockets open
      pipelining: 1,
      duration: 5 // 5 seconds duration
    }, (err, result) => {
      if (err) {
        console.error("Benchmark error:", err);
      } else {
        console.log("\n📊 --- BENCHMARK PERFORMANCE RESULTS ---");
        console.log(`Target URL:       http://localhost:${port}/health`);
        console.log(`Total Requests:   ${result.requests.sent}`);
        console.log(`Average Latency:  ${result.latency.average} ms`);
        console.log(`Max Latency:      ${result.latency.max} ms`);
        console.log(`Throughput Rate:  ${(result.throughput.average / 1024 / 1024).toFixed(2)} MB/s`);
        console.log(`Success Count:    ${result.requests.average} reqs/sec`);
        console.log("-----------------------------------------\n");
      }
      
      // Clean up server process
      child.kill("SIGTERM");
      process.exit(0);
    });

    // Output progress feedback
    autocannon.track(instance, { renderProgressBar: true });
  })
  .catch((err) => {
    console.error("Setup failed:", err);
    child.kill("SIGTERM");
    process.exit(1);
  });
