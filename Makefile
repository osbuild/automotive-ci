.PHONY: dependencies up_stage up_prod

dependencies:
	pip install --upgrade pip
	pip install -r requirements.txt

up_stage: dependencies
	ansible-playbook deployment/site.yml -e env=stage

up_prod: dependencies
	ansible-playbook deployment/site.yml -e env=prod
