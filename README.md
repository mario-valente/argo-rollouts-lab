# Argo Rollouts Lab

Um laboratório completo para testar e aprender sobre **Argo Rollouts** com estratégias de deploy Canary, Blue-Green, Analysis com métricas Prometheus, e muito mais.

## 📋 Índice

- [Pré-requisitos](#-pré-requisitos)
- [Quick Start](#-quick-start)
- [Estrutura do Projeto](#-estrutura-do-projeto)
- [Estratégias de Deploy](#-estratégias-de-deploy)
- [Analysis e Métricas](#-analysis-e-métricas)
- [Cenários de Teste](#-cenários-de-teste)
- [Scripts Utilitários](#-scripts-utilitários)
- [Dashboards](#-dashboards)

## 🛠 Pré-requisitos

- **Docker** (para Kind)
- **Kind** - `brew install kind`
- **kubectl** - `brew install kubectl`
- **Helm** v3.x - `brew install helm`

## 🚀 Quick Start

```bash
# 1. Criar cluster Kind
make cluster

# 2. Instalar Argo Rollouts + Prometheus + Grafana
make install

# 3. Deploy canary
make deploy-canary

# 4. Gerar tráfego e observar
make traffic
```

Ou passo a passo manual:

```bash
# Criar cluster
kind create cluster --name argo-rollouts-lab --config cluster/kind-config.yaml

# Instalar tudo via Helm
./scripts/setup.sh

# Abrir port-forwards
./scripts/port-forward.sh
```

## 📁 Estrutura do Projeto

```
argo-rollouts-lab/
├── cluster/                    # Configurações do Kind
│   ├── kind-config.yaml        # Cluster com 3 nodes
│   └── kind-config-minimal.yaml # Cluster single-node
│
├── infrastructure/             # Helm values e configs
│   ├── argo-rollouts-values.yaml
│   ├── prometheus-stack-values.yaml
│   ├── nginx-ingress-values.yaml
│   ├── prometheus/
│   │   └── servicemonitor.yaml
│   └── grafana/
│       └── dashboard-configmap.yaml
│
├── manifests/
│   ├── app/                    # Demo app (Go)
│   │   ├── Dockerfile
│   │   └── main.go
│   ├── rollouts/               # Rollout definitions
│   │   ├── canary-rollout.yaml
│   │   ├── canary-rollout-with-experiments.yaml
│   │   ├── bluegreen-rollout.yaml
│   │   └── bluegreen-rollout-manual.yaml
│   └── analysis/               # Analysis Templates
│       ├── success-rate-analysis.yaml
│       ├── error-rate-analysis.yaml
│       ├── latency-analysis.yaml
│       ├── bluegreen-analysis.yaml
│       ├── experiment-analysis.yaml
│       ├── web-analysis.yaml
│       └── cluster-analysis-templates.yaml
│
├── scripts/                    # Automação
│   ├── setup.sh                # Instalação via Helm
│   ├── deploy.sh               # Deploy com estratégia
│   ├── rollout-actions.sh      # Promote/abort/undo
│   ├── traffic-generator.sh    # Gerador de tráfego
│   └── port-forward.sh         # Port-forwards
│
├── Makefile                    # Comandos make
└── README.md
```

## 🎯 Estratégias de Deploy

### Canary Deployment

Envia gradualmente tráfego para a nova versão enquanto monitora métricas.

```bash
# Via Makefile
make deploy-canary

# Via script
./scripts/deploy.sh canary v2

# Manual
kubectl apply -f manifests/rollouts/canary-rollout.yaml
```

**Progressão:**
- 10% → pause 30s
- 20% → análise inicia + pause 60s
- 40% → pause 60s
- 60% → pause 60s
- 80% → pause 60s
- 100% → completo

### Blue-Green Deployment

Mantém duas versões e alterna tráfego instantaneamente.

```bash
# Auto-promote (após análise)
./scripts/deploy.sh bluegreen v2

# Manual promote
./scripts/deploy.sh bluegreen-manual v2
./scripts/rollout-actions.sh promote bluegreen-manual
```

## 📊 Analysis e Métricas

### Analysis Templates Disponíveis

| Template | Descrição | Uso |
|----------|-----------|-----|
| `success-rate-analysis` | Taxa de sucesso > 95% | Canary |
| `error-rate-analysis` | Taxa de erro < 5% | Canary |
| `latency-analysis` | P99 latência | Canary |
| `bluegreen-pre-analysis` | Smoke tests pre-promote | Blue-Green |
| `bluegreen-post-analysis` | Monitoramento pós-promote | Blue-Green |
| `experiment-comparison-analysis` | Compara canary vs baseline | Experiments |
| `web-analysis` | Health checks HTTP | Qualquer |
| `job-analysis` | Validação via Job | Qualquer |

### Métricas da Demo App

```promql
# Requests por versão
sum by (version) (rate(http_requests_total[1m]))

# Taxa de erro
http_error_rate{namespace="demo-app"}

# Total de erros
http_errors_total{version="v2"}
```

## 🧪 Cenários de Teste

### Deploy bem-sucedido

```bash
./scripts/deploy.sh canary v2
./scripts/traffic-generator.sh -r 20 -d 180
```

### Deploy com falha (auto-rollback)

```bash
# v3-bad tem 20% de erro rate - vai falhar na análise
./scripts/deploy.sh canary v3-bad
```

### Deploy lento

```bash
./scripts/deploy.sh canary v4-slow --latency 800
```

### Blue-Green manual

```bash
./scripts/deploy.sh bluegreen-manual v2

# Testar preview
curl http://localhost:8081/api/info

# Promover
./scripts/rollout-actions.sh promote bluegreen-manual
```

## 🔧 Scripts

### setup.sh

```bash
./scripts/setup.sh              # Instalação completa
./scripts/setup.sh --argo-only  # Só Argo Rollouts
./scripts/setup.sh --cleanup    # Limpar tudo
```

### deploy.sh

```bash
./scripts/deploy.sh canary v2
./scripts/deploy.sh bluegreen v2
./scripts/deploy.sh canary v2 --error-rate 0.05 --latency 100
```

### rollout-actions.sh

```bash
./scripts/rollout-actions.sh status canary
./scripts/rollout-actions.sh watch canary
./scripts/rollout-actions.sh promote canary
./scripts/rollout-actions.sh abort canary
./scripts/rollout-actions.sh undo canary
./scripts/rollout-actions.sh pause canary
./scripts/rollout-actions.sh resume canary
```

### traffic-generator.sh

```bash
./scripts/traffic-generator.sh              # 10 RPS / 5 min
./scripts/traffic-generator.sh -r 50 -d 600 # 50 RPS / 10 min
./scripts/traffic-generator.sh --canary     # Target canary service
```

## 📈 Dashboards

### Acessar interfaces

```bash
# Todos de uma vez
./scripts/port-forward.sh

# Argo Rollouts Dashboard
kubectl argo rollouts dashboard -n argo-rollouts
# http://localhost:3100

# Prometheus
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090 -n monitoring
# http://localhost:9090

# Grafana (admin/admin)
kubectl port-forward svc/prometheus-grafana 3000:80 -n monitoring
# http://localhost:3000
```

## 🔨 Makefile Commands

```bash
make help               # Mostrar ajuda

# Cluster
make cluster            # Criar cluster Kind (3 nodes)
make cluster-minimal    # Criar cluster Kind (1 node)
make delete-cluster     # Deletar cluster

# Instalação
make install            # Instalar tudo
make install-argo       # Só Argo Rollouts
make cleanup            # Remover tudo

# Deploy
make deploy-canary      # Canary v2
make deploy-canary-bad  # Canary v3 (vai falhar)
make deploy-bluegreen   # Blue-Green v2

# Operações
make status             # Status do rollout
make watch              # Watch rollout
make promote            # Promover
make abort              # Abortar
make undo               # Rollback

# Utilitários
make traffic            # Gerar tráfego
make port-forward       # Port-forwards
make dashboard          # Argo dashboard
```

## ❓ Troubleshooting

### Rollout travado

```bash
kubectl argo rollouts get rollout <name> -n demo-app
kubectl get analysisrun -n demo-app
kubectl describe analysisrun <name> -n demo-app
```

### Métricas não aparecem

```bash
# Verificar targets no Prometheus
# http://localhost:9090/targets

# Verificar ServiceMonitor
kubectl get servicemonitor -n demo-app
```

### Limpar e reiniciar

```bash
make cleanup
make delete-cluster
make cluster
make install
```

## 📚 Recursos

- [Argo Rollouts Docs](https://argoproj.github.io/argo-rollouts/)
- [Analysis & Progressive Delivery](https://argoproj.github.io/argo-rollouts/features/analysis/)
- [Traffic Management](https://argoproj.github.io/argo-rollouts/features/traffic-management/)
