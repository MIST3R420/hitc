#!/bin/sh

# minikube start --nodes 3 -p minikube-3-node

info() {
  echo "[INFO: " "$@" "]">&2
}

#show_unused_configmaps() {
#  volumesCM=$( kubectl get pods -o  jsonpath='{.items[*].spec.volumes[*].configMap.name}' | xargs -n1)
#  volumesProjectedCM=$( kubectl get pods -o  jsonpath='{.items[*].spec.volumes[*].projected.sources[*].configMap.name}' | xargs -n1)
#  envCM=$( kubectl get pods -o  jsonpath='{.items[*].spec.containers[*].env[*].ValueFrom.configMapKeyRef.name}' | xargs -n1)
#  envFromCM=$( kubectl get pods -o  jsonpath='{.items[*].spec.containers[*].envFrom[*].configMapKeyRef.name}' | xargs -n1)
#
#  diff \
#  <(echo "$volumesCM\n$volumesProjectedCM\n$envCM\n$envFromCM" | sort | uniq) \
#  <(kubectl get configmaps -o jsonpath='{.items[*].metadata.name}' | xargs -n1 | sort | uniq)
#}

delete_clusterrolebinding() {
  ns=$1
  kubectl get clusterrolebinding | \
      grep -o "^${ns:?}[-a-z^+ ]*" | \
    while read -r line; \
  do
    echo
    info "Deleting cluster role binding \"${line:?}\""
    kubectl delete clusterrolebinding "${line:?}";
  done
}

delete_clusterrole() {
  ns=$1
  kubectl get clusterrole | \
      grep -o "^${ns:?}[-a-z^+ ]*" | \
    while read -r line; \
  do
    echo
    info "Deleting cluster role \"${line:?}\""
    kubectl delete clusterrole "${line:?}";
  done
}

wipe_namespace() {
  ns=$1
  helm ls -n kafka -a
  for i in $(seq 2) ; do
    echo
    info "Iteration ${i} of 2"
    echo
    info "Deleting namespace \"${ns:?}\" and its finalizers"
    kubectl delete ns "${ns:?}" & \
    sleep 2s & \
    kubectl get ns "${ns:?}" -o json \
      | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
      | kubectl replace --raw /api/v1/namespaces/"${ns:?}"/finalize -f -
  done
}

wipe_crb_cr() {
  ns=$1
  echo
  info "Deleting cluster role bindings of namespace \"${ns:?}\""
  delete_clusterrolebinding "${ns:?}"
  echo
  info "Deleting cluster roles of namespace \"${ns:?}\""
  delete_clusterrole "${ns:?}"
}

# yeah... use for last resort XD
wipe_pvc_pv() {
  ns=$1
  kubectl get pvc -n "${ns:?}"
  kubectl get pvc -n "${ns:?}" | grep -o "data[^ ]*" | while read -r pvc;
    do
      kubectl patch pvc "${pvc}" -p '{"metadata":{"finalizers":null}}'
      kubectl delete pvc "${pvc}" --grace-period=0 --force;
    done
  kubectl get pv -n "${ns:?}"
  kubectl get pv -n "${ns:?}" | grep -o "pvc[^ ]*" | while read -r pv;
    do
      kubectl patch pv "${pv}" -p '{"metadata":{"finalizers":null}}'
      kubectl delete pv "${pv}" --grace-period=0 --force
    done
  # kubectl delete pvc  -n kafka  --grace-period=0 --force
}

stop_namespace() {
  ns=$1
  kubectl --namespace "${ns:?}" scale deployment \
    --replicas 0 \
    $(kubectl --namespace "${ns:?}" get deployment | awk '{print $1}')
  kubectl --namespace "${ns:?}" scale statefulset \
    --replicas 0 \
    $(kubectl --namespace default get statefulset  | awk '{print $1}')
}

delete_cert_manager() {
  kubectl get Issuers,ClusterIssuers,Certificates,CertificateRequests,Orders,Challenges --all-namespaces
  helm --namespace cert-manager delete cert-manager
}

start_cluster_3_node() {
  clustername="minikube-3-node"
  minikube start --nodes 3 -p $clustername
}

deploy_argocd() {
  ns="argocd"
  info "Adding repo"
  helm repo add argo https://argoproj.github.io/argo-helm --force-update
  echo
  info "Updating repo"
  helm repo update
  echo
  info "Repo search result"
  helm search repo argo/argo-cd
  echo
  info "Creating namespace \"${ns:?}\""
  kubectl create ns "${ns:?}"
  echo
  info "Installing from helm chart"
  helm upgrade --install "${ns:?}" argo/argo-cd \
    -f infrastructure/argo-helm/charts/argo-cd/values.yaml \
    --version 5.17.4 \
    --namespace "${ns:?}" \
    --create-namespace \
    --wait --timeout 10m --debug
  echo
  info "ArgoCD initial admin secret"
  kubectl -n "${ns:?}" get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d; echo
  echo
  info "Port forwarding in background"
  kubectl port-forward svc/argocd-server -n "${ns:?}" 8069:443 &
}

deploy_argocd_kustomize() {
  namespace="argocd"
  kubectl create ns $namespace
  kubectl apply -k infrastructure/argoproj-deployments/argocd
}

deploy_jenkins() {
  kubectl create ns "jenkins"
  helm repo add jenkins https://charts.jenkins.io --force-update
  helm repo update
  helm search repo jenkins/jenkins
  helm upgrade --install jenkins jenkins/jenkins \
    -f infrastructure/jenkins-helm/charts/jenkins/values.yaml \
    --namespace jenkins \
    --create-namespace \
    --wait --timeout 10m --debug
  kubectl exec --namespace jenkins -it svc/jenkins -c jenkins -- /bin/cat /run/secrets/additional/chart-admin-password && echo
  echo http://127.0.0.1:8068
  kubectl --namespace jenkins port-forward svc/jenkins 8068:8080
}

deploy_grafana() {
  ns="grafana"
  helm repo add grafana https://grafana.github.io/helm-charts --force-update
  helm repo update
  helm search repo grafana/grafana
  helm upgrade --install "${ns:?}" grafana/grafana \
    -f infrastructure/grafana/values.yaml \
    --version "6.50.0" \
    --namespace "${ns:?}" \
    --create-namespace --cleanup-on-fail --atomic \
    --wait --timeout 10m --debug || exit
  echo
  info "Grafana initial admin secret"
  kubectl get secret --namespace grafana grafana -o jsonpath="{.data.admin-password}" | base64 --decode ; echo
  echo
  POD_NAME=$(kubectl get pods --namespace grafana -l "app.kubernetes.io/name=grafana,app.kubernetes.io/instance=grafana" -o jsonpath="{.items[0].metadata.name}")
  info "Port forwarding pod \"${POD_NAME}\" in background"
  kubectl --namespace grafana port-forward "${POD_NAME}" 3000
}

deploy_strimzi() {
  helm repo add strimzi https://strimzi.io/charts/ --force-update
  helm repo update
  helm search repo strimzi
  kubectl create ns strimzi
  helm upgrade --install strimzi strimzi/strimzi-kafka-operator \
    -f infrastructure/strimzi-kafka-operator/values.yaml \
    --namespace strimzi \
    --create-namespace --cleanup-on-fail --atomic \
    --wait --timeout 10m --debug || exit
  kubectl create ns kafka
  kubectl apply -f infrastructure/strimzi-kafka-operator/examples/kafka/kafka-persistent.yaml --namespace kafka
#  kubectl create ns kafka-connect
#  kubectl apply -f infrastructure/strimzi-kafka-operator/examples/connect/kafka-connect.yaml --namespace kafka-connect
}

deploy_mongodb() {
  helm repo add mongodb https://mongodb.github.io/helm-charts
  helm install mongodb-community-operator mongodb/community-operator
  helm upgrade --install mongodb-community-operator mongodb/community-operator \
    -f infrastructure/mongodb/values.yaml \
    --namespace mongodb \
    --create-namespace --cleanup-on-fail --atomic \
    --wait --timeout 10m --debug || exit
  kubectl apply -f infrastructure/mongodb/sample-deployment.yaml -n mongodb
  kubectl get secret vip-password -n mongodb \
    -o json | jq -r '.data | with_entries(.value |= @base64d)'

}

#
#deploy_mongodb() {
#  helm repo add bitnami https://charts.bitnami.com/bitnami
#  helm install mongodb bitnami/mongodb
#  helm upgrade --install mongodb bitnami/mongodb \
#    -f infrastructure/mongodb/values.yaml \
#    --namespace mongodb \
#    --create-namespace --cleanup-on-fail --atomic \
#    --wait --timeout 10m --debug || exit
#}

#start_cluster_3_node
#deploy_argocd_helm
#stop_namespace "argocd"
#deploy_jenkins
#wipe_namespace mongodb
#wipe_namespace "kafka"
#kubectl apply -f infrastructure/strimzi-kafka-operator/examples/kafka/kafka-persistent.yaml --namespace kafka
#wipe_namespace strimzi
#wipe_pvc_pv grafana
#deploy_grafana
deploy_mongodb
#deploy_strimzi
#deploy_zookeeper
