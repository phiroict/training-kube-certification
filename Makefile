version=20220810.1
istio_version=1.14.3
istio_version_arm=1.14.3
nginx_ingress_controller_version=1.3.0
concourse_version=7.8.2
# Archlinux setup
init_archlinux:
	sudo pacman -S istio kubectl make rustup minikube docker jmeter-qt socat wireshark-qt --needed
	yay -S docker-machine-driver-kvm2 libvirt qemu-headless ebtables --needed
	sudo systemctl enable libvirtd.service
	sudo systemctl start libvirtd.service
	sudo usermod -a -G libvirt $(whoami)
	minikube config set driver kvm2
init_ansible:
	sudo pacman -S ansible --needed
	ansible-playbook --ask-become-pass -c local infra/ansible/dev-machine/playbook.yaml
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
	minikube start --driver kvm2 --nodes 2 --cpus 2 --memory 10000M
	minikube addons enable ingress
minikube_delete:
	minikube delete

minikube_set_hosts:
	cd infra/ansible/hosts && ansible-playbook -c local --ask-become-pass --extra-vars "ip_address=$(shell minikube ip)" playbook.yaml
# Service mesh ----------------------------------------------------------------------------------------------------------------------------------------------------------
istio_init:
	istioctl install --set profile=demo -y
istio_init_arm:
	istioctl install --set profile=demo -y --set components.cni.enabled=true
istio_inject:
	kubectl label namespace dev-applications istio-injection=enabled --overwrite
	kubectl label namespace test-applications istio-injection=enabled --overwrite
	kubectl label namespace uat-applications istio-injection=enabled --overwrite
	kubectl label namespace prod-applications istio-injection=enabled --overwrite
istio_extras:
	rm -rf istio-$(istio_version)
	wget https://storage.googleapis.com/istio-release/releases/$(istio_version)/istio-$(istio_version)-linux-amd64.tar.gz
	tar xfv istio-$(istio_version)-linux-amd64.tar.gz
	kubectl apply -f istio-$(istio_version)/samples/addons/
	rm -f istio-$(istio_version)-linux-amd64.tar.gz
	sudo cp -pf istio-$(istio_version)/bin/istioctl  /usr/bin/istioctl
	# kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v$(nginx_ingress_controller_version)/deploy/static/provider/cloud/deploy.yaml
istio_extras_arm:
	wget https://github.com/istio/istio/releases/download/$(istio_version_arm)/istio-$(istio_version_arm)-osx-arm64.tar.gz
	tar xfv istio-$(istio_version_arm)-osx-arm64.tar.gz
	kubectl apply -f istio-$(istio_version_arm)/samples/addons/
	rm -f istio-$(istio_version_arm)-osx-arm64.tar.gz
istio_kiali_dashboard:
	nohup istioctl dashboard kiali &

# Dashboards
minikube_dashboard:
	nohup minikube dashboard&
kiali_dashboard:
	nohup istioctl dashboard kiali&

# CI
concourse_init:
	rm -f concourse-*-linux-amd64.tgz*
	wget https://github.com/concourse/concourse/releases/download/v$(concourse_version)/concourse-$(concourse_version)-linux-amd64.tgz
	tar -xzvf concourse-$(concourse_version)-linux-amd64.tgz
	kubectl apply -f ci/concourse/infra/concourse-namespace.yaml
	mkdir -p ci/concourse/secrets
	sudo cp -p concourse/bin/concourse /usr/bin/concourse
	cd concourse/fly-assets && tar -xzvf fly-linux-amd64.tgz
	sudo cp -p concourse/fly-assets/fly /usr/bin/fly
concourse_keygen:
	cd concourse/bin && ./concourse generate-key -t rsa -f ../../ci/concourse/secrets/session_signing_key
	cd concourse/bin && ./concourse generate-key -t ssh -f ../../ci/concourse/secrets/tsa_host_key
	cd concourse/bin && ./concourse generate-key -t ssh -f ../../ci/concourse/secrets/worker_key
	-kubectl delete secret -n ci session-signing
	-kubectl delete secret -n ci tsa-host-private
	-kubectl delete secret -n ci tsa-host-public
	-kubectl delete secret -n ci worker-private
	-kubectl delete secret -n ci worker-public
	kubectl create secret generic session-signing -n ci --from-file=ci/concourse/secrets/session_signing_key
	kubectl create secret generic tsa-host-private -n ci  --from-file=ci/concourse/secrets/tsa_host_key
	kubectl create secret generic tsa-host-public -n ci  --from-file=ci/concourse/secrets/tsa_host_key.pub
	kubectl create secret generic worker-private -n ci  --from-file=ci/concourse/secrets/worker_key
	kubectl create secret generic worker-public  -n ci  --from-file=ci/concourse/secrets/worker_key.pub
	rm -f ci/concourse/secrets/*
concourse_create:
	cd ci/concourse/infra && kubectl apply -k .
concourse_delete:
	cd ci/concourse/infra && kubectl delete -k .
concourse_all: concourse_init concourse_keygen concourse_create
concourse_web:
	nohup firefox http://concourse.info:32080 &
# Main runners  ----------------------------------------------------------------------------------------------------------------------------------------------------------
provision_minikube: minikube_kvm2 istio_init init_namespaces istio_inject istio_extras deploy_dev concourse_all minikube_set_hosts minikube_dashboard concourse_web istio_kiali_dashboard
provision_mac_arm_minikube: istio_init_arm init_namespaces istio_inject istio_extras_arm deploy_dev minikube_set_hosts minikube_dashboard concourse_web istio_kiali_dashboard

bounce_minikube: minikube_delete provision_minikube
