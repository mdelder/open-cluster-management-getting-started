#!/bin/bash

apply_bootstrap_sa() {
    cat $(dirname $0)/examples/import/kind-cluster-bootstrap.yaml | kubectl apply -f -
    sleep 5
}

gen_hub_kubeconfig() {
    kubectl get configmap cluster-info -n kube-public -o jsonpath='{.data.kubeconfig}' > bootstrap-hub.kubeconfig
    sed -i "s,name: \"\",name: hub," bootstrap-hub.kubeconfig
    kubectl config set-credentials bootstrap --token=hifklm.abcdefghijklmnop --kubeconfig=bootstrap-hub.kubeconfig
    kubectl config set-context bootstrap --user=bootstrap --cluster=hub --kubeconfig=bootstrap-hub.kubeconfig
    kubectl config use-context bootstrap --kubeconfig=bootstrap-hub.kubeconfig
}

apply_bootstrap_sa
gen_hub_kubeconfig


echo "

Now on the kind-cluster, run the following command:

kubectl create secret generic bootstrap-hub-kubeconfig -n open-cluster-management-agent --from-file=kubeconfig=bootstrap-hub.kubeconfig

"

