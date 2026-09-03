import { defineConfig } from "vite";

// Set by scripts/start-windows.ps1 -Tailscale to the current Tailscale MagicDNS
// hostname, so Vite accepts requests proxied in by `tailscale serve` without
// falling back to the unsafe allowedHosts: true.
const additionalAllowedHost = process.env.__VITE_ADDITIONAL_SERVER_ALLOWED_HOSTS;

export default defineConfig({
  server: {
    host: "127.0.0.1",
    port: 8765,
    strictPort: true,
    allowedHosts: additionalAllowedHost ? [additionalAllowedHost] : undefined,
    proxy: {
      "/data.json": "http://127.0.0.1:8766",
      "/api": "http://127.0.0.1:8766"
    }
  }
});
