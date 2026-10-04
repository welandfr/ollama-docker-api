# ollama-docker-api

Ollama in a container with an Nvidia GPU, serving every installed model from one
endpoint. Ollama loads a model into VRAM on the first request for it and unloads
it after `OLLAMA_KEEP_ALIVE` (default 5m idle), so what limits you is how many
models are installed — not how many are running.

Settings live in a local `.env`; `compose.yml` supplies defaults for everything
optional. Start with `./up.sh`.

## Set the port and models

```sh
OLLAMA_PORT=8844
OLLAMA_MODEL_LIST=ornith-1.5:9b,qwen3.5:9b
```

`OLLAMA_MODEL` (single model) still works, and is also what `test.http` and
`cors-test.html` use for their "which model" field.

## Context window — the setting that decides whether coding agents work

Ollama picks a default context length from available VRAM:

| VRAM | Ollama's default context |
| --- | --- |
| under 24 GiB | **4k** |
| 24–48 GiB | 32k |
| 48 GiB and above | 256k |

**4k is unusable for an agentic coding tool.** Claude Code's system prompt and
tool schemas alone run to roughly 15k tokens, so at 4k the tool definitions are
truncated away and the model cannot emit valid tool calls — it fails in a way
that looks like model incompetence rather than misconfiguration.

32k is not enough either, less obviously: it holds the prompt, so the agent
starts working, but the ~17k left over is refilled by one large file read. The
agent compacts, refills, compacts, and reports *"Autocompact is thrashing"*.

So this sets 64k, which matches Ollama's own guidance for coding tools:

```sh
OLLAMA_CONTEXT_LENGTH=65536
```

A client may override it per request — Ollama's native API takes
`options.num_ctx` — but the Anthropic-compatible endpoint has no equivalent, so
for Claude Code this value *is* the window.

### Making 64k fit on 16 GB

KV cache grows with the context window, and at 64k an f16 cache is around 8 GB,
which does not fit beside a 9B model's 6.5 GB of weights on a 16 GB card.
Quantizing the cache roughly halves it for a small quality loss:

```sh
OLLAMA_FLASH_ATTENTION=1
OLLAMA_KV_CACHE_TYPE=q8_0
```

Flash attention is required for the quantized cache. That brings a 9B model at
64k to about 10.5 GB, which fits with headroom.

Two related settings matter for the same budget. `OLLAMA_MAX_LOADED_MODELS`
defaults to **1** here, because two 9B models at 64k would need over 20 GB —
Ollama evicts the idle model when another is requested, so listing several
models is fine, requests just pay the load time. And `OLLAMA_NUM_PARALLEL`
defaults to 1 because each parallel slot gets its own KV cache, multiplying what
the context window costs.

### Verify it rather than trusting the arithmetic

```sh
docker compose exec ollama ollama ps
```

`PROCESSOR` must read `100% GPU` and `CONTEXT` should show the configured
window. Any CPU split means the window is too large for the card — the symptom
is severe slowness, not an error, so it is easy to misread as the model simply
being slow. Back down to 49152 or 32768 if so.

## Exposure

The API has **no authentication**. The default publishes the port on every
interface, which is fine on a trusted LAN and not fine otherwise. Confine it
with:

```sh
OLLAMA_BIND=10.66.0.2      # a WireGuard or LAN address
OLLAMA_BIND=127.0.0.1      # local only
```

`OLLAMA_ORIGINS=*` in `compose.yml` allows browser requests from any origin,
which is what `cors-test.html` exercises. For anything reachable beyond a
trusted network, put the Caddy front end in `Caddyfile.example` in front — it
adds API-key checking and its own CORS headers.

## Endpoints

Three APIs on the same port:

| Path | Shape |
| --- | --- |
| `/api/chat`, `/api/generate`, `/api/tags`, `/api/ps` | Ollama's own |
| `/v1/chat/completions` | OpenAI-compatible |
| `/v1/messages` | Anthropic-compatible — what Claude Code talks to |

For Claude Code, point it straight here; no proxy is needed:

```sh
ANTHROPIC_BASE_URL=http://localhost:8844 \
ANTHROPIC_AUTH_TOKEN=ollama \
ANTHROPIC_API_KEY="" \
CLAUDE_CODE_MAX_CONTEXT_TOKENS=65536 \
claude
```

`CLAUDE_CODE_MAX_CONTEXT_TOKENS` should match `OLLAMA_CONTEXT_LENGTH`. Without
it Claude Code assumes a 200k window for a model it does not recognise and
compacts at that, growing prompts past what Ollama accepts — which Ollama then
truncates silently.

The sibling `claude-ollama` project does the same job through a local proxy. It
is worth running instead of the direct connection when you want per-request
control of `num_ctx` without changing this server, or the per-request logging it
produces; the direct connection is simpler and keeps web search and web fetch,
which that proxy drops.

## Start

```sh
./up.sh
```

Starts the container detached, waits for all model pulls, then prints the test
URLs and the effective context, KV-cache and VRAM settings. Plain
`docker compose up -d` works too, but that output only appears in
`docker compose logs ollama`.

## Add a model to a running container

```sh
docker compose exec ollama ollama pull mistral:7b
```

Add it to `OLLAMA_MODEL_LIST` too, so it survives a volume wipe.

## Remove the model data after changing models

```sh
docker compose down
docker volume rm $(docker volume ls -q | grep ollama_api_data)
```

## Test

`test.http` covers all of this; by hand:

```sh
curl http://localhost:8844/api/tags     # installed, all servable
curl http://localhost:8844/api/ps       # loaded in VRAM, with CONTEXT

curl http://localhost:8844/api/generate -d '{
  "model": "ornith-1.5:9b", "stream": false, "prompt": "Explain Docker in one paragraph." }'

# the endpoint Claude Code uses
curl http://localhost:8844/v1/messages \
  -H 'content-type: application/json' -H 'anthropic-version: 2023-06-01' \
  -d '{ "model": "ornith-1.5:9b", "max_tokens": 64,
        "messages": [{ "role": "user", "content": "Hello." }] }'
```
