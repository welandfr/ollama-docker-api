#!/bin/sh
# Start the Ollama container detached, wait for the model pull to finish,
# then print the URLs for testing in a browser.
set -e
cd "$(dirname "$0")"

[ -f .env ] && { set -a; . ./.env; set +a; }
PORT=${OLLAMA_PORT:-11434}
MODEL=${OLLAMA_MODEL:-qwen-3.5:2b}
TIMEOUT=${UP_TIMEOUT:-900}

docker compose up -d "$@"

printf 'waiting for %s ' "$MODEL"
i=0
while [ "$i" -lt "$TIMEOUT" ]; do
  if curl -fsS "http://localhost:$PORT/api/tags" 2>/dev/null | grep -qF "$MODEL"; then
    printf '\n\n'
    echo '=========================================================='
    echo '  Ollama ready:'
    echo "  http://localhost:$PORT/api/tags   (installed models)"
    echo "  http://localhost:$PORT/api/ps     (loaded in memory)"
    echo '=========================================================='
    echo ''
    exit 0
  fi
  printf '.'
  sleep 2
  i=$((i + 2))
done

printf '\n\n'
echo "Timed out after ${TIMEOUT}s waiting for $MODEL."
echo 'The pull may still be running: docker compose logs -f ollama'
echo ''
echo "  http://localhost:$PORT/api/tags"
