# Create users 

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

# Environments 

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

# Issue context [solved]

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