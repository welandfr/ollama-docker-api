#!/bin/sh
# Runs on the HOST. Starts the container detached, waits for every model pull to
# finish, then prints the URLs and the settings the container came up with.
#
# The work inside the container is done by entrypoint.sh.
set -e
cd "$(dirname "$0")"

[ -f .env ] && { set -a; . ./.env; set +a; }
PORT=${OLLAMA_PORT:-11434}
MODELS=${OLLAMA_MODEL_LIST:-${OLLAMA_MODEL:-qwen3.5:2b}}
MODELS=$(echo "$MODELS" | tr ',' ' ')
TIMEOUT=${UP_TIMEOUT:-900}

docker compose up -d "$@"

printf 'waiting for: %s ' "$MODELS"
i=0
while [ "$i" -lt "$TIMEOUT" ]; do
  tags=$(curl -fsS "http://localhost:$PORT/api/tags" 2>/dev/null || true)
  missing=0
  for m in $MODELS; do
    echo "$tags" | grep -qF "$m" || missing=1
  done
  if [ "$missing" -eq 0 ] && [ -n "$tags" ]; then
    printf '\n\n'
    echo '=========================================================='
    echo '  Ollama ready:'
    echo "  http://localhost:$PORT/api/tags   (installed, all servable)"
    echo "  http://localhost:$PORT/api/ps     (loaded in memory)"
    echo ''
    echo "  Context: ${OLLAMA_CONTEXT_LENGTH:-unset — Ollama picks from VRAM (4k under 24GiB)}"
    echo "  KV cache: ${OLLAMA_KV_CACHE_TYPE:-f16}, flash attention: ${OLLAMA_FLASH_ATTENTION:-0}"
    echo "  Resident models: ${OLLAMA_MAX_LOADED_MODELS:-1}, parallel slots: ${OLLAMA_NUM_PARALLEL:-1}"
    echo ''
    echo '  After the first request, confirm PROCESSOR reads 100% GPU:'
    echo '    docker compose exec ollama ollama ps'
    echo '=========================================================='
    echo ''
    exit 0
  fi
  printf '.'
  sleep 2
  i=$((i + 2))
done

printf '\n\n'
echo "Timed out after ${TIMEOUT}s waiting for: $MODELS"
echo 'A pull may still be running: docker compose logs -f ollama'
echo ''
echo "  http://localhost:$PORT/api/tags"
