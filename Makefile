include .env
include sensitive.env
export

# setup-dev: set-project cloud-sql-setup gcs-setup artifact-reg-setup

create-project:
	gcloud projects create $(PROJECT_ID) --name $(PROJECT_NAME)

set-project:
	gcloud config set project $(PROJECT_ID)

enable-services:
	gcloud services enable run.googleapis.com
	gcloud services enable sqladmin.googleapis.com
	gcloud services enable artifactregistry.googleapis.com
	gcloud services enable secretmanager.googleapis.com

# backend database:
cloud-sql-setup:
	gcloud sql instances create $(INSTANCE_NAME) \
		--database-version=POSTGRES_15 \
		--region=$(REGION) \
		--tier=db-f1-micro \
		--storage-type=HDD \
		--storage-size=10GB \
		--authorized-networks=0.0.0.0/0

	gcloud sql users create $(USERNAME) \
		--instance=$(INSTANCE_NAME) \
		--password=$(PASSWORD)

	gcloud sql databases create $(DATABASE_NAME) \
		--instance=$(INSTANCE_NAME)

# ip address needed later for gcp secrets:
	gcloud sql instances describe mlflow-db-instance --format=json | \
		jq -r '.ipAddresses[] | select(.type=="PRIMARY") | .ipAddress'

# artifact store:
gcs-setup:
	gcloud storage buckets create gs://$(BUCKET_NAME) \
		--location $(REGION) \
		--uniform-bucket-level-access \
		--enable-hierarchical-namespace

	gcloud storage folders create gs://$(BUCKET_NAME)/$(FOLDER_NAME)

# setup artifact registry to store images for cloud run
artifact-reg-setup:
	gcloud artifacts repositories create $(DOCKER_REPO) \
		--repository-format=docker \
		--location=$(REGION) \
		--description="Docker repository for NRL predictor"
	gcloud auth configure-docker $(REGION)-docker.pkg.dev

# create secrets for cloud run service
create-secrets:
	gcloud secrets create DB_URL --replication-policy="automatic"
	gcloud secrets create BUCKET_URL --replication-policy="automatic"

add-secrets: create-secrets
	printf "%s" "postgresql://$(DB_USERNAME):$(DB_PASSWORD)@34.40.174.129/$(DATABASE_NAME)" | \
    	gcloud secrets versions add DB_URL --data-file=-

	printf "%s" "gs://$(BUCKET_NAME)/$(FOLDER_NAME)" | \
    	gcloud secrets versions add BUCKET_URL --data-file=-

# service account and permissions
iam-setup:
	gcloud iam service-accounts create $(SVC_ACCT)

	gcloud iam service-accounts keys create ~/.gcp/$(SVC_ACCT)-key.json \
    	--iam-account=$(SVC_EMAIL)

	gcloud storage buckets add-iam-policy-binding gs://$(BUCKET_NAME) \
		--member=serviceAccount:$(SVC_EMAIL) \
		--role=roles/storage.admin

	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member=serviceAccount:$(SVC_EMAIL) \
		--role=roles/run.admin

	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member=serviceAccount:$(SVC_EMAIL) \
		--role=roles/artifactregistry.writer

	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member=serviceAccount:$(SVC_EMAIL) \
		--role=roles/cloudsql.client

	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member=serviceAccount:$(SVC_EMAIL) \
		--role=roles/secretmanager.secretAccessor

# impersonation to run cloud run deployment on gha
	gcloud iam service-accounts add-iam-policy-binding $(SVC_EMAIL) \
		--member=serviceAccount:$(SVC_EMAIL) \
		--role=roles/iam.serviceAccountUser

# secrets/vars added to gh for use in ci/cd
setup-gh-cli:
	brew install gh
	gh auth-login

# setup-gh-cli
add-secrets-gh: 
	gh secret set SVC_KEY < ~/.gcp/mlflow-svc-acct-key.json

get-service-url:
	gcloud run services describe $(SERVICE_NAME) \
		--region=$(REGION) \
		--project=$(PROJECT_ID) \
		--format='value(status.url)'

# IMAGE_TAG=$(REGION)-docker.pkg.dev/$(PROJECT_ID)/$(DOCKER_REPO)/$(IMAGE_NAME):latest
# cloud-run-deploy:
# 	gcloud run deploy $(SERVICE_NAME) \
# 		--image $(IMAGE_TAG) \
# 		--region $(REGION) \
# 		--service-account $(SVC_EMAIL) \
# 		--update-secrets=DB_URL=DB_URL:latest \
# 		--update-secrets=BUCKET_URL=BUCKET_URL:latest \
# 		--memory=2Gi \
# 		--timeout=600
