const crypto = require('crypto');
const http = require('http');

const JWT_SECRET = process.env.JWT_SECRET || "timeworth-secret-fallback-key-1234567890";
const fs = require("fs");
const path = require("path");

let userId = "858f308a-126d-442b-a524-b44e4e7a8001"; // Fallback to current known ID
let resolvedUsername = "si3mshady";

const { execSync } = require('child_process');

try {
  const result = execSync("python3 -c 'import sqlite3; conn = sqlite3.connect(\"/var/lib/timeguild/data-dev/time_worth.db\"); c = conn.cursor(); c.execute(\"select id, username from users where role=\\\"creator\\\" order by created_at desc limit 1\"); print(c.fetchone())'").toString().trim();
  const match = result.match(/\('([^']+)',\s*'([^']+)'\)/);
  if (match) {
    userId = match[1];
    resolvedUsername = match[2];
    console.log(`[Script] Found dynamic creator via Python: ${userId} (${resolvedUsername})`);
  }
} catch (e) {
  // Fall back to defaults
}

function createToken(payload) {
  const data = JSON.stringify(payload);
  const signature = crypto.createHmac("sha256", JWT_SECRET).update(data).digest("hex");
  return `${Buffer.from(data).toString("base64")}.${signature}`;
}

const token = createToken({ id: userId });
const payload = {
  role: "creator",
  displayName: resolvedUsername,
  bio: "Time Guild Creator",
  tags: ["development"],
  price: 100,
  availability: "Weekday evenings",
  agentEnabled: true,
  agentPrompt: "You are the booking assistant for the expert. Ask the client what topic they want to discuss and make sure they confirm they have read the bio. Once they answer, say: \"Criteria met! You are now qualified to book.\"",
  boundaries: [],
  screeningAggression: 50
};

const postData = JSON.stringify(payload);

const req = http.request({
  hostname: "localhost",
  port: 80,
  path: "/api/creators",
  method: "POST",
  headers: {
    "Cookie": `tw_session=${token}`,
    "Content-Type": "application/json",
    "Content-Length": Buffer.byteLength(postData),
    "Host": "timeguild.xyz"
  }
}, (res) => {
  let data = "";
  res.on("data", chunk => data += chunk);
  res.on("end", () => {
    console.log(`Status: ${res.statusCode}`);
    console.log(`Response: ${data}`);
  });
});

req.on("error", console.error);
req.write(postData);
req.end();
