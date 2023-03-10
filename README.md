# virtualservice

## Before starting

```
kind --version
kind version 0.17.0

helm version
version.BuildInfo{Version:"v3.11.1", GitCommit:"293b50c65d4d56187cd4e2f390f0ada46b4c4737", GitTreeState:"clean", GoVersion:"go1.18.10"}
```

## Procedure

```
kind create cluster --name lab

helm repo add istio https://istio-release.storage.googleapis.com/charts

helm repo update

kubectl create ns istio-system

helm install istio-base istio/base -n istio-system

helm install istiod istio/istiod -n istio-system

helm list -A
NAME      	NAMESPACE   	REVISION	UPDATED                                	STATUS  	CHART        	APP VERSION
istio-base	istio-system	1       	2023-03-09 23:02:32.425221898 -0300 -03	deployed	base-1.17.1  	1.17.1     
istiod    	istio-system	1       	2023-03-09 23:02:58.355109845 -0300 -03	deployed	istiod-1.17.1	1.17.1     

go install github.com/itchyny/gojq/cmd/gojq@latest

gojq -v
gojq 0.12.12 (rev: HEAD/go1.20.2)

./run.sh

kind delete cluster --name lab
```
