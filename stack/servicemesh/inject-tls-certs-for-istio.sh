kubectl create -n istio-system secret tls httpbin-credential \
  --key=example_certs1/httpbin.phiroict.local.key \
  --cert=example_certs1/httpbin.phiroict.local.crt