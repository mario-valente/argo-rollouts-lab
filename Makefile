.PHONY: help cluster cluster-minimal delete-cluster install install-argo install-monitoring cleanup deploy-canary deploy-bluegreen traffic status promote abort undo watch port-forward dashboard

# Default target
help:
	@echo "Argo Rollouts Lab - Comandos Disponíveis"
	@echo ""
	@echo "Cluster:"
	@echo "  make cluster              Criar cluster Kind (3 nodes)"
	@echo "  make cluster-minimal      Criar cluster Kind (1 node)"
	@echo "  make delete-cluster       Deletar cluster Kind"
	@echo ""
	@echo "Instalação:"
	@echo "  make install              Instalação completa (Argo Rollouts + Prometheus + Grafana)"
	@echo "  make install-argo         Instalar apenas Argo Rollouts"
	@echo "  make install-monitoring   Instalar apenas Prometheus/Grafana"
	@echo "  make cleanup              Remover tudo"
	@echo ""
	@echo "Deploy:"
	@echo "  make deploy-canary        Deploy canary v2"
	@echo "  make deploy-canary-bad    Deploy canary v3-bad (vai falhar)"
	@echo "  make deploy-bluegreen     Deploy blue-green v2"
	@echo ""
	@echo "Operações:"
	@echo "  make status               Ver status do rollout canary"
	@echo "  make watch                Assistir progresso do rollout"
	@echo "  make promote              Promover rollout"
	@echo "  make abort                Abortar rollout"
	@echo "  make undo                 Rollback"
	@echo ""
	@echo "Utilitários:"
	@echo "  make traffic              Gerar tráfego (10 RPS)"
	@echo "  make port-forward         Abrir port-forwards"
	@echo "  make dashboard            Abrir Argo Rollouts dashboard"
	@echo ""
	@echo "Exemplos:"
	@echo "  make cluster && make install && make deploy-canary && make traffic"

# Cluster management
cluster:
	@kind create cluster --name argo-rollouts-lab --config cluster/kind-config.yaml
	@kubectl cluster-info

cluster-minimal:
	@kind create cluster --name argo-lab --config cluster/kind-config-minimal.yaml
	@kubectl cluster-info

delete-cluster:
	@kind delete cluster --name argo-rollouts-lab 2>/dev/null || true
	@kind delete cluster --name argo-lab 2>/dev/null || true

# Installation
install:
	@./scripts/setup.sh

install-argo:
	@./scripts/setup.sh --argo-only

install-monitoring:
	@./scripts/setup.sh --monitoring-only

cleanup:
	@./scripts/setup.sh --cleanup

# Deploy
deploy-canary:
	@./scripts/deploy.sh canary v2

deploy-canary-bad:
	@./scripts/deploy.sh canary v3-bad

deploy-bluegreen:
	@./scripts/deploy.sh bluegreen v2

deploy-bluegreen-manual:
	@./scripts/deploy.sh bluegreen-manual v2

# Rollout operations
status:
	@./scripts/rollout-actions.sh status canary

status-bg:
	@./scripts/rollout-actions.sh status bluegreen

watch:
	@./scripts/rollout-actions.sh watch canary

watch-bg:
	@./scripts/rollout-actions.sh watch bluegreen

promote:
	@./scripts/rollout-actions.sh promote canary

promote-bg:
	@./scripts/rollout-actions.sh promote bluegreen

promote-bg-manual:
	@./scripts/rollout-actions.sh promote bluegreen-manual

abort:
	@./scripts/rollout-actions.sh abort canary

undo:
	@./scripts/rollout-actions.sh undo canary

pause:
	@./scripts/rollout-actions.sh pause canary

resume:
	@./scripts/rollout-actions.sh resume canary

# Utilities
traffic:
	@./scripts/traffic-generator.sh -r 10 -d 300

traffic-heavy:
	@./scripts/traffic-generator.sh -r 50 -d 600

port-forward:
	@./scripts/port-forward.sh

dashboard:
	@kubectl argo rollouts dashboard -n argo-rollouts

# Quick tests
test-success:
	@echo "Testing successful deployment..."
	@./scripts/deploy.sh canary v2
	@./scripts/traffic-generator.sh -r 20 -d 180 &
	@./scripts/rollout-actions.sh watch canary

test-failure:
	@echo "Testing failed deployment (should auto-rollback)..."
	@./scripts/deploy.sh canary v3-bad
	@./scripts/traffic-generator.sh -r 20 -d 180 &
	@./scripts/rollout-actions.sh watch canary
