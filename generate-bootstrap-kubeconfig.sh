#!/bin/bash


apply_bootstrap_sa() {
    bootstrap_sa=$(dirname $0)/examples/import/kind-cluster-bootstrap-sa.yaml
    kubectl apply -f $bootstrap_sa
    sleep 5
}

gen_insecure_hub_kubeconfig() {
    hub_cluster="kind-hub"
    cluster_ns="kind-cluster"
    token=$(kubectl get -n $cluster_ns secret/bootstrap-sa -o jsonpath='{.data.token}')

    export KUBECONFIG=bootstrap-hub.kubeconfig
    kind export kubeconfig --name=hub
    kubectl config set-credentials bootstrap-sa --token=$token
    kubectl config set-context --current --user=bootstrap-sa
    kubectl config set clusters.$hub_cluster.insecure-skip-tls-verify true
    kubectl config unset clusters.$hub_cluster.certificate-authority-data

    sed -iE 's/127\.0\.0\.1/docker.for.mac.localhost/g' bootstrap-hub.kubeconfig
}

apply_bootstrap_sa
gen_insecure_hub_kubeconfig


echo "

Now on the kind-cluster, run the following command:

kubectl create secret generic bootstrap-hub-kubeconfig -n open-cluster-management-agent --from-file=kubeconfig=bootstrap-hub.kubeconfig

"

