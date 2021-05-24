#!/bin/bash


apply_bootstrap_sa() {
    hub_cluster="${1:-kind-hub}"
    cluster_ns="${2:-kind-cluster}"

    printf "\n\tApplying configuration for \"bootstrap-sa\" ServiceAccount on \"$hub_cluster\" in namespace \"$cluster_ns\".\n\n"

    bootstrap_sa=$(dirname $0)/examples/import/kind-cluster-bootstrap-sa.yaml
    kubectl apply -f $bootstrap_sa
    sleep 5
}

gen_insecure_hub_kubeconfig() {
    hub_cluster="${1:-kind-hub}"
    cluster_ns="${2:-kind-cluster}"

    printf "\n\tConfiguring bootstrap KUBECONFIG for \"$hub_cluster\" for managed cluster \"$cluster_ns\".\n\n"

    token=$(kubectl get -n $cluster_ns secret/bootstrap-sa -o go-template='{{.data.token|base64decode}}')
    sa_user="system:serviceaccount:kind-cluster:bootstrap-sa"

    export KUBECONFIG=bootstrap-hub.kubeconfig
    kind export kubeconfig --name=hub
    kubectl config set-credentials $sa_user --token=$token
    kubectl config set-context --current --user="$sa_user"
    kubectl config set clusters.$hub_cluster.insecure-skip-tls-verify true
    kubectl config unset clusters.$hub_cluster.certificate-authority-data
    kubectl config unset users.$hub_cluster

    # E0524 16:56:54.331005       1 reflector.go:127] k8s.io/client-go@v0.19.5/tools/cache/reflector.go:156:
    # Failed to watch *v1beta1.CertificateSigningRequest: failed to list *v1beta1.CertificateSigningRequest:
    # Get "https://docker.for.mac.localhost:55268/apis/certificates.k8s.io/v1beta1/certificatesigningrequests?limit=500&resourceVersion=0":
    # x509: certificate is valid for hub-control-plane, kubernetes, kubernetes.default, kubernetes.default.svc,
    # kubernetes.default.svc.cluster.local, localhost, not docker.for.mac.localhost

    sed -i 's/127\.0\.0\.1/docker.for.mac.localhost/g' bootstrap-hub.kubeconfig
}

if [[ "$2" != "" && "$2" != "kind-cluster" ]]; then
    printf "\n\t WARNING: \"examples/import/kind-cluster-bootstrap-sa.yaml\" currently assumes the imported cluster is named \"kind-cluster\"."
fi

apply_bootstrap_sa $1 $2
gen_insecure_hub_kubeconfig $1 $2

printf "\n\tNow on the kind-cluster, run the following command:"
printf "\n\n\tkubectl create secret generic bootstrap-hub-kubeconfig -n open-cluster-management-agent --from-file=kubeconfig=bootstrap-hub.kubeconfig\n"
