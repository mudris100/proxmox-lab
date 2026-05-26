.PHONY: deploy terraform provision destroy

deploy:
	cd terraform && terraform apply -auto-approve
	cd ansible && ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

terraform:
	cd terraform && terraform apply -auto-approve

provision:
	cd ansible && ansible-playbook playbook.yml --vault-password-file ~/.vault_pass

destroy:
	cd terraform && terraform destroy -auto-approve
