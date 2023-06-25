ENVS="dev test uat prod"
for CURRENT_ENV in ${ENVS}; do
kubectl create -n istio-system secret tls gateway-cred-${CURRENT_ENV} \
  --key=${CURRENT_ENV}/example_certs1/${CURRENT_ENV}.phiroict.local.key \
  --cert=${CURRENT_ENV}/example_certs1/${CURRENT_ENV}.phiroict.local.crt
done
