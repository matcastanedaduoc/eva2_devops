#!/bin/sh
set -e

# Runtime environment variable injection for the SPA.
# Replaces placeholder values in the built JS with actual env vars.
# This allows a single Docker image to be used across environments.

echo "window.__ENV__ = {" > /usr/share/nginx/html/env-config.js
echo "  VITE_VENTAS_API_URL: \"${VITE_VENTAS_API_URL:-http://localhost:8080}\"," >> /usr/share/nginx/html/env-config.js
echo "  VITE_DESPACHOS_API_URL: \"${VITE_DESPACHOS_API_URL:-http://localhost:8081}\"" >> /usr/share/nginx/html/env-config.js
echo "};" >> /usr/share/nginx/html/env-config.js

exec "$@"
