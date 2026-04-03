# ATELIER API-DRIVEN INFRASTRUCTURE

Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé avec LocalStack.

Ce projet permet de piloter une instance EC2 (démarrage, arrêt, statut) via de simples requêtes HTTP, grâce à une architecture **API Gateway → Lambda → EC2**, le tout simulé dans **LocalStack** et exécuté dans **GitHub Codespaces**.

---

## Architecture

```
Utilisateur (curl / navigateur)
        │
        ▼
   API Gateway (GET /ec2)
        │
        ▼
   Lambda (ec2-manager)
        │
        ▼
   EC2 (start / stop / status)
```

Une requête HTTP `GET` est envoyée à l'API Gateway avec deux paramètres :
- `action` : `start`, `stop` ou `status`
- `instance_id` : l'identifiant de l'instance EC2

L'API Gateway transmet la requête à une fonction Lambda Python qui appelle l'API EC2 de LocalStack pour exécuter l'action demandée.

---

## Prérequis

- Un compte **GitHub** avec accès à **GitHub Codespaces**
- Un compte **LocalStack** avec un **Auth Token** (gratuit sur [app.localstack.cloud](https://app.localstack.cloud))
- Aucune installation locale nécessaire, tout se fait dans le Codespace

---

## Structure du projet

```
API_Driven/
├── lambda/
│   └── handler.py          # Fonction Lambda Python (start/stop/status EC2)
├── scripts/
│   └── setup.sh            # Script de déploiement automatisé
├── Makefile                 # Commandes d'automatisation
├── .gitignore               # Exclusion des fichiers générés
└── README.md                # Ce fichier
```

---

## Guide d'installation

### Étape 1 — Créer le Codespace

1. Rendez-vous sur votre fork du repository **API_Driven** sur GitHub
2. Cliquez sur **Code** → **Codespaces** → **Create codespace on main**
3. Attendez que l'environnement se charge

### Étape 2 — Récupérer votre token LocalStack

1. Créez un compte sur [app.localstack.cloud](https://app.localstack.cloud) si ce n'est pas déjà fait
2. Rendez-vous dans **Account** → **Auth Tokens**
3. Copiez votre token (il ressemble à `ls-xxxxxxxxxx`)

### Étape 3 — Premier setup

Dans le terminal du Codespace, lancez :

```bash
make first-setup
```

Cette commande va :
- Installer toutes les dépendances (LocalStack, AWS CLI, boto3)
- Vous demander votre **token LocalStack** (collez-le quand le prompt apparaît)
- Démarrer LocalStack en arrière-plan
- Vérifier que les services AWS sont disponibles

### Étape 4 — Déployer l'infrastructure

```bash
make deploy
```

Le script crée automatiquement :
1. Un **AMI** enregistré dans LocalStack
2. Une **instance EC2** basée sur cet AMI
3. Un **rôle IAM** pour la Lambda
4. Une **fonction Lambda** Python qui pilote l'EC2
5. Une **API Gateway** avec une route `GET /ec2`

À la fin du déploiement, les **3 URLs** sont affichées dans le terminal.

### Étape 5 — Rendre le port public (important pour Codespaces)

1. Dans le Codespace, cliquez sur l'onglet **PORTS** en bas
2. Trouvez le port **4566**
3. Clic droit → **Port Visibility** → **Public**
4. L'URL publique suit le format : `https://<CODESPACE_NAME>-4566.app.github.dev`

---

## Utilisation

### Avec curl (localhost)

```bash
# Vérifier le statut de l'instance
curl "http://localhost:4566/restapis/<API_ID>/dev/_user_request_/ec2?action=status&instance_id=<INSTANCE_ID>"

# Stopper l'instance
curl "http://localhost:4566/restapis/<API_ID>/dev/_user_request_/ec2?action=stop&instance_id=<INSTANCE_ID>"

# Démarrer l'instance
curl "http://localhost:4566/restapis/<API_ID>/dev/_user_request_/ec2?action=start&instance_id=<INSTANCE_ID>"
```

### Avec le navigateur (URL publique Codespace)

Remplacez `http://localhost:4566` par l'URL publique de votre port 4566 :

```
https://<CODESPACE_NAME>-4566.app.github.dev/restapis/<API_ID>/dev/_user_request_/ec2?action=status&instance_id=<INSTANCE_ID>
```

### Réponses attendues

```json
{"message": "Instance i-xxxxxxxxxxxx is running"}
{"message": "Instance i-xxxxxxxxxxxx stopped"}
{"message": "Instance i-xxxxxxxxxxxx started"}
```

---

## Commandes Makefile

| Commande | Description |
|----------|-------------|
| `make first-setup` | Installation complète (dépendances + LocalStack). Demande le token LocalStack. |
| `make setup` | Redémarrer LocalStack uniquement (si déjà installé). Demande le token. |
| `make deploy` | Déployer l'infrastructure (EC2 + Lambda + API Gateway). |
| `make clean` | Arrêter LocalStack et supprimer les fichiers temporaires. |
| `make redeploy` | Clean + restart LocalStack + redéploiement complet. |

---

## Détails techniques

### Lambda (`handler.py`)

La fonction Lambda reçoit l'événement HTTP via API Gateway (intégration `AWS_PROXY`), extrait les paramètres `action` et `instance_id` du querystring, puis appelle le service EC2 de LocalStack via boto3.

Point technique important : la Lambda s'exécute dans un container Docker séparé au sein de LocalStack. Pour communiquer avec l'API EC2, elle utilise l'IP du réseau Docker interne (`172.17.0.2`) et non `localhost`, qui pointerait vers le container de la Lambda lui-même.

### API Gateway

L'API est configurée en mode REST avec une seule ressource `/ec2` et une méthode `GET`. L'intégration avec la Lambda est de type `AWS_PROXY`, ce qui signifie que la requête HTTP complète est transmise à la Lambda et que la réponse de la Lambda est directement renvoyée au client.

### LocalStack

LocalStack émule les services AWS en local. Les services utilisés sont : EC2, Lambda, IAM et API Gateway. Le token d'authentification est nécessaire pour activer les fonctionnalités avancées (notamment le support complet d'EC2).

---

## Dépannage

**`awslocal` ne fonctionne pas (`No such file or directory: aws`)**
→ Installer le CLI AWS : `pip install awscli --break-system-packages`

**La Lambda retourne `ResourceConflictException: Pending`**
→ La Lambda n'a pas fini de s'initialiser. Attendre quelques secondes et réessayer.

**La Lambda retourne `Could not connect to the endpoint URL`**
→ Problème de réseau Docker. Vérifier que `handler.py` utilise `172.17.0.2` et non `localhost` pour l'endpoint.

**`InvalidAMI.ID.NotFound`**
→ Utiliser `awslocal ec2 register-image` pour créer un AMI valide avant de lancer une instance.

---

## Autrice

Réalisé par Agathe dans le cadre de l'atelier API-Driven Infrastructure, présenté — EPSI 2026.

---
Cours présenté par M. STOCKER, dont voici l'énoncé initial :
---
------------------------------------------------------------------------------------------------------
ATELIER API-DRIVEN INFRASTRUCTURE
------------------------------------------------------------------------------------------------------
L’idée en 30 secondes : **Orchestration de services AWS via API Gateway et Lambda dans un environnement émulé**.  
Cet atelier propose de concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, des actions d’infrastructure sur des **instances EC2**, le tout dans un **environnement AWS simulé avec LocalStack** et exécuté dans **GitHub Codespaces**. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.Cet atelier propose de concevoir une architecture API-driven dans laquelle une requête HTTP déclenche, via API Gateway et une fonction Lambda, des actions d’infrastructure sur des instances EC2, le tout dans un environnement AWS simulé avec LocalStack et exécuté dans GitHub Codespaces. L’objectif est de comprendre comment des services cloud serverless peuvent piloter dynamiquement des ressources d’infrastructure, indépendamment de toute console graphique.
  
-------------------------------------------------------------------------------------------------------
Séquence 1 : Codespace de Github
-------------------------------------------------------------------------------------------------------
Objectif : Création d'un Codespace Github  
Difficulté : Très facile (~5 minutes)
-------------------------------------------------------------------------------------------------------
RDV sur Codespace de Github : <a href="https://github.com/features/codespaces" target="_blank">Codespace</a> **(click droit ouvrir dans un nouvel onglet)** puis créer un nouveau Codespace qui sera connecté à votre Repository API-Driven.
  
---------------------------------------------------
Séquence 2 : Création de l'environnement AWS (LocalStack)
---------------------------------------------------
Objectif : Créer l'environnement AWS simulé avec LocalStack  
Difficulté : Simple (~5 minutes)
---------------------------------------------------

Dans le terminal du Codespace copier/coller les codes ci-dessous etape par étape :  

**Installation de l'émulateur LocalStack**  
```
sudo -i mkdir rep_localstack
```
```
sudo -i python3 -m venv ./rep_localstack
```
```
sudo -i pip install --upgrade pip && python3 -m pip install localstack && export S3_SKIP_SIGNATURE_VALIDATION=0
```
```
localstack start -d
```
**vérification des services disponibles**  
```
localstack status services
```
**Réccupération de l'API AWS Localstack** 
Votre environnement AWS (LocalStack) est prêt. Pour obtenir votre AWS_ENDPOINT cliquez sur l'onglet **[PORTS]** dans votre Codespace et rendez public votre port **4566** (Visibilité du port).
Réccupérer l'URL de ce port dans votre navigateur qui sera votre ENDPOINT AWS (c'est à dire votre environnement AWS).
Conservez bien cette URL car vous en aurez besoin par la suite.  

Pour information : IL n'y a rien dans votre navigateur et c'est normal car il s'agit d'une API AWS (Pas un développement Web type UX).

---------------------------------------------------
Séquence 3 : Exercice
---------------------------------------------------
Objectif : Piloter une instance EC2 via API Gateway
Difficulté : Moyen/Difficile (~2h)
---------------------------------------------------  
Votre mission (si vous l'acceptez) : Concevoir une architecture **API-driven** dans laquelle une requête HTTP déclenche, via **API Gateway** et une **fonction Lambda**, lancera ou stopera une **instance EC2** déposée dans **environnement AWS simulé avec LocalStack** et qui sera exécuté dans **GitHub Codespaces**. [Option] Remplacez l'instance EC2 par l'arrêt ou le lancement d'un Docker.  

**Architecture cible :** Ci-dessous, l'architecture cible souhaitée.   
  
![Screenshot Actions](API_Driven.png)   
  
---------------------------------------------------  
## Processus de travail (résumé)

1. Installation de l'environnement Localstack (Séquence 2)
2. Création de l'instance EC2
3. Création des API (+ fonction Lambda)
4. Ouverture des ports et vérification du fonctionnement

---------------------------------------------------
Séquence 4 : Documentation  
Difficulté : Facile (~30 minutes)
---------------------------------------------------
**Complétez et documentez ce fichier README.md** pour nous expliquer comment utiliser votre solution.  
Faites preuve de pédagogie et soyez clair dans vos expliquations et processus de travail.  
   
---------------------------------------------------
Evaluation
---------------------------------------------------
Cet atelier, **noté sur 20 points**, est évalué sur la base du barème suivant :  
- Repository exécutable sans erreur majeure (4 points)
- Fonctionnement conforme au scénario annoncé (4 points)
- Degré d'automatisation du projet (utilisation de Makefile ? script ? ...) (4 points)
- Qualité du Readme (lisibilité, erreur, ...) (4 points)
- Processus travail (quantité de commits, cohérence globale, interventions externes, ...) (4 points) 
