version="20220806.3"
# Kubernetes calls  --------------------------------------------------------------------------------------------------------------
create_user:
	bash ./create_certificate.sh "phiroict"
create_readonly_role_sa:
	k apply -f set-role-for-serviceaccount.yaml
create_sa_token_dashboard_admin:
	k apply -f sa_token_generation.yaml

## Deployment 
deploy_dev:
	cd stack/kustomize && kubectl apply -k overlays/dev
deploy_test:
	cd stack/kustomize && kubectl apply -k overlays/test
deploy_uat:
	cd stack/kustomize && kubectl apply -k overlays/uat
deploy_prod:
	cd stack/kustomize && kubectl apply -k overlays/prod

undeploy_dev:
	cd stack/kustomize && kubectl delete -k overlays/dev

# App builders -------------------------------------------------------------------------------------------------------------------
## Initialize (run only once in a while)
app_init:
	rustup override set nightly
	cargo install cargo-release
	rustup component add clippy
	rustup component add rustfmt
## Dev build
app_build_gateway:
	cd apps/gateway && cargo build 
app_build_datasource:
	cd apps/datasource && cargo build 
app_build_all: app_build_gateway app_build_datasource
app_run_all:
	cd apps/gateway && nohup cargo run&
	cd apps/datasource && nohup cargo run&

## Release build
app_build_gateway_release:
	cd apps/gateway && cargo build --release
app_build_datasource_release:
	cd apps/datasource && cargo build --release
app_build_all_release: app_build_gateway_release app_build_datasource_release

## Container build
app_container_gateway:
	docker build --build-arg path=apps --build-arg app_name=gateway -t phiroict/training_k8s_rust_gateway:$(version) -f infra/docker/Dockerfile  .
	docker push phiroict/training_k8s_rust_gateway:$(version)
app_container_datasource:
	docker build --build-arg path=apps --build-arg app_name=datasource -t phiroict/training_k8s_rust_datasource:$(version) -f infra/docker/Dockerfile  .
	docker push phiroict/training_k8s_rust_datasource:$(version)
app_container_build_all: app_container_gateway app_container_datasource
docker_compose_run:
	cd infra/docker && docker-compose up -d
docker_compose_stop:
	cd infra/docker && docker-compose down
## Minikube start commands with several drivers
minikube_podman:
	minikube config set rootless true
	minikube start --driver podman --container-runtime containerd  --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress
minikube_docker:
	minikube start --driver docker  --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress

minikube_virtualbox:
	minikube start --driver virtualbox --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress
minikube_kvm2:
	minikube start --driver kvm2 --nodes 4 --cpus 2 --memory 8000M
	minikube addons enable ingress