# Black Mamba Kubernetes migration

## Что это

Стартовый Kubernetes-манифест для AI-платформы:

- pgvector/PostgreSQL;
- Black Mamba API;
- Hermes gateway;
- LiteLLM;
- Open WebUI;
- Open WebUI AI;
- Ollama placeholder.

## Перед deploy

```bash
make k8s-preflight
./scripts/k8s/create-secret-from-env.sh ai-platform black-mamba-secret /run/media/nsadmin/godny_soft/soft/black_mamba/local_llm/.env
make app-build APP=black-mamba
make app-push APP=black-mamba
make app-dry-run APP=black-mamba
make app-diff APP=black-mamba
```

## Важно

`ollama` по умолчанию имеет `replicas: 0`. Включать его можно только после:

```bash
nvidia-smi
kubectl get nodes -o wide
kubectl get pods -n kube-system
```

и установки NVIDIA runtime/device plugin для Kubernetes.

