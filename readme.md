

# Goal 
 This is a project that is built while studying for the K8s certification, and slowly turned into a full stack development
 that can be deployed on cloud and local clusters.  
 It is a full stack project from application to deployment, its aim is to be able to be provisioned 95%+ automated.

Most of the documentation can be read in the [wiki](https://github.com/phiroict/training-kube-certification/wiki)
Check out the wiki [by](git@github.com:phiroict/training-kube-certification.wiki.git) 
This readme will contain developer setup notes and observations, all other documentation is in the [wiki](https://github.com/phiroict/training-kube-certification/wiki). 





# Stack
- A Linux system (this has been developed on an Arch linux machine, should work fine on other distros as well) 
  - MacOS -> This is now the ARM platform so many container images need to be build for this platform, this is out of scope for this training. Good luck.
  - MacOS and Windows use VM when running docker containers so this solution may not work without faffing network settings, again, outside scope and again, Good luck.
  - For archlinux there is an ansible configuration playbook at `infra/ansible/dev-machine/playbook.yaml`, ran from the `make init_ansible` task.
- git
- kubectl
- kubernetes cluster 
- kustomize
- make (or CMake)
- istio (It will be overwritten during some make tasks, this is just for bootstrapping)
- rustup / rustc
- kvm2 / qemu (There are other virtualisation platforms you can use, check the `Minikube` section of the make file as how to create them - I have been using the kvm2 stack as it is opensource)
- jmeter
- ansible
- bash
- make 

Optional:
- minikube
- wireshark
- k9s (Commandline k8s maintenance) 
- azure-cli
- aws-cli
- aws-vault
- gcloud  


# Implementation setup

## TL;DR; express setup
Run the following make steps:

### Initial 
Run the make tasks, or the commands therein: 

- `init_archlinux` (Or equivalent for your OS)
- `concourse_init`
- Manual: Set the secrets in `ci/concourse/secrets` [see](### Set_passwords)
  - git.creds
  - docker.creds 
- `provision_minikube`

We are also implementing cloud deployments (Azure AKS, AWS EKS, and Google GKS) initially we will set up 
azure AKS as we need to sort ingress and access. This would be slightly different for the cloud providers as these can 
use load balancers to export traffic. There are several ways of access the cloud applications -> By port forwarding, (not for production) or istio gateways.   

We keep you posted as we go along. 



## Setup password files 
See concourse [passwords](###Set_passwords)

## Setup 
Flow of the setup is: 
- [if using archlinux] run `make init_archlinux` [install make first or run the commandline from the makefile directly]
- [other oses] install the stack above
- Then run the `make provision_minikube` 

## Shortcuts 
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
In the make file there are four ways to create these minikube stacks.
If you do not that much memory you can change the settings, by for instance using fewer nodes and memory. Note that tools like istio need a lot of resources so if you 
notice that pods are failing with OOMErrors you need to increase memory per node. It is better to have fewer nodes than memory. 
On linux, the kvm2 minikube is recommended.  

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

### Azure AKS 
Need: 
- azure cli (az) 
- azure admin account for at least one subscription 
 
Stack will be created with 
- az_login
- az_cdk_init
- az_cdk_get
- az_cdk_deploy
- az_cdk_get_credentials
- az_cdk_destroy

Full provision with make task: 
- az_provision

For this the infra is changed a bit to use ingresses and the services will be changed to type of load balancer. 
```
TODO 20220817: 
v concourse worker issue [added more vCPUs]
v concourse web expose [forwarding it]
  v istio dashboards exposure. [Port forwarding] 
```
Initial run: 

```bash
az login
# Once at the start if nothing has been set up.
make az_cdk_init
# On each change on the infra
make az_cdk_get 
```
This will provision the infra on the cloud, now create the stack by running: 
```bash
make provision_cloud_aks
```
Now there are a few automation steps that need to be made when using the cloud. 
- The cluster creates a public IP address we need to use for exposing. 
```text
20.232.236.3 gateway.example.com
127.0.0.1 concourse.info
```
TODO is to create a step grabbing the public ip and passing it to the hosts file. 
```text
TODO : 20220818
- gateway app exposure through istio gateway (Service repo seems not to resolve) 
- create a step grabbing the public ip and passing it to the hosts file. 
- Fix build fail when the there are no changes in the system. 
- Full automated process. (testing one instance now) 

```


### AWS EKS
Needs: 
- aws-vault
- aws commandline 
- aws admin account 
- cdktf installed 
- eksctl 
- 
The stack will be created with the aws_* make tasks:
- aws_init : Initializes the node libraries (run once)
- aws_bootstrap : Installs the s3 bucket for the state. (run once, change the name of the bucket :) )
- aws_get : gets the cdktf libraries
- aws_build : builds the cluster
- aws_destroy : Cleans it up.  

Full provision with make task:
- aws_provision

You need to set the aws as the home target. Otherwise you need to replace home with whatever name you choose. 

```bash
aws-vault add home
```

You can inject the session settings in a command with 

```bash
aws-vault exec home -- <command> 
```
You can make it an alias for brevity: 

```bash
alias a="aws-vault exec home --no-session -- "
```

Note the `--no-session` is needed for certain IAM creation actions as Federated users (the user with temporary credentials) are not allowed to do. 

__Workaround__
At the moment there is an issue with the generated terraform script. So we have a work around in place until the issue can be
fixed. 

__patch__

`Cdktf.tf.json`

line 83: Remove the brackets as it is a list not a string.

```json
"subnet_ids": "${module.vpc.private_subnets}",
```
Not
```json
"subnet_ids": ["${module.vpc.private_subnets}"],
```


`Eks-managed-node-group/main.tf`

Line : 40
Replace line with this

```hcl
launch_template_name_int = coalesce("long-value", var.launch_template_name, "${var.name}-eks-node-group")
```

Run the stack from the `training-kube-certification/stack/cloud/aws/cdktf.out/stacks/aws_instance` folder as the synth will overwrite and introduce the error again.

Run there:
```bash
terraform init -upgrade
terraform plan -out plan.plan
terraform apply plan.plan
```

There are also some work around tasks in the make file, these run from the `cdk.tf.json` script you ought to have patched before 

| make task      | desc                                   |
|----------------|----------------------------------------|
| aws_wa_init    | runs the init / upgrade terraform task | 
| aws_wa_plan    | plans the terraform script             | 
| aws_wa_apply   | applies the terraform script           | 
| aws_wa_destroy | destroy the terraform script           | 


It is not ideal but for now we do this this way until can fix the incorrect type setting.
These are set in the aws_wa (Work Around) tasks I have added temporary.

Now, if you want to use the portal to review the cluster, your user has no access to these so you need to run
You need to install `eksctl` for this. 

```bash
aws-vault exec home --no-session --  eksctl create iamidentitymapping --cluster  training-eks-phiro-test --region=ap-southeast-2 --arn arn:aws:iam::774492638540:role/$(aws-vault exec home --no-session -- aws iam list-roles | jq -r '.Roles[].RoleName' | grep "0-eks*") --group system:masters --username phiro
```
Relogin and you should have access to the portal on aws. 

You can now run the kubenetes tasks, note that you need to be logged in onto aws so you need to set the 
environment correctly. Alternatively you can run each command with `aws-vault exec home --no-session -- ` prepended. 

### Google GKS 

## Makefile 

To document commands and keep them in sync with use we use a Makefile as the main local pipeline and task runner.
The tasks defined in there are: 

| Make task                       | description                                                                                                                                      |
|---------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| init_archlinux                  | For a linux machine these are the preamble settings and applications.                                                                            |
| init_ansible                    | Does the same as the first but now using ansible                                                                                                 |
| create_user                     | Example of creation of a user with creation of the SSL certs needed --reference only                                                             |
| create_readonly_role_sa         | Example of creation of a service account -reference only                                                                                         |
| create_sa_token_dashboard_admin | Example of a token generation for a sa account (kubectl>1.21 no longer does this automatically)                                                  |
| init_namespaces                 | Creates the namespaces we use, as we add other components on the namespace we do not want to delete / create it with the rest of the infra stack |
| deploy_dev                      | Deploy the infra & applications on the dev environment, uses kustomize.                                                                          |
| deploy_test                     | Deploy the infra & applications on the test environment, uses kustomize.                                                                         |
| deploy_uat                      | Deploy the infra & applications on the uat environment, uses kustomize.                                                                          |
| deploy_prod                     | Deploy the infra & applications on the prod environment, uses kustomize.                                                                         |
| undeploy_dev                    | Remove infra for dev (save namespace)                                                                                                            |
| undeploy_test                   | Remove infra for test (save namespace)                                                                                                           |
| undeploy_uat                    | Remove infra for uat (save namespace)                                                                                                            |
| undeploy_prod                   | Remove infra for prod (save namespace)                                                                                                           |
| app_init                        | Setup rust for nightly build use (Rocket, the service framework needs that)                                                                      |
| app_build_gateway               | Build the gateway microservice application                                                                                                       |
| app_build_datasource            | Build the datasource microservice application                                                                                                    |
| app_build_all                   | Build all the microservices                                                                                                                      |
| app_run_all                     | Run the microservices locally on the machine.                                                                                                    |
| app_build_gateway_release       | Build the Rust release version                                                                                                                   |
| app_build_datasource_release    | Builds the Rust release version                                                                                                                  |
| app_build_all_release           | Build all release versions                                                                                                                       |
| app_container_gateway           | Create the docker image for the gateway microservice                                                                                             |
| app_container_datasource        | Create the docker image for the datasource microservice                                                                                          |
| app_container_build_all         | Build all containers for the microservices                                                                                                       |
| docker_compose_run              | Run the images in a docker compose stack locally                                                                                                 |
| docker_compose_stop             | Stop and delete local docker compose stack                                                                                                       |
| minikube_podman                 | Create k8s cluster using podman (Does not need a docker engine running, only needs containerd)                                                   |
| minikube_docker                 | Create k8s cluster using docker (Needs running docker engine)                                                                                    |
| minikube_virtualbox             | Create k8s cluster on virtualbox. VB needs to be installed, but you would not need containerization on you local machine                         |
| minikube_kvm2                   | Create k8s cluster on kvm / qemu (recommended way on linux)                                                                                      |
| minikube_delete                 | Delete and erase minikube from your system                                                                                                       |
| minikube_set_hosts              | Get the minikube gateway ip address and places it in the /etc/hosts file                                                                         |
| istio_init                      | Install istio in the cluster using defaults                                                                                                      |
| istio_init_arm                  | Installs istio on the cluster on the ARM platform (Mac M1/2 platform)                                                                            |
| istio_inject                    | Injects istio in namespaces                                                                                                                      |
| istio_extras                    | Installs extra tools for istio, kialis, prometheus, grafana, etc.                                                                                |
| istio_extras_arm                | Installs extra tools for istio, kialis, prometheus, grafana, etc.                                                                                |
| minikube_dashboard              | Shows the k8s dashboard                                                                                                                          |
| kiali_dashboard                 | Sows the kiali dashboard                                                                                                                         |
| concourse_init                  | Downloads concourse CI on k8s, creates the `concourse-main` namespace                                                                                        |
| concourse_keygen                | Generate keys for concourse                                                                                                                      |
| concourse_create                | Creates the stack for concourse, needs init and keygen to have run at least once                                                                 |
| concourse_delete                | Remove the concourse stack, leaves the `concourse-main` namespace                                                                                            
| concourse_all                   | Runs complete concourse installation                                                                                                             |
| concourse_web                   | Opens the concourse web site                                                                                                                     |
| provision_minikube              | Builds the complete kubernetes stack with apps, services, istio, and concourse                                                                   |
| provision_mac_arm_kube          | Builds the complete kubernetes stack with apps, services, istio, and concourse  for ARM                                                          |
| bounce_minikube                 | Tear down and completely rebuild the k8s stack.                                                                                                  |
| argocd_install                  | Install the argcd component in its separate namespace                                                                                            |
| argocd_dashboard                | open the argocd dashboard, note that you need to get the secret as password from k8s see `### Get the password for argocd`                                                        |



# Design and use
This is a complete stack development. This chapter will list some design choices.




## CI 

We use a tool concourse that runs in its own namespace. 
It is created separately by the following make tasks

| make task        | description                                                                                                                                                                      |
|------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| concourse_init   | Run once to download concourse and create the `concourse-main` namespace                                                                                                                     | 
| concourse_keygen | Generate the keys we use for setting up the stack, you need to run this before any `concourse_create` as the secrets are deleted from the system after applying it to kubernetes | 
| concourse_create | Create the stack, assumes `concource_init` and `concourse_keygen` have run                                                                                                       |
| concourse_delete | Clean up the stack except the `concourse-main` namespace                                                                                                                                     |
| concourse_all | Runs concourse_init, keygen and create in one go for convenience |

## CD 

For Continues deployment we use argocd that is installed in its own namespace. It will make sure the infrastructure is running 
and the applications are in a specific state. Note that it will use kustomize to generate the resources and as such has 
no knowledge of the infra and application layout. 

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
Note that since k8s 1.24 the secret is no longer automatically generated, this is not well documented as yet, so we generate the secret as is depicted.


## Environments 

We use `kustomize` to render the environments for the kubernetes setup. 
Note that it needs an external app installed, there is an integrated version in kubectl itself, but it is barely maintained. 

The scripts are in the `stack/kustomize` folder, and you call them from that folder with:

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

## concourse login
```bash
fly --target main login --concourse-url http://concourse.info:32080/
source <(fly completion --shell bash)
```

## concourse create pipeline 
```bash
cd ci/concourse/pipelines/apps
cat build-microservice-gateway-dev.yaml | fly -t main set-pipeline --pipeline ms-build-gateway --config -
```

### Set_passwords 
Create a docker.creds file in the `ci/concourse/secrets` folder (It will not be stored in git) in format
```bash
USERNAME=<youdockerusername>
PASSWORD=<yourdockerpassword>
```

Then 

```bash
k create ns concourse-main
source ci/concourse/secrets/docker.creds
k create secret generic registry-username -n concourse-main --from-literal=registry-username=$USERNAME
k create secret generic registry-password -n concourse-main --from-literal=registry-password=$PASSWORD
```

Create a git.creds file in the `ci/concourse/secrets` folder (It will not be stored in git) in format
```bash
GUSERNAME=<youdockerusername>
GPASSWORD=<yourdockerpassword>
```

Then

```bash
k create ns concourse-main
source ci/concourse/secrets/git.creds
k create secret generic git-username -n concourse-main --from-literal=git-username=$GUSERNAME
k create secret generic git-password -n concourse-main --from-literal=git-password=$GPASSWORD
```

## ArgoCD 
### Get the password for argocd

Now get the secret for login

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

# Notes on setup

## AKS

![img.png](docs/images/notes_aks_deployment.png)