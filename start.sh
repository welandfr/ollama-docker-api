#!/bin/sh
# Container entrypoint: start the Ollama server, pull every model in the list,
# then stay in the foreground.
set -e

ollama serve &

# Wait for the server to answer instead of a fixed sleep.
i=0
while [ "$i" -lt 60 ]; do
  ollama list >/dev/null 2>&1 && break
  i=$((i + 1))
  sleep 1
done

# Comma- or space-separated. OLLAMA_MODEL is kept for backwards compatibility.
MODELS=${OLLAMA_MODEL_LIST:-${OLLAMA_MODEL:-qwen3.5:2b}}

for m in $(echo "$MODELS" | tr ',' ' '); do
  echo "pulling $m"
  ollama pull "$m"
done

PORT=${HOST_PORT:-11434}
echo ''
echo '=========================================================='
echo '  Ollama is ready. Installed models (all servable):'
echo "  http://localhost:$PORT/api/tags"
echo ''
echo '  Models loaded in memory (empty until first request):'
echo "  http://localhost:$PORT/api/ps"
echo ''
echo "  Default context: ${OLLAMA_CONTEXT_LENGTH:-unset (Ollama picks from VRAM)}"
echo "  KV cache: ${OLLAMA_KV_CACHE_TYPE:-f16}, flash attention: ${OLLAMA_FLASH_ATTENTION:-0}"
echo "  Resident models: ${OLLAMA_MAX_LOADED_MODELS:-1}, parallel slots: ${OLLAMA_NUM_PARALLEL:-1}"
echo ''
echo '  After the first request, check that PROCESSOR reads 100% GPU:'
echo '    docker compose exec ollama ollama ps'
echo '=========================================================='
echo ''

wait
