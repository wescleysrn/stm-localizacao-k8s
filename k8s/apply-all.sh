#!/usr/bin/env bash
# =============================================================
# apply-all.sh — Aplica todos os manifests do stm-localizacao em ordem
#
# Uso:
#   ./apply-all.sh               # Aplica tudo (padrão: produção)
#   ./apply-all.sh --dry-run     # Simula sem aplicar
#   ./apply-all.sh --delete      # Remove todos os recursos
#
# Pré-requisitos:
#   - kubectl configurado com o contexto correto
#   - Namespace ms já existente (ou crie com 00-namespace.yaml)
# =============================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="ms"
DRY_RUN=""
ACTION="apply"

# ---------------------------------------------------------
# Parse de argumentos
# ---------------------------------------------------------
for arg in "$@"; do
  case $arg in
    --dry-run)
      DRY_RUN="--dry-run=client"
      echo "[INFO] Modo dry-run ativado — nenhuma alteração será aplicada."
      ;;
    --delete)
      ACTION="delete"
      echo "[WARN] Modo delete ativado — todos os recursos serão removidos!"
      ;;
  esac
done

# ---------------------------------------------------------
# Verifica kubectl e contexto
# ---------------------------------------------------------
echo "[INFO] Contexto kubectl atual: $(kubectl config current-context)"
echo "[INFO] Namespace alvo: ${NAMESPACE}"
echo ""

if [[ "${ACTION}" == "delete" ]]; then
  read -p "[WARN] Confirma remoção de todos os recursos? (yes/no): " confirm
  if [[ "${confirm}" != "yes" ]]; then
    echo "[INFO] Operação cancelada."
    exit 0
  fi
fi

# ---------------------------------------------------------
# Lista de manifests em ordem de aplicação
# ---------------------------------------------------------
MANIFESTS=(
  "00-namespace.yaml"
  "09-registry-secret.yaml"   # Registry antes do Deployment
  "08-rbac.yaml"
  "01-configmap.yaml"
  "02-secret.yaml"
  "03-deployment.yaml"
  "04-service.yaml"
  "05-ingress.yaml"
  "06-hpa.yaml"
  "07-pdb.yaml"
  "10-networkpolicy.yaml"
)

# ---------------------------------------------------------
# Aplica ou remove cada manifest
# ---------------------------------------------------------
for manifest in "${MANIFESTS[@]}"; do
  filepath="${SCRIPT_DIR}/${manifest}"
  if [[ -f "${filepath}" ]]; then
    echo "[${ACTION^^}] ${manifest}"
    kubectl ${ACTION} -f "${filepath}" ${DRY_RUN}
  else
    echo "[WARN] Arquivo não encontrado: ${filepath}"
  fi
done

echo ""
echo "[INFO] Concluído com sucesso!"

# ---------------------------------------------------------
# Aguarda o Deployment ficar pronto (apenas no apply)
# ---------------------------------------------------------
if [[ "${ACTION}" == "apply" && -z "${DRY_RUN}" ]]; then
  echo ""
  echo "[INFO] Aguardando rollout do Deployment stm-localizacao..."
  kubectl rollout status deployment/stm-localizacao -n "${NAMESPACE}" --timeout=300s
  echo ""
  echo "[INFO] Pods em execução:"
  kubectl get pods -n "${NAMESPACE}" -l app=stm-localizacao
fi
