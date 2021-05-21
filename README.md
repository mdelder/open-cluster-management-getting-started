
# Overview

The open-cluster-management.io project is focused on how to simplify fleet management for Kubernetes and OpenShift. There are a few simple concepts to understand when getting started:

1. _Hub_ cluster (represented by the `ClusterManager` API): When managing a fleet, one cluster is designated as the _hub_ where other clusters connect to receive desired configuration and behavior.
2. _Managed cluster_ (represented by the `ManagedCluster` API): Any cluster that runs the agent (`Klusterlet`, described shortly) and connects to a _hub_.
3. `ManifestWork`: An API that describes desired configuration that should be applied to a _managed cluster_.
4. `PlacementRule`: An API that describes how workloads should be placed across the fleet.

# Getting started

Let's start with a simple example using 2 [KinD clusters](https://kind.sigs.k8s.io/). We'll have a cluster named `hub` and a second named `cluster`.

```bash
$ kind get clusters
cluster
hub
```

You can switch between `kubeconfig` settings for each cluster using:

```bash
# Use the kubeconfig for the managed cluster
kind export kubeconfig --name=cluster

# Use the kubeconfig for the hub cluster
kind export kubeconfig --name=hub
```

## Deploy the Cluster Manager

Let's deploy the [Cluster Manager](https://operatorhub.io/operator/cluster-manager) to the _hub_.

We need the Operator Lifecycle Manager (OLM) running on our cluster. If you're running OKD or OpenShift, you already have these pods running.
```bash
$ kind export kubeconfig --name=hub
$ curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.18.1/install.sh | bash -s v0.18.1
```

Next, deploy the `Cluster Manager` operator:

```bash
$ kubectl create -f https://operatorhub.io/install/cluster-manager.yaml
subscription.operators.coreos.com/my-cluster-manager created
```
Next, we deploy the `ClusterManager` operand in the `operator.open-cluster-management.io/v1` API group. The `ClusterManager` operand will start the pods that listen for _managed clusters_ to be imported and service API like `ManagedCluster`.

```bash
kubectl apply -f examples/cluster-manager.yaml
clustermanager.operator.open-cluster-management.io/cluster-manager created
```
_Example: Deploy the [cluster-manager.yaml](examples/cluster-manager.yaml)._

By creating the `ClusterManager` operand, you are telling the operator run the pods that service the CustomResourceDefinitions (CRDs) or API for dealing with concepts like cluster inventory, Role-Based Access Control (RBAC) and work distribution (assigning desired configuration to _managed clusters_ in the fleet).

Verify the running pods in the `open-cluster-management-hub` namespace:

```bash
$ kubectl get clustermanager
NAME              AGE
cluster-manager   5m19s

$ kubectl get pods -n open-cluster-management-hub
NAME                                                       READY   STATUS    RESTARTS   AGE
cluster-manager-registration-controller-6586874ccc-475mt   1/1     Running   1          4m25s
cluster-manager-registration-controller-6586874ccc-cg2qb   1/1     Running   2          4m25s
cluster-manager-registration-controller-6586874ccc-mq472   1/1     Running   1          4m25s
cluster-manager-registration-webhook-58c7d64d9f-295tx      1/1     Running   2          4m25s
cluster-manager-registration-webhook-58c7d64d9f-2lmx2      1/1     Running   1          4m25s
cluster-manager-registration-webhook-58c7d64d9f-m578d      1/1     Running   1          4m25s
cluster-manager-work-webhook-57c5db85f5-6jhgm              0/1     Pending   0          4m25s
cluster-manager-work-webhook-57c5db85f5-dwmcw              1/1     Running   1          4m25s
cluster-manager-work-webhook-57c5db85f5-mfnf4              0/1     Pending   0          4m25s
```

## Deploy the `Klusterlet` agent

Now let's *import* the _managed cluster_ to the _hub_ by deploying the [Klusterlet](https://operatorhub.io/operator/klusterlet) agent. The `Klusterlet` runs a set of pods that register and connect back to _hub_. The `Klusterlet` operator just runs the pods that service the `Klusterlet` operand, so the pods for registration and work reconcilation will not start until we actually define the `Klusterlet` operand.

We're now going to switch to the KinD cluster named `cluster` and configure the `Klusterlet` operator and supporting `Klusterlet` operand.

```bash

# Install the Operator Lifecycle Manager if not present
$ curl -sL https://github.com/operator-framework/operator-lifecycle-manager/releases/download/v0.18.1/install.sh | bash -s v0.18.1

# Configure the Klusterlet operator
$ kubectl create -f https://operatorhub.io/install/klusterlet.yaml
```

Once operator is ready, deploy the Klusterlet agent pods by configuring the `Klusterlet` operand:

```bash
$ kubectl apply -f examples/klusterlet.yaml
```

Now the `Klusterlet` operand will start the pods for `registration` and `work`. However, we can see that the `registration` pods will fail to successful start until we supply the required `bootstrap-hub-kubeconfig` that allows the `registration` pods to connect to the API server of the _hub_.

We are going to take an insecure approach to import the _managed cluster_ to the _hub_ because we cannot create `ServiceAccount` tokens in KinD clusters. So let's capture the `kind-hub` `$KUBECONFIG` and create a `Secret` with it on the _managed clusters_.

```bash
$ export KUBECONFIG=kind-hub.kubecfg
$ kind export kubeconfig --name=hub

./generate-bootstrap-kubeconfig.sh

$ kubectl create secret generic bootstrap-hub-kubeconfig \
    -n open-cluster-management-agent \
    --from-file=kubeconfig=bootstrap-hub.kubecfg
```

Approve the `CertificateSigningRequest` on the _hub_.

```bash
$ kubectl get csr
NAME                 AGE     SIGNERNAME                            REQUESTOR          CONDITION
kind-cluster-mgtdz   8m53s   kubernetes.io/kube-apiserver-client   kubernetes-admin   Pending

$ kubectl certificate approve kind-cluster-mgtdz
```

```bash
$ kubectl get pods -n open-cluster-management-agent
```

### In case you're curious
The only required permissions for `bootstrap-hub-kubeconfig` are to create a `CertificateSigningRequest`. Here is an [example `ServiceAccount` configuration](examples/import/kind-cluster-bootstrap-sa.yaml) that would allow this (if KinD supported `ServiceAccount` tokens).

```bash
# Using the KUBECONFIG of the hub
export CLUSTER_NAMESPACE=kind-cluster
kubectl apply -f examples/import/kind-cluster-bootstrap-sa.yaml
# sleep 5 or wait a moment for Kubernetes to reconcile the serviceaccount token in the secret.
export TOKEN=$(kubectl get -n $CLUSTER_NAMESPACE secret/bootstrap-sa -o jsonpath='{.data.token}')


# Make a copy of the KUBECONFIG to avoid modifying the original
cp $KUBECONFIG bootstrap-hub.kubeconfig
export KUBECONFIG=bootstrap-hub.kubeconfig
kubectl config set-credentials bootstrap-sa --token=$TOKEN
kubectl config set-context --current --user=bootstrap-sa

kubectl create secret generic bootstrap-hub-kubeconfig -n open-cluster-management-agent --from-file=kubeconfig=bootstrap-hub.kubeconfig
```



# References

1. [open-cluster-management.io](https://open-cluster-management.io) - the official project website.
2. [How to get started with Red Hat Advanced Cluster Management](https://www.openshift.com/blog/how-to-get-started-with-red-hat-advanced-cluster-management-for-kubernetes) - describes how to consume Open Cluster Management from Red Hat's supported offering of the project.
3. [Connecting managed clusters with Submariner in Red Hat Advanced Cluster Management for Kubernetes](https://www.openshift.com/blog/connecting-managed-clusters-with-submariner-in-red-hat-advanced-cluster-management-for-kubernetes)
4. [How to use the Certificate Policy Controller to Identify Risks in Red Hat Advanced Cluster Management for Kubernetes](https://www.openshift.com/blog/how-to-use-the-certificate-policy-controller-to-identify-risks-in-red-hat-advanced-cluster-management-for-kubernetes)
5. [K8s Integrity Shield (tech-preview): Protecting the Integrity of Kubernetes Resources with Signature](https://www.openshift.com/blog/k8s-integrity-shield-tech-preview-protecting-the-integrity-of-kubernetes-resources-with-signature)
6. [Integrating Gatekeeper with Red Hat Advanced Cluster Management for Kubernetes](https://www.openshift.com/blog/integrating-gatekeeper-with-red-hat-advanced-cluster-management-for-kubernetes)
7. [Contributing and deploying community policies with Red Hat Advanced Cluster Management and GitOps](https://www.openshift.com/blog/tag/red-hat-advanced-cluster-management)
8. [Address CVEs Using Red Hat Advanced Cluster Management Governance Policy Framework](https://www.openshift.com/blog/address-cves-using-red-hat-advanced-cluster-management-governance-policy-framework)