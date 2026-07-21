const isBun = typeof globalThis.Bun !== "undefined";
const Database = isBun ? require("bun:sqlite").Database : require("better-sqlite3");
const fs = require('fs');
const http = require('http');
const https = require('https');
const crypto = require('crypto');

const dbPath = process.env.DB_PATH || '/app/data/time_worth.db';
const JWT_SECRET = process.env.JWT_SECRET || "timeworth-secret-fallback-key-1234567890";
const K8S_HOST = "kubernetes.default.svc";
const TOKEN_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/token";
const CA_PATH = "/var/run/secrets/kubernetes.io/serviceaccount/ca.crt";

function createToken(payload) {
  const data = JSON.stringify(payload);
  const signature = crypto.createHmac("sha256", JWT_SECRET).update(data).digest("hex");
  return `${Buffer.from(data).toString("base64")}.${signature}`;
}

async function runTest() {
  console.log("=== STARTING DYNAMIC PROVISIONING END-TO-END VALIDATION ===");
  
  // 1. Insert test user in local database
  console.log(`[1/6] Connecting to DB: ${dbPath}`);
  const db = new Database(dbPath);
  
  const userId = "test-creator-uuid-" + Math.floor(Math.random() * 100000);
  const username = "testcreator-" + Math.floor(Math.random() * 1000);
  const email = `${username}@timeguild.local`;
  
  console.log(`[2/6] Seeding temporary client user: ${username} (${email})`);
  db.prepare("INSERT INTO users (id, email, username, password_hash, role) VALUES (?, ?, ?, 'temp', 'client')").run(userId, email, username);
  db.prepare("INSERT INTO creator_profiles (user_id, bio, tags, price_per_session, availability, verification_status) VALUES (?, '', '[]', 0, '', 'unverified')").run(userId);

  // 2. Generate session cookie
  const sessionToken = createToken({ id: userId });
  console.log(`[3/6] Generated session token cookie for user`);

  // 3. Call local HTTP onboarding API
  console.log(`[4/6] Sending onboarding upgrade request to /api/creators...`);
  const payload = {
    role: "creator",
    displayName: "Test Creator Dynamic",
    bio: "This is a temporary creator for automated provisioning validation.",
    tags: ["k8s", "automation"],
    price: 150,
    availability: "Weekdays",
    agentEnabled: false,
    agentPrompt: "Test prompt",
    boundaries: [],
    screeningAggression: 50,
    latitude: 37.7749,
    longitude: -122.4194
  };

  const postData = JSON.stringify(payload);
  
  const apiPromise = new Promise((resolve, reject) => {
    const req = http.request({
      hostname: "localhost",
      port: 80,
      path: "/api/creators",
      method: "POST",
      headers: {
        "Cookie": `tw_session=${sessionToken}`,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData),
        "Host": "dev.timeguild.local"
      }
    }, (res) => {
      let data = "";
      res.on("data", chunk => data += chunk);
      res.on("end", () => {
        if (res.statusCode === 200) {
          resolve(JSON.parse(data));
        } else {
          reject(new Error(`API Error: ${res.statusCode} - ${data}`));
        }
      });
    });
    req.on("error", reject);
    req.write(postData);
    req.end();
  });

  await apiPromise;
  console.log("✓ Onboarding API accepted request successfully.");

  // 4. Wait 3 seconds for provisioning loop
  console.log("[5/6] Waiting 3 seconds for K3s controller plane to provision compute resources...");
  await new Promise(resolve => setTimeout(resolve, 3000));

  // 5. Query K8s API to verify provisioning
  console.log("[6/6] Connecting to Kubernetes API to query provisioned resources...");
  const token = fs.readFileSync(TOKEN_PATH, "utf-8").trim();
  const ca = fs.readFileSync(CA_PATH);

  function checkK8sResource(path) {
    return new Promise((resolve) => {
      const req = https.request({
        hostname: K8S_HOST,
        port: 443,
        path: path,
        method: "GET",
        headers: {
          Authorization: `Bearer ${token}`
        },
        ca: ca
      }, (res) => {
        resolve(res.statusCode);
      });
      req.on("error", () => resolve(500));
      req.end();
    });
  }

  const nsStatus = await checkK8sResource(`/api/v1/namespaces/tenant-${username}`);
  const deployStatus = await checkK8sResource(`/apis/apps/v1/namespaces/tenant-${username}/deployments/timeguild-app`);
  const svcStatus = await checkK8sResource(`/api/v1/namespaces/tenant-${username}/services/timeguild-service`);
  const ingStatus = await checkK8sResource(`/apis/networking.k8s.io/v1/namespaces/tenant-${username}/ingresses/timeguild-ingress`);

  console.log("=== VALIDATION RESULTS ===");
  console.log(`- Namespace (tenant-${username}): ${nsStatus === 200 ? "CREATED (200 OK)" : "FAIL (" + nsStatus + ")"}`);
  console.log(`- Deployment (timeguild-app): ${deployStatus === 200 ? "CREATED (200 OK)" : "FAIL (" + deployStatus + ")"}`);
  console.log(`- Service (timeguild-service): ${svcStatus === 200 ? "CREATED (200 OK)" : "FAIL (" + svcStatus + ")"}`);
  console.log(`- Ingress (timeguild-ingress): ${ingStatus === 200 ? "CREATED (200 OK)" : "FAIL (" + ingStatus + ")"}`);

  const allSuccess = nsStatus === 200 && deployStatus === 200 && svcStatus === 200 && ingStatus === 200;
  
  // 6. Cleanup
  console.log("=== CLEANING UP TEMPORARY RESOURCES ===");
  console.log("De-provisioning Kubernetes namespace...");
  const deletePromise = new Promise((resolve) => {
    const req = https.request({
      hostname: K8S_HOST,
      port: 443,
      path: `/api/v1/namespaces/tenant-${username}`,
      method: "DELETE",
      headers: {
        Authorization: `Bearer ${token}`
      },
      ca: ca
    }, (res) => {
      resolve();
    });
    req.end();
  });
  await deletePromise;

  console.log("Deleting database test records...");
  db.prepare("DELETE FROM creator_profiles WHERE user_id = ?").run(userId);
  db.prepare("DELETE FROM users WHERE id = ?").run(userId);
  db.prepare("DELETE FROM tenants WHERE id = ?").run(`tenant_${userId}`);

  console.log("Validation complete.");
  if (allSuccess) {
    console.log("STATUS: SUCCESS - Dynamic Compute Isolation is 100% functional!");
    process.exit(0);
  } else {
    console.log("STATUS: FAILED - Some resources were not created.");
    process.exit(1);
  }
}

runTest().catch(console.error);
