source ci/concourse/secrets/git.creds
kubectl create secret generic git-username -n concourse-main --from-literal=git-username=$GUSERNAME
kubectl create secret generic git-password -n concourse-main --from-literal=git-password=$GPASSWORD
source ci/concourse/secrets/docker.creds
kubectl create secret generic registry-username -n concourse-main --from-literal=registry-username=$USERNAME
kubectl create secret generic registry-password -n concourse-main --from-literal=registry-password=$PASSWORD
