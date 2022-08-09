version="20220809.2"
istio_version="1.13.7"
# Archlinux setup
init_archlinux:
	sudo pacman -S istio kubectl make rustup minikube docker jmeter-qt socat wireshark-qt --needed
	yay -S docker-machine-driver-kvm2 libvirt qemu-headless ebtables --needed
	sudo systemctl enable libvirtd.service
	sudo systemctl start libvirtd.service
	sudo usermod -a -G libvirt $(whoami)
	minikube config set driver kvm2
# Kubernetes calls  --------------------------------------------------------------------------------------------------------------
create_user:
	bash ./create_certificate.sh "phiroict"
create_readonly_role_sa:
	k apply -f set-role-for-serviceaccount.yaml
create_sa_token_dashboard_admin:
	k apply -f sa_token_generation.yaml

## Deployment -------------------------------------------------------------------------------------------------------------------- 
### Create namespaces first as we need to associate istio with it
init_namespaces:
	kubectl apply -f stack/namespace_init/namespaces.yaml
### Deployments	
deploy_dev:
	cd stack/kustomize && kubectl apply -k overlays/dev
deploy_test:
	cd stack/kustomize && kubectl apply -k overlays/test
deploy_uat:
	cd stack/kustomize && kubectl apply -k overlays/uat
deploy_prod:
	cd stack/kustomize && kubectl apply -k overlays/prod
### Undeployments
undeploy_dev:
	cd stack/kustomize && kubectl delete -k overlays/dev
undeploy_test:
	cd stack/kustomize && kubectl delete -k overlays/dev
undeploy_uat:
	cd stack/kustomize && kubectl delete -k overlays/dev
undeploy_prod:
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

# Minikube ----------------------------------------------------------------------------------------------------------------------------------------------------------
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
minikube_delete:
	minikube delete

# Service mesh ----------------------------------------------------------------------------------------------------------------------------------------------------------
istio_init:
	istioctl install --set profile=demo -y
istio_inject:
	kubectl label namespace dev-applications istio-injection=enabled --overwrite
	kubectl label namespace test-applications istio-injection=enabled --overwrite
	kubectl label namespace uat-applications istio-injection=enabled --overwrite
	kubectl label namespace prod-applications istio-injection=enabled --overwrite
istio_extras:
	wget https://storage.googleapis.com/istio-release/releases/$(istio_version)/istio-$(istio_version)-linux-amd64.tar.gz 
	tar xfv istio-$(istio_version)-linux-amd64.tar.gz
	kubectl apply -f istio-$(istio_version)/samples/addons/

# Main runners  ----------------------------------------------------------------------------------------------------------------------------------------------------------
provision_minikube: minikube_kvm2 istio_init init_namespaces istio_inject istio_extras deploy_dev

bounce_minikube: minikube_delete provision_minikube

# Dashboards
minikube_dashboard:
	nohup minikube dashboard&
kiali_dashboard:
	nohup istioctl dashboard kiali&