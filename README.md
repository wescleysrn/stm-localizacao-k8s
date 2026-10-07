# deploy/ — Infraestrutura Kubernetes do stm-localizacao

Este diretório contém todos os manifestos e charts para publicar o `stm-localizacao`
em um cluster Kubernetes. Ele é **ignorado** pelo Docker (`.dockerignore`) e
pelo Maven (`maven.config` / `.gitignore de artefatos`).

---

## Estrutura

```
deploy/
├── k8s/                        # Manifestos Kubernetes puros (kubectl)
│   ├── 00-namespace.yaml       # Namespace "ms" compartilhado entre microsserviços
│   ├── 01-configmap.yaml       # Variáveis de ambiente não-sensíveis
│   ├── 02-secret.yaml          # Senhas e tokens (não commitar valores reais)
│   ├── 03-deployment.yaml      # Deployment com probes, resources, affinity
│   ├── 04-service.yaml         # Service ClusterIP
│   ├── 05-ingress.yaml         # Ingress com TLS
│   ├── 06-hpa.yaml             # HorizontalPodAutoscaler
│   ├── 07-pdb.yaml             # PodDisruptionBudget
│   ├── 08-rbac.yaml            # ServiceAccount, Role, RoleBinding
│   ├── 09-registry-secret.yaml # Credenciais do Nexus (imagePullSecret)
│   ├── 10-networkpolicy.yaml   # Isolamento de rede entre pods
│   └── apply-all.sh            # Script para aplicar tudo em ordem
│
└── chart/                      # Helm Chart (uso futuro)
    ├── Chart.yaml              # Metadados do chart
    ├── values.yaml             # Valores padrão (sobrescreva em prod)
    ├── charts/                 # Dependências (vazio por ora)
    └── templates/              # Templates Helm (a migrar dos k8s/ futuramente)
```

---

Criar namespace:

```
kubectl apply -f 00-namespace.yaml
```

## Pré-requisitos

- `kubectl` configurado com o contexto correto
- Cluster RKE2 rodando
- Namespace `ms` criado
- Secret do registry Nexus gerado (veja abaixo)

---

## Uso rápido — kubectl

### 1. Gerar e aplicar o secret do registry Nexus

```bash
kubectl create secret docker-registry nexus-registry-secret \
  --docker-server=nexus.stm.jus.br \
  --docker-username=gitlab-runner \
  --docker-password=<PASSWORD> \
  --namespace=microservicos 
  --dry-run=client -o yaml > 09-registry-secret.yaml
```

Aplicar:

```
kubectl apply -f 09-registry-secret.yaml
```

### 2. Ajustar as senhas no Secret

Edite `deploy/k8s/02-secret.yaml` com os valores base64 reais:

```bash
echo -n "O45Wf3o-K%Bslja0j[EP" | base64
```

Aplicar:

```
kubectl apply -f 02-secret.yaml
```

### 3. Configmap

Aplicar:

```
kubectl apply -f 01-configmap.yaml
```

### 4. Deployment

Aplicar:

```
kubectl apply -f 03-deployment.yaml
```

```
@172.16.0.%
IP : 172.16.0.101   PORTA: 3308

Usuário			    senha
user_comunicacao	HWV[hY/R+CNMo,5S2(fd
user_localizacao	2a3dhFaj2T+@QM}wgOyw
user_ouvidoria		(EJK&MK!g}VeJTJQ{WGN
```

```
@10.3.3.%

IP : 172.16.0.101   PORTA: 3308

Usuário			    senha
user_comunicacao	cL(!_c+wPGPw@Ffc4WGu
user_localizacao	O45Wf3o-K%Bslja0j[EP
user_ouvidoria		Or)4uJE[an4uhb_mKVHO
```

### 5. Service

### 6. Ingress

Criar tls

```
kubectl create secret tls stm-microservicos-tls \
  --cert=/opt/stm-portal/internal.stm.jus.br.crt \
  --key=/opt/stm-portal/internal_private_key.pem \
  -n microservicos
```

### 3. Aplicar tudo

```bash
cd deploy/k8s
chmod +x apply-all.sh
./apply-all.sh
```

### Dry-run (simular sem aplicar)

```bash
./apply-all.sh --dry-run
```

### Remover todos os recursos

```bash
./apply-all.sh --delete
```

---

## Microsserviços futuros

O namespace `ms` é compartilhado. Para adicionar um novo microsserviço:

1. Crie `deploy/k8s/` no repositório do novo serviço
2. Reutilize o `00-namespace.yaml` — o namespace já existirá
3. Siga a mesma numeração de arquivos para consistência

Serviços planejados:
- `stm-localizacao` — comunicação por e-mail
- `stm-render` — renderizador de documentos
- `stm-localizacao` — serviço de localização
- `stm-sei-integration` — integração com o SEI

---

## Helm (uso futuro)

Após validar os manifestos `k8s/`, migre para o chart:

```bash
# Instalar
helm install stm-localizacao deploy/chart/ \
  --namespace ms \
  --set secret.keycloakAdminPassword="$(echo -n 'senha' | base64)" \
  --set secret.keycloakConnectionsPassword="$(echo -n 'senha-db' | base64)"

# Atualizar
helm upgrade stm-localizacao deploy/chart/ --namespace ms

# Remover
helm uninstall stm-localizacao --namespace ms
```

---

## Segurança — O que NÃO commitar

- `deploy/k8s/02-secret.yaml` com valores reais
- `deploy/k8s/09-registry-secret.yaml` com credenciais reais
- Qualquer arquivo `values-prod.yaml` com senhas

Use variáveis de ambiente no CI/CD (GitLab CI, etc.) para injetar os valores sensíveis em tempo de deploy.
