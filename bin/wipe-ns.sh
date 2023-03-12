#!/bin/sh
. ./common.sh
ns=$1
echo
info "Deleting namespace \"${ns:?}\" and its finalizers"
kubectl delete ns "${ns:?}" & \
kubectl get ns "${ns:?}" -o json \
  | tr -d "\n" | sed "s/\"finalizers\": \[[^]]\+\]/\"finalizers\": []/" \
  | kubectl replace --raw /api/v1/namespaces/"${ns:?}"/finalize -f -
echo
info "Deleting cluster role bindings of namespace \"${ns:?}\""
delete_clusterrolebinding "${ns:?}"
echo
info "Deleting cluster roles of namespace \"${ns:?}\""
delete_clusterrole "${ns:?}"