import { z } from "zod";

/**
 * Server-side environment validation — fails fast at boot on bad config.
 * BACKEND_URL is consumed only by BFF route handlers; it is never exposed
 * to the browser bundle (no NEXT_PUBLIC_* usage for backend access).
 */
const envSchema = z.object({
  BACKEND_URL: z.string().url().default("http://localhost:8080"),
  NODE_ENV: z.enum(["development", "test", "production"]).default("development"),
});

export const env = envSchema.parse({
  BACKEND_URL: process.env.BACKEND_URL,
  NODE_ENV: process.env.NODE_ENV,
});
