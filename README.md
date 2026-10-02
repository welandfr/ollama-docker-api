# ollama-docker-api

### Set the port and model in local .env file; 
```sh
OLLAMA_PORT=8844
OLLAMA_MODEL=qwen3.5:9b 
```
### Start:
```sh
./up.sh
```
Starts the container detached, waits for the model pull, then prints the test URLs.
Plain `docker compose up -d` works too, but the URLs only appear in `docker compose logs ollama`.

### Remove the model data after changing models:
```sh
docker compose down
docker volume rm $(docker volume ls -q | grep ollama_api_data)
```

### Test:
```sh
curl http://localhost:8844/api/generate -d '{ "model": "qwen3.5:2b", "stream": false, "prompt": "Explain Docker in one paragraph." }' 
```
