import process from "node:process";
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

const port = Number(process.env.AI_CODING_DASHBOARD_PORT ?? "8768");

export default defineConfig({
  plugins: [react()],
  server: {
    host: process.env.AI_CODING_DASHBOARD_HOST ?? "127.0.0.1",
    port,
    strictPort: true,
  },
  preview: {
    host: process.env.AI_CODING_DASHBOARD_HOST ?? "127.0.0.1",
    port,
    strictPort: true,
  },
});
