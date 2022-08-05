# Kubernetes calls  --------------------------------------------------------------------------------------------------------------
create_user:
	bash ./create_certificate.sh "phiroict"
create_readonly_role_sa:
	k apply -f set-role-for-serviceaccount.yaml
create_sa_token_dashboard_admin:
	k apply -f sa_token_generation.yaml
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

## Release build
app_build_gateway_release:
	cd apps/gateway && cargo build --release
app_build_datasource_release:
	cd apps/datasource && cargo build --release
app_build_all_release: app_build_gateway_release app_build_datasource_release
