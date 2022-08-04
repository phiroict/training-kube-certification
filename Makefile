create_user:
	bash ./create_certificate.sh "phiroict"
create_readonly_role:
	k apply -f set-role-for-user.yaml
create_sa_token_dashboard_admin:
	k apply -f sa_token_generation.yaml