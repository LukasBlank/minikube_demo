#!/bin/bash
# CREATE MINIKUBE CLUSTERS
minikube start -p cluster-argo --memory='3000' --driver=hyperv &
minikube start -p cluster-satelite-1 --memory='3000' --driver=hyperv &
minikube start -p cluster-satelite-2 --memory='3000' --driver=hyperv &
wait

# # INSTALL ARGO
kubectl config use-context cluster-argo
helm repo add argo https://argoproj.github.io/argo-helm
helm install argocd argo/argo-cd

# ARGO JOIN CLUSTER 1
CLUSTERNAME_S1="cluster-satelite-1"
CLUSTERNAMEB64_S1=$(echo -n "$CLUSTERNAME_S1" | base64)
export CLUSTERNAME_S1
export CLUSTERNAMEB64_S1
CLUSTERNAME_S2="cluster-satelite-2"
CLUSTERNAMEB64_S2=$(echo -n "$CLUSTERNAME_S2" | base64)
export CLUSTERNAME_S2
export CLUSTERNAMEB64_S2

envsubst >"./argo_join/manifests/satelite_cluster_argo_join.yaml" <"./argo_join/templates/satelite_cluster_argo_join_template.yaml"
kubectl config use-context "$CLUSTERNAME_S1"
kubectl apply -f ./argo_join/manifests/satelite_cluster_argo_join.yaml
IP_S1=$(minikube ip -p $CLUSTERNAME_S1)
ENDPOINT_S1=https://${IP_S1}:8443
ENDPOINTB64_S1=$(echo -n "$ENDPOINT_S1" | base64)
export ENDPOINT_S1
export ENDPOINTB64_S1
TOKEN_S1=$(kubectl get secret argocd-manager -n kube-system -o json | jq -r '.data.token | @base64d')
CACRT_S1=$(kubectl get secret argocd-manager -n kube-system -o json | jq -r '.data."ca.crt"')
CONFIGB64_S1=$(echo -n '{"bearerToken":"'"${TOKEN_S1}"'","tlsClientConfig":{"caData":"'"${CACRT_S1}"'","insecure":false}}' | base64 | tr -d '\n')
export CONFIGB64_S1

kubectl config use-context "$CLUSTERNAME_S2"
kubectl apply -f ./argo_join/manifests/satelite_cluster_argo_join.yaml
IP_S2=$(minikube ip -p $CLUSTERNAME_S2)
ENDPOINT_S2=https://${IP_S2}:8443
ENDPOINTB64_S2=$(echo -n "$ENDPOINT_S2" | base64)
export ENDPOINT_S2
export ENDPOINTB64_S2
TOKEN_S2=$(kubectl get secret argocd-manager -n kube-system -o json | jq -r '.data.token | @base64d')
CACRT_S2=$(kubectl get secret argocd-manager -n kube-system -o json | jq -r '.data."ca.crt"')
CONFIGB64_S2=$(echo -n '{"bearerToken":"'"${TOKEN_S2}"'","tlsClientConfig":{"caData":"'"${CACRT_S2}"'","insecure":false}}' | base64 | tr -d '\n')
export CONFIGB64_S2
envsubst >"./argo_join/manifests/argo_cluster_config.yaml" <"./argo_join/templates/argo_cluster_config_template.yaml"
envsubst >"./argo_join/manifests/argo_main_application_controller.yaml" <"./argo_join/templates/argo_main_application_controller_template.yaml"
kubectl config use-context cluster-argo
kubectl apply -f ./argo_join/manifests/argo_cluster_config.yaml

# EXPOSE ARGO
until [[ $(kubectl get deployment argocd-server -o json | jq -r '.status.availableReplicas') != "null" ]]; do
    echo "Waiting for the deployment to be ready..."
    sleep 5
done
cmd.exe /c "start cmd.exe /k kubectl port-forward service/argocd-server 8080:443"

# # CHANGE USER PWD ON FIRST LOGIN
ARGO_PWD=$(kubectl get secret argocd-initial-admin-secret -o json | jq -r '.data.password | @base64d')
argocd login localhost:8080 --insecure --username admin --password "$ARGO_PWD"
argocd account update-password --current-password "$ARGO_PWD" --new-password local-password

# DEPLOY MAIN APPLICATION CONTROLLER
kubectl apply -f ./argo_join/manifests/argo_main_application_controller.yaml
