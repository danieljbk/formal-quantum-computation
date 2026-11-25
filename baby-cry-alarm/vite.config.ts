/// <reference types="vitest" />
import { defineConfig, type Plugin } from "vite";
import react from "@vitejs/plugin-react";

/**
 * Make dist/index.html playable when opened straight from disk (file://):
 * browsers block `type="module"` scripts and `crossorigin` assets on file://,
 * so emit a classic deferred script and drop the crossorigin attributes.
 */
function fileProtocolFriendly(): Plugin {
  return {
    name: "file-protocol-friendly",
    apply: "build",
    enforce: "post",
    transformIndexHtml(html) {
      return html
        .replace(/<script type="module" crossorigin /g, "<script defer ")
        .replace(/<script type="module" /g, "<script defer ")
        .replace(/ crossorigin(?=[ >])/g, "");
    },
  };
}

export default defineConfig({
  // Relative base so dist/index.html works from any path (CI preview packaging).
  base: "./",
  plugins: [react(), fileProtocolFriendly()],
  build: {
    modulePreload: false,
    rollupOptions: {
      output: { format: "iife", inlineDynamicImports: true },
    },
  },
  test: {
    environment: "jsdom",
    include: ["tests/**/*.test.{ts,tsx}"],
  },
});
