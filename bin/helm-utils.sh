#!/bin/bash
# fuck being posix compliant
info() {
  echo
  echo "[INFO: " "$@" "]">&2
}

while getopts ":n:r:c:u:y:v:Z" option; do
  case "${option}" in
    ### Set parameters
    # -n namespace e.g. argocd
    n)
      NAMESPACE="${OPTARG}";
      info "Namespace is ${NAMESPACE:?}";
      ;;
    # -r repo name e.g. argo
    r )
      REPO_NAME="${OPTARG}";
      info "Repo name is ${REPO_NAME:?}";
      ;;
    # -c chart path e.g. argo/argocd
    c )
      CHART_PATH="${OPTARG}";
      info "Chart path is ${CHART_PATH:?}";
      ;;
    # -u repo url e.g. https://argoproj.github.io/argo-helm
    u )
      REPO_URL="${OPTARG}";
      info "Repo url is ${REPO_URL:?}";
      ;;
    # -y values.yaml path e.g. infra/argo-helm/charts/argo-cd/values.yaml
    y )
      VALUES_YAML="${OPTARG}";
      info "Values yaml path is ${VALUES_YAML:?}";
      ;;
    # -v chart version e.g. "5.17.4" or "latest"
    v )
      CHART_VERSION="${OPTARG}";
      info "Chart version is ${CHART_VERSION:?}";
      ;;
    Z )
      info "Creating namespace ${NAMESPACE:?}";
      kubectl create ns "${NAMESPACE:?}";
      info "Adding Helm repo with name \"${REPO_NAME}\" and url \"${REPO_URL}\"";
      helm repo add "${REPO_NAME}" "${REPO_URL}" --force-update;
      info "Updating repo";
      helm repo update;
      info "Search helm chart repo results";
      helm search repo "${CHART_PATH}";
      info "Installing from helm chart";
      helm upgrade --install "${NAMESPACE:?}" "${CHART_PATH}"\
        -f "${VALUES_YAML:?}" \
        --version "${CHART_VERSION:?}" \
        --namespace "${NAMESPACE:?}" \
        --create-namespace \
        --wait --timeout 10m --debug;
      ;;
    * )
      echo "Unexpected option: $1 - this should not happen."
      break ;;
  esac
done
