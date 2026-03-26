# ollama-docker-api

### Set the port and model in local .env file; 
```sh
OLLAMA_PORT=8844
OLLAMA_MODEL=qwen3.5:9b 
```
### Remove the model data after changing models:
```sh
docker compose down
docker volume rm $(docker volume ls -q | grep ollama_api_data)
```

### Test:
```sh
curl http://localhost:8844/api/generate -d '{ "model": "qwen3.5:2b", "stream": false, "prompt": "Explain Docker in one paragraph." }' 
```
