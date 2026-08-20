SHELL := /bin/bash

KUSTOMIZE ?= kustomize
KUBECTL ?= kubectl
K8S_OVERLAY ?= k8s/overlays/local
APP ?=
IMAGE_TAG ?= $(shell date +%Y%m%d)-local
REGISTRY ?= 127.0.0.1:30500
BACKUP_CTL ?= /usr/local/sbin/osnova-backupctl

.PHONY: help
help:
	@printf '%s\n' 'OSNOVA Kubernetes platform commands'
	@printf '%s\n' ''
	@printf '%s\n' 'Preflight:'
	@printf '%s\n' '  make k8s-preflight'
	@printf '%s\n' ''
	@printf '%s\n' 'Install/check:'
	@printf '%s\n' '  make k8s-install-check'
	@printf '%s\n' '  make k8s-install'
	@printf '%s\n' '  make k8s-install-ingress'
	@printf '%s\n' ''
	@printf '%s\n' 'Manifests:'
	@printf '%s\n' '  make k8s-build-local'
	@printf '%s\n' '  make k8s-dry-run-local'
	@printf '%s\n' '  make k8s-diff-local'
	@printf '%s\n' '  make k8s-apply-local'
	@printf '%s\n' ''
	@printf '%s\n' 'Apps:'
	@printf '%s\n' '  make app-build APP=barber'
	@printf '%s\n' '  make app-push APP=barber'
	@printf '%s\n' '  make app-dry-run APP=barber'
	@printf '%s\n' '  make app-diff APP=barber'
	@printf '%s\n' '  make app-apply APP=barber'
	@printf '%s\n' ''
	@printf '%s\n' 'Backup:'
	@printf '%s\n' '  make backup-preflight'
	@printf '%s\n' '  make backup-static-check'
	@printf '%s\n' '  make backup-ansible-check'
	@printf '%s\n' '  make backup-ansible-apply'
	@printf '%s\n' '  make backup-init'
	@printf '%s\n' '  make backup-run'
	@printf '%s\n' '  make backup-status'
	@printf '%s\n' '  make backup-snapshots'
	@printf '%s\n' '  make backup-retention-dry-run'
	@printf '%s\n' '  make backup-check'
	@printf '%s\n' '  make backup-check-data'
	@printf '%s\n' '  make backup-prune'
	@printf '%s\n' '  make backup-restore-smoke'

.PHONY: k8s-preflight
k8s-preflight:
	./scripts/k8s/preflight.sh

.PHONY: k8s-install-check
k8s-install-check:
	./scripts/k8s/install-k3s.sh --check

.PHONY: k8s-install
k8s-install:
	./scripts/k8s/install-k3s.sh

.PHONY: k8s-status
k8s-status:
	$(KUBECTL) get nodes -o wide
	$(KUBECTL) get pods,svc,ingress,pvc -A

.PHONY: k8s-install-ingress
k8s-install-ingress:
	./scripts/k8s/install-ingress-nginx.sh

.PHONY: k8s-build-local
k8s-build-local:
	$(KUSTOMIZE) build k8s/overlays/local

.PHONY: k8s-dry-run-local
k8s-dry-run-local:
	$(KUSTOMIZE) build k8s/overlays/local | $(KUBECTL) apply --dry-run=server -f -

.PHONY: k8s-diff-local
k8s-diff-local:
	$(KUBECTL) diff -k k8s/overlays/local

.PHONY: k8s-apply-local
k8s-apply-local:
	$(KUBECTL) apply -k k8s/overlays/local

.PHONY: app-build
app-build:
	@test -n "$(APP)" || (echo 'APP is required, example: make app-build APP=barber' >&2; exit 2)
	./scripts/k8s/build-app-images.sh "$(APP)" "$(REGISTRY)" "$(IMAGE_TAG)" --build-only

.PHONY: app-push
app-push:
	@test -n "$(APP)" || (echo 'APP is required, example: make app-push APP=barber' >&2; exit 2)
	./scripts/k8s/build-app-images.sh "$(APP)" "$(REGISTRY)" "$(IMAGE_TAG)"

.PHONY: app-dry-run
app-dry-run:
	@test -n "$(APP)" || (echo 'APP is required, example: make app-dry-run APP=barber' >&2; exit 2)
	$(KUBECTL) apply --dry-run=server -k "apps/$(APP)/k8s"

.PHONY: app-diff
app-diff:
	@test -n "$(APP)" || (echo 'APP is required, example: make app-diff APP=barber' >&2; exit 2)
	$(KUBECTL) diff -k "apps/$(APP)/k8s"

.PHONY: app-apply
app-apply:
	@test -n "$(APP)" || (echo 'APP is required, example: make app-apply APP=barber' >&2; exit 2)
	$(KUBECTL) apply -k "apps/$(APP)/k8s"

.PHONY: backup-postgres
backup-postgres:
	@test -n "$(NS)" || (echo 'NS is required, example: make backup-postgres NS=kolos APP=kolos-postgres DB=strapi USER=strapi' >&2; exit 2)
	@test -n "$(APP)" || (echo 'APP is required, example: make backup-postgres NS=kolos APP=kolos-postgres DB=strapi USER=strapi' >&2; exit 2)
	@test -n "$(DB)" || (echo 'DB is required' >&2; exit 2)
	@test -n "$(USER)" || (echo 'USER is required' >&2; exit 2)
	./scripts/backup/postgres-dump.sh "$(NS)" "$(APP)" "$(DB)" "$(USER)"

.PHONY: backup-preflight
backup-preflight:
	sudo $(BACKUP_CTL) preflight

.PHONY: backup-static-check
backup-static-check:
	./scripts/backup/check-backup-code.sh

.PHONY: backup-ansible-check
backup-ansible-check:
	sudo ansible-playbook -i ansible/inventory.ini ansible/backup.yml --check --diff

.PHONY: backup-ansible-apply
backup-ansible-apply:
	sudo ansible-playbook -i ansible/inventory.ini ansible/backup.yml

.PHONY: backup-init
backup-init:
	sudo $(BACKUP_CTL) init

.PHONY: backup-run
backup-run:
	sudo systemctl start osnova-backup.service

.PHONY: backup-status
backup-status:
	sudo $(BACKUP_CTL) status

.PHONY: backup-snapshots
backup-snapshots:
	sudo $(BACKUP_CTL) snapshots

.PHONY: backup-retention-dry-run
backup-retention-dry-run:
	sudo $(BACKUP_CTL) retention-dry-run

.PHONY: backup-check
backup-check:
	sudo $(BACKUP_CTL) check

.PHONY: backup-check-data
backup-check-data:
	sudo $(BACKUP_CTL) check-data

.PHONY: backup-prune
backup-prune:
	sudo $(BACKUP_CTL) prune

.PHONY: backup-restore-smoke
backup-restore-smoke:
	sudo $(BACKUP_CTL) restore-smoke
