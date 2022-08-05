TARGET_USER=${1:-phiroict}

mkdir certs_${TARGET_USER}
cd certs_${TARGET_USER}
openssl genrsa -out ${TARGET_USER}.key 4096
openssl req -new -key ${TARGET_USER}.key -out ${TARGET_USER}.csr -subj "/CN=${TARGET_USER}/O=gen-code-pipeline"
sudo openssl x509 -req -in ${TARGET_USER}.csr -CA /etc/kubernetes/pki/ca.crt -CAkey /etc/kubernetes/pki/ca.key -CAcreateserial -out ${TARGET_USER}.crt -days 500
echo "Generation complete "
pwd
ls -l
echo "Now attaching the certificate to the user"
PASSWORD=$(cat /proc/sys/kernel/random/uuid) 
kubectl config set-credentials ${TARGET_USER} --client-certificate=$(pwd)/${TARGET_USER}.crt --client-key=$(pwd)/${TARGET_USER}.key --username=${TARGET_USER} --password=${PASSWORD}
kubectl config set-context ${TARGET_USER} --cluster=kubernetes --user=${TARGET_USER} --namespace=default
echo "Password, will be printend only once, do not lose it!: '${PASSWORD}'"
echo ${TARGET_USER}:${PASSWORD} > secret-password-cluster.txt
cd - 