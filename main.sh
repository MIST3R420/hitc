#!/bin/bash
. ./helm-utils.sh


deploy_argocd() {
  ./helm-utils.sh \
    --ns argocd \
    --repo-name argo \
    --repo-url https://argoproj.github.io/argo-helm \
    --values-yaml infrastructure/argo-helm/charts/argo-cd/values.yaml \
    --chart-version 5.17.4 \
    --create-ns --add-repo --update-repo --search-repo --upgrade-install-repo
  info "ArgoCD initial admin secret"
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  info "Port forwarding at http://127.0.0.1:8069"
  kubectl port-forward svc/argocd-server -n argocd 8069:443
}
deploy_jenkins() {
  ./helm-utils.sh \
    -n jenkins \
    -r jenkins \
    -c jenkins/jenkins \
    -u https://charts.jenkins.io \
    -y infrastructure/jenkins-helm/charts/jenkins/values.yaml \
    -v 4.2.21 \
    -Z
  info "Jenkins initial admin secret"
  kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
  info "Port forwarding at http://127.0.0.1:8068"
  kubectl --namespace jenkins port-forward svc/jenkins 8068:8080
}

deploy_jenkins