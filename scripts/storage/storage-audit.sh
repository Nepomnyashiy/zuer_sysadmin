#!/usr/bin/env bash
set -euo pipefail

mode="${1:---quick}"
if [[ "$mode" != "--quick" && "$mode" != "--deep" ]]; then
  printf 'Usage: %s [--quick|--deep]\n' "$0" >&2
  exit 2
fi

printf 'OSNOVA storage audit: %s\n' "$(date --iso-8601=seconds)"
printf '\nFilesystem capacity\n'
df -hT / /mnt/ufiles
df -ih / /mnt/ufiles
printf '\nMount identity\n'
findmnt -T /mnt/ufiles -o SOURCE,TARGET,FSTYPE,OPTIONS,UUID
printf '\nBlock devices\n'
lsblk -d -o NAME,PATH,SIZE,ROTA,TYPE,TRAN,MODEL
printf '\nDocker accounting\n'
docker info --format 'DockerRootDir={{.DockerRootDir}} Driver={{.Driver}} DriverStatus={{json .DriverStatus}} LoggingDriver={{.LoggingDriver}}'
docker system df
printf 'dangling_images=%s\n' "$(docker image ls -q --filter dangling=true | sort -u | wc -l)"
printf '\nDocker mounts and log policies\n'
while IFS= read -r container_id; do
  docker inspect --format '{{.Name}}|log={{.HostConfig.LogConfig.Type}}:{{json .HostConfig.LogConfig.Config}}|mounts={{range .Mounts}}{{.Type}}:{{.Source}}->{{.Destination}};{{end}}' "$container_id"
done < <(docker ps -aq)
printf '\nKubernetes storage\n'
kubectl get nodes -o wide
kubectl get storageclass,pv,pvc -A -o wide

if [[ "$mode" == "--deep" ]]; then
  printf '\nHome directory usage (largest entries)\n'
  du -x -B1 -d3 /home/nsadmin 2>/dev/null | sort -n | tail -120
  printf '\nufiles usage (largest readable entries)\n'
  du -x -B1 -d2 /mnt/ufiles 2>/dev/null | sort -n | tail -100
fi
