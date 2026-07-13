const fs = require("fs");
const path = require("path");

const file = path.join(__dirname, "../../src/app/page.tsx");

if (!fs.existsSync(file)) {
  console.error(`Error: File not found at ${file}`);
  process.exit(1);
}

let content = fs.readFileSync(file, "utf8");
const target = `            <div className="inline-flex items-center gap-2 rounded-full border border-rose-500/50 bg-rose-500/10 px-3 py-1 text-xs text-rose-400 backdrop-blur">
              <span className="size-1.5 rounded-full bg-rose-500 animate-pulse" /> GitOps Live Sync Demo
            </div>`;
const replacement = `            <div className="inline-flex items-center gap-2 rounded-full border border-border/70 bg-card/60 px-3 py-1 text-xs text-muted-foreground backdrop-blur">
              <span className="size-1.5 rounded-full bg-emerald-500" /> Now in private beta
            </div>`;

if (content.includes(target)) {
  fs.writeFileSync(file, content.replace(target, replacement), "utf8");
  console.log("✅ Restored hero banner to Now in private beta!");
} else {
  console.log("⚠️ Target text not found. Already in original state?");
}
