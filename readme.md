# Goal 
 This is a project that is built while studying for the K8s certification. 
 It is a full stack project from application to deployment. 

 This will include 
 - Two applications in Rust using the Rocket webserver framework with a shared interface definition library and a template project.
 - Kustomize: For having one codebase for kubernetes and a set of variations per environment
 - Kubernetes: Several ways of using kubernetes in this project
   - Build it yourselves with another [project](https://github.com/phiroict/training_k8s_cluster)
   - Use minikube (See below)
 - Using a service mesh `istio` for zero trust inner service encryption.
 - Using encryption for ingoing connections (TLS / istio certs? )
 - Tests framework created in jmeter for content and saturation tests. 
 - CI: Jenkins container (todo)
 - CD: ArgoCD (todo)
  


# Stack
- Linux system (this has been developed on a Arch linux machine, should work fine on other distros as well) 
  - MacOS -> This is now the ARM platform so many container images need to be build for this platform, this is out of scope for this training. Good luck.
  - MacOS and Windows use VM when running docker containers so this solution may not work without faffing network settings, again, outside scope and again, Good luck.
  - For archlinux there is an ansible configuration playbook at `infra/ansible/dev-machine/playbook.yaml`, ran from the `make init_ansible` task.
- git
- kubectl
- kubernetes cluster 
- kustomize
- make (or CMake)
- istio (It will be overwritten during some of the make tasks, this is just for bootstrapping)
- rustup / rustc
- kvm2 / qemu (There are other virtualisation platforms you can use, check the `Minikube` section of the make file as how to create them - I have been using the kvm2 stack as it is opensource)
- jmeter

Optional:
- minikube
- wireshark



# Implementation setup

## Setup 
Flow of the setup is: 
- [if using archlinux] run `make init_archlinux` [install make first or run the commandline from the makefile directly]
- [other oses] install the stack above
- Then run the `make provision_minikube` 

## Short cuts 
For the examples add: 
```text
alias k=kubectl 
```
to your  `.profile` or `.bashrc` or equivalent.

## Local machine
[Arch linux] To use the opensource kvm2 version of minikube, follow the [instructions](`https://gist.github.com/grugnog/caa118205ad498423266f26150a5d555`) 

## Kubernetes

### Build cluster yourself
There is a project to set up a complete cluster : `https://github.com/phiroict/training_k8s_cluster` you can use to create a cluster yourself. There are many more ways to create a cluster, this is one of them.


### Use minikube. 
If you are less interested in the inner workings of kubernetes, you can use minikube, a cluster you can run locally on a machine with at least 36 GiB RAM. 
In the make file there are four ways to create these minikube stacks 

```makefile
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
```
These create the stack on several virtualization platforms. If you are an experience user with one of these, use these. There are more platforms available by the way, these
were the three I tested it on.
More info [here](https://minikube.sigs.k8s.io/docs/drivers/)  
More info about [minikube](https://minikube.sigs.k8s.io/docs/)  

# Design and use
This is a complete stack development. This chapter will move to some of the design choices.

## Main flow
In the whole stack these are the main components. Some of the details are omitted, we get to them later. 

![Main flow](docs/images/High_level_kubernetes_flow.png)

## Application flow
From the apps folder we have two applications that are the applications that will run on the pods.  
They are created from a template service project `service_template` setting up things like logging and
some configuration of the Rust / Rocket configuration.

The interface contract are captured in the Interface contract library: `application_interfaces` these
are used by both services.  
![Main flow ](docs/images/Rust_component_configuration.png)

## CI 

We use a tool concourse that runs in its own namespace. 

# Appendixes 
## Convenient commands 

### set namespace default 

```bash
k config set-context --current  --namespace dev-applications
```

# Kubernetes actions 
## Create users 

```bash
bash create_certificate.sh <NAME>
```

Create a role and associate it to the user 

```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: readonly-for-all
rules:
- apiGroups: ["*"]
  resources: ["*"]
  verbs: ["get", "list", "watch"]
- nonResourceURLs: ["*"]
  verbs: ["get", "list", "watch"]
---
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: readonly-for-test
subjects:
- kind: User
  name: <user>
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: readonly-for-all
  apiGroup: rbac.authorization.k8s.io
```

Now change to that user 

```bash
k config use-context <user>
```

Change back to the administrator
```bash
k config use-context kubernetes-admin@kubernetes
```

## Service accounts 

Create like this: 

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:  
  name: dev-deploy-principal
  namespace: dev-applications
---
apiVersion: v1
kind: Secret
metadata:
  name: sa-dev-deploy-token
  annotations:
    kubernetes.io/service-account.name: dev-deploy-principal
type: kubernetes.io/service-account-token  
```
Note that since k8s 1.24 the secret is no longer automatically generated, this is not well documented as of yet, so we generate the secret as is depicted.


## Environments 

We use `kustomize` to render the environments for the kubernetes setup. 
Note that it needs an external app installed, there is a integrated version in kubectl itself, but it is barely maintained. 

The scripts are in the `stack/kustomize` folder and you call them from that folder with:

[env is one of `{dev,test,uat,prod}`]

```bash
kustomize build overlays/<env>
```
Apply with

```bash
kubectl apply -k overlays/<env>
```
Remove with:
```bash
kubectl delete -k overlays/<env>
```

# Issues
## Issue context [solved]

There seems to be a bug in the set-credentials where it should be:

```yaml
- context:
    cluster: kubernetes
    user: phiroict
```

but it is 

```yaml
- context:
    cluster: ""
    user: ""
```
So the context change cannot find the cluster. 
Solved, missed the settings in the set-context should be this
```bash
kubectl config set-context ${TARGET_USER} --cluster=kubernetes --user=${TARGET_USER} --namespace=default
```