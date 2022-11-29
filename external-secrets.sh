#!/bin/bash  
echo "1: Check Parameters"
if [ $# -lt 3 ]; then
  echo 1>&2 "$0: not enough arguments"
  exit 2
elif [ $# -gt 3 ]; then
  echo 1>&2 "$0: too many arguments"
  exit 2
fi


echo "2: Set Parameters"
declare envParam=$1  #example: dev-canary
declare awsKeyParam=$2 #<external-secrets-k8s.aws-key>
declare awsSkeyParam=$3 #<external-secrets-k8s.aws-secret-key>


echo "3: Check for dependencies" 
helm version --short
kubectl version --short


echo "4: Install external-secrets operator using Helm chart
5: Create an external-secrets namespace"
helm install external-secrets external-secrets/external-secrets -n external-secrets --create-namespace
#kubectl get ns external-secrets


echo "6: Create an external-secrets directory"
mkdir external-secrets
cd external-secrets 


echo "7: Create an awssm-secret secret using external-secrets-k8s account"
echo -n $awsKeyParam > ./access-key
#cat access-key
#printf "\n"
echo -n $awsSkeyParam > ./secret-access-key
#cat secret-access-key
#printf "\n"
kubectl create secret generic awssm-secret --from-file=./access-key  --from-file=./secret-access-key
#kubectl get secret awssm-secret


echo "8: Create a cluster-secret-store.yaml file"
cat > cluster-secret-store.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ClusterSecretStore
metadata:
  name: global-secret-store
spec:
  provider:
    aws:
      service: SecretsManager
      region: us-east-1
      auth:
        secretRef:
          accessKeyIDSecretRef:
            name: awssm-secret
            key: access-key
            namespace: default
          secretAccessKeySecretRef:
            name: awssm-secret
            key: secret-access-key
            namespace: default
EOF
#cat cluster-secret-store.yaml


echo "9: Create an external-secrets.yaml file"
cat > external-secrets.yaml <<EOF
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: external-secrets
spec:
  refreshInterval: 1m
  secretStoreRef:
    name: global-secret-store
    kind: ClusterSecretStore
  target:
    name: external-secrets
    creationPolicy: Owner
  dataFrom:
  - find:
      tags:
        Name: "$envParam"
    rewrite:
    - regexp:
        source: "[^a-zA-Z0-9 -]"
        target: "_"
    - regexp:
        source: "${envParam}_(.*)"
        target: "\$1"
EOF
#cat external-secrets.yaml
#ls


echo "10: Apply files to cluster"
sleep 30
kubectl apply -f cluster-secret-store.yaml 
kubectl apply --namespace=ar -f external-secrets.yaml
kubectl apply --namespace=core -f external-secrets.yaml


echo "11: Check changes"
#kubectl describe externalsecrets external-secrets
#kubectl describe externalsecrets
kubectl get secret external-secrets -o jsonpath='{.data}' -n ar
kubectl get secret external-secrets -o jsonpath='{.data}' -n core

