#!/usr/bin/env bash

DOMAIN="phiroict.local"
mkdir -p example_certs1
mkdir -p example_certs2
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/O=example Inc./CN=${DOMAIN}" -keyout example_certs1/${DOMAIN}.key -out example_certs1/${DOMAIN}.crt
openssl req -out example_certs1/httpbin.${DOMAIN}.csr -newkey rsa:2048 -nodes -keyout example_certs1/httpbin.${DOMAIN}.key -subj "/CN=httpbin.${DOMAIN}/O=httpbin organization"
openssl x509 -req -sha256 -days 365 -CA example_certs1/${DOMAIN}.crt -CAkey example_certs1/${DOMAIN}.key -set_serial 0 -in example_certs1/httpbin.${DOMAIN}.csr -out example_certs1/httpbin.${DOMAIN}.crt
openssl req -out example_certs1/helloworld.${DOMAIN}.csr -newkey rsa:2048 -nodes -keyout example_certs1/helloworld.${DOMAIN}.key -subj "/CN=helloworld.${DOMAIN}/O=helloworld organization"
openssl x509 -req -sha256 -days 365 -CA example_certs1/${DOMAIN}.crt -CAkey example_certs1/${DOMAIN}.key -set_serial 1 -in example_certs1/helloworld.${DOMAIN}.csr -out example_certs1/helloworld.${DOMAIN}.crt
openssl req -x509 -sha256 -nodes -days 365 -newkey rsa:2048 -subj "/O=example Inc./CN=${DOMAIN}" -keyout example_certs2/${DOMAIN}.key -out example_certs2/${DOMAIN}.crt
openssl req -out example_certs2/httpbin.${DOMAIN}.csr -newkey rsa:2048 -nodes -keyout example_certs2/httpbin.${DOMAIN}.key -subj "/CN=httpbin.${DOMAIN}/O=httpbin organization"
openssl x509 -req -sha256 -days 365 -CA example_certs2/${DOMAIN}.crt -CAkey example_certs2/${DOMAIN}.key -set_serial 0 -in example_certs2/httpbin.${DOMAIN}.csr -out example_certs2/httpbin.${DOMAIN}.crt
openssl req -out example_certs1/client.${DOMAIN}.csr -newkey rsa:2048 -nodes -keyout example_certs1/client.${DOMAIN}.key -subj "/CN=client.${DOMAIN}/O=client organization"
openssl x509 -req -sha256 -days 365 -CA example_certs1/${DOMAIN}.crt -CAkey example_certs1/${DOMAIN}.key -set_serial 1 -in example_certs1/client.${DOMAIN}.csr -out example_certs1/client.${DOMAIN}.crt
