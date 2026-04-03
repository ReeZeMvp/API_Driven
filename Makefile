.PHONY: first-setup setup deploy clean redeploy

## Premier setup complet (LocalStack + dépendances)
first-setup:
	@echo "============================================"
	@echo "   PREMIER SETUP - LOCALSTACK"
	@echo "============================================"
	@echo ""
	@echo "Installation des dépendances système..."
	sudo mkdir -p /root/rep_localstack
	sudo python3 -m venv /root/rep_localstack
	pip install --upgrade pip --break-system-packages
	pip install localstack awscli awscli-local boto3 --break-system-packages
	export S3_SKIP_SIGNATURE_VALIDATION=0
	@echo ""
	@read -p "Entrez votre token LocalStack : " TOKEN; \
	export LOCALSTACK_AUTH_TOKEN=$$TOKEN; \
	echo "Token configuré."; \
	echo "Démarrage de LocalStack..."; \
	LOCALSTACK_AUTH_TOKEN=$$TOKEN localstack start -d; \
	echo "Attente du démarrage (15s)..."; \
	sleep 15; \
	localstack status services

## Démarrer LocalStack (si déjà installé)
setup:
	@read -p "Entrez votre token LocalStack : " TOKEN; \
	LOCALSTACK_AUTH_TOKEN=$$TOKEN localstack start -d
	@echo "Attente du démarrage..."
	sleep 15
	localstack status services

## Déployer l'infra (EC2 + Lambda + API Gateway)
deploy:
	chmod +x scripts/setup.sh
	bash scripts/setup.sh

## Nettoyer tout (restart LocalStack)
clean:
	localstack stop
	rm -f function.zip
	@echo "Environnement nettoyé."

## Clean + redeploy en une commande
redeploy: clean
	@read -p "Entrez votre token LocalStack : " TOKEN; \
	LOCALSTACK_AUTH_TOKEN=$$TOKEN localstack start -d
	@echo "Attente du démarrage de LocalStack..."
	sleep 15
	bash scripts/setup.sh