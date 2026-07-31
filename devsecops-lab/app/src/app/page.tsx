export default function Home() {
  const env = process.env.APP_ENV || process.env.NODE_ENV || "development";

  return (
    <main style={{ padding: "3rem", fontFamily: "system-ui, sans-serif", maxWidth: "800px", margin: "0 auto" }}>
      <header style={{ borderBottom: "2px solid #eaeaea", paddingBottom: "1rem" }}>
        <h1>🛡️ DevSecOps Learning Lab</h1>
        <p style={{ fontSize: "1.2rem", color: "#666" }}>
          Environment: <strong style={{ color: "#0070f3" }}>{env.toUpperCase()}</strong>
        </p>
      </header>

      <section style={{ marginTop: "2rem" }}>
        <h2>System Status & Verification</h2>
        <div style={{ padding: "1.5rem", borderRadius: "8px", backgroundColor: "#f5f5f5", border: "1px solid #ddd" }}>
          <p><strong>Runtime:</strong> Next.js 14 Standalone Container (Non-root user: nextjs)</p>
          <p><strong>Compute:</strong> AWS ECS (Fargate / EC2)</p>
          <p><strong>Database Target:</strong> AWS RDS PostgreSQL (`db.t4g.micro` / `db.t3.micro` Free Tier)</p>
        </div>
      </section>

      <section style={{ marginTop: "2rem" }}>
        <h2>Database Connection Check</h2>
        <p>Click below or query the endpoint to test live RDS PostgreSQL integration:</p>
        <a
          href="/api/db-check"
          style={{
            display: "inline-block",
            padding: "0.75rem 1.5rem",
            backgroundColor: "#0070f3",
            color: "#fff",
            borderRadius: "6px",
            textDecoration: "none",
            fontWeight: "bold",
          }}
        >
          Execute Live /api/db-check ➔
        </a>
      </section>
    </main>
  );
}
