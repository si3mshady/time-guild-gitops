import { NextResponse } from "next/server";
import { Pool } from "pg";

const pool = new Pool({
  host: process.env.DB_HOST || "localhost",
  port: parseInt(process.env.DB_PORT || "5432"),
  user: process.env.DB_USER || "postgres",
  password: process.env.DB_PASSWORD || "postgres",
  database: process.env.DB_NAME || "devsecops_lab_db",
  ssl: process.env.DB_SSL === "true" ? { rejectUnauthorized: false } : false,
  connectionTimeoutMillis: 5000,
});

export async function GET() {
  const startTime = Date.now();
  try {
    const client = await pool.connect();
    const result = await client.query("SELECT NOW() as db_time, VERSION() as db_version;");
    client.release();

    const latencyMs = Date.now() - startTime;

    return NextResponse.json({
      status: "healthy",
      environment: process.env.APP_ENV || "dev",
      database: {
        connected: true,
        host: process.env.DB_HOST ? process.env.DB_HOST.split(".")[0] + "...[redacted]" : "localhost",
        databaseName: process.env.DB_NAME || "devsecops_lab_db",
        serverTimestamp: result.rows[0].db_time,
        version: result.rows[0].db_version,
        queryLatencyMs: `${latencyMs}ms`,
      },
      timestamp: new Date().toISOString(),
    });
  } catch (error: any) {
    return NextResponse.json(
      {
        status: "unhealthy",
        environment: process.env.APP_ENV || "dev",
        database: {
          connected: false,
          error: error.message,
        },
        timestamp: new Date().toISOString(),
      },
      { status: 500 }
    );
  }
}
