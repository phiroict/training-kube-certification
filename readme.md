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

# Issue 

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