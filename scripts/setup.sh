#!/bin/bash
set -e

if [ -n "$CODESPACE_NAME" ]; then
    ENDPOINT="https://${CODESPACE_NAME}-4566.app.github.dev"
else
    ENDPOINT="http://localhost:4566"
fi
REGION="us-east-1"
FUNCTION_NAME="ec2-manager"
API_NAME="ec2-api"

echo "============================================"
echo "   DÉPLOIEMENT API-DRIVEN INFRASTRUCTURE"
echo "============================================"
echo ""

# ===========================================
# 1. Création d'un AMI dans LocalStack
# ===========================================
echo "=== 1. Enregistrement d'un AMI dans LocalStack ==="
AMI_ID=$(awslocal ec2 register-image \
    --name "localstack-ami" \
    --description "AMI for LocalStack API-Driven atelier" \
    --architecture x86_64 \
    --root-device-name "/dev/sda1" \
    --block-device-mappings '[{"DeviceName":"/dev/sda1","Ebs":{"VolumeSize":8}}]' \
    --query 'ImageId' \
    --output text)
echo "AMI créé : $AMI_ID"

# ===========================================
# 2. Création de l'instance EC2
# ===========================================
echo ""
echo "=== 2. Création de l'instance EC2 ==="
INSTANCE_ID=$(awslocal ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type t2.micro \
    --query 'Instances[0].InstanceId' \
    --output text)
echo "Instance créée : $INSTANCE_ID"

STATE=$(awslocal ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text)
echo "Statut initial : $STATE"

# ===========================================
# 3. Création du rôle IAM pour Lambda
# ===========================================
echo ""
echo "=== 3. Création du rôle IAM Lambda ==="
awslocal iam create-role \
    --role-name lambda-ec2-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "lambda.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }' > /dev/null 2>&1 || echo "Rôle déjà existant, on continue."

ROLE_ARN="arn:aws:iam::000000000000:role/lambda-ec2-role"
echo "Rôle IAM : $ROLE_ARN"

# ===========================================
# 4. Packaging et création de la Lambda
# ===========================================
echo ""
echo "=== 4. Packaging de la fonction Lambda ==="
cd lambda
zip -j ../function.zip handler.py
cd ..
echo "Archive function.zip créée."

echo ""
echo "=== 5. Déploiement de la fonction Lambda ==="
awslocal lambda create-function \
    --function-name "$FUNCTION_NAME" \
    --runtime python3.9 \
    --handler handler.handler \
    --zip-file fileb://function.zip \
    --role "$ROLE_ARN" \
    --timeout 30 \
    --environment "Variables={ENDPOINT_URL=$ENDPOINT}" > /dev/null
echo "Lambda '$FUNCTION_NAME' déployée."

# Attente que la Lambda soit active
echo "Attente que la Lambda soit prête..."
for i in $(seq 1 15); do
    LAMBDA_STATE=$(awslocal lambda get-function \
        --function-name "$FUNCTION_NAME" \
        --query 'Configuration.State' \
        --output text 2>/dev/null)
    if [ "$LAMBDA_STATE" = "Active" ]; then
        echo "Lambda active !"
        break
    fi
    echo "  État actuel : $LAMBDA_STATE (tentative $i/15)..."
    sleep 2
done

if [ "$LAMBDA_STATE" != "Active" ]; then
    echo "ERREUR : La Lambda n'est pas passée en état Active après 30s."
    exit 1
fi

# Test de la Lambda
echo "Test de la Lambda..."
awslocal lambda invoke \
    --function-name "$FUNCTION_NAME" \
    --payload "{\"queryStringParameters\":{\"action\":\"status\",\"instance_id\":\"$INSTANCE_ID\"}}" \
    /tmp/lambda-test-output.json > /dev/null
echo "Résultat du test :"
cat /tmp/lambda-test-output.json
echo ""

# ===========================================
# 5. Création de l'API Gateway
# ===========================================
echo ""
echo "=== 6. Création de l'API Gateway ==="
API_ID=$(awslocal apigateway create-rest-api \
    --name "$API_NAME" \
    --query 'id' \
    --output text)
echo "API ID : $API_ID"

# Récupérer la ressource racine "/"
ROOT_ID=$(awslocal apigateway get-resources \
    --rest-api-id "$API_ID" \
    --query 'items[0].id' \
    --output text)

# Créer la ressource /ec2
RESOURCE_ID=$(awslocal apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ROOT_ID" \
    --path-part "ec2" \
    --query 'id' \
    --output text)
echo "Resource /ec2 : $RESOURCE_ID"

# Méthode GET sur /ec2
awslocal apigateway put-method \
    --rest-api-id "$API_ID" \
    --resource-id "$RESOURCE_ID" \
    --http-method GET \
    --authorization-type NONE > /dev/null

# Intégration Lambda (AWS_PROXY)
LAMBDA_ARN="arn:aws:lambda:${REGION}:000000000000:function:${FUNCTION_NAME}"

awslocal apigateway put-integration \
    --rest-api-id "$API_ID" \
    --resource-id "$RESOURCE_ID" \
    --http-method GET \
    --type AWS_PROXY \
    --integration-http-method POST \
    --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/${LAMBDA_ARN}/invocations" > /dev/null

# Déploiement sur le stage "dev"
awslocal apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name dev > /dev/null
echo "API déployée sur le stage 'dev'."

# ===========================================
# RÉSUMÉ
# ===========================================
BASE_URL="${ENDPOINT}/restapis/${API_ID}/dev/_user_request_/ec2"

echo ""
echo "============================================"
echo "   DÉPLOIEMENT TERMINÉ AVEC SUCCÈS"
echo "============================================"
echo ""
echo "AMI ID       : $AMI_ID"
echo "Instance ID  : $INSTANCE_ID"
echo "API ID       : $API_ID"
echo ""
echo "--- URLs ---"
echo ""
echo "START  : ${BASE_URL}?action=start&instance_id=${INSTANCE_ID}"
echo "STOP   : ${BASE_URL}?action=stop&instance_id=${INSTANCE_ID}"
echo "STATUS : ${BASE_URL}?action=status&instance_id=${INSTANCE_ID}"
echo ""
echo "--- Commandes curl ---"
echo ""
echo "curl \"${BASE_URL}?action=start&instance_id=${INSTANCE_ID}\""
echo "curl \"${BASE_URL}?action=stop&instance_id=${INSTANCE_ID}\""
echo "curl \"${BASE_URL}?action=status&instance_id=${INSTANCE_ID}\""
echo ""
echo "Si vous utilisez Codespaces, remplacez ${ENDPOINT} par l'URL publique du port 4566."