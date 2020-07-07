GCP_PROJECT_ID=<gcp_project_id>
PROJECT=${GCP_PROJECT_ID}
AIRFLOW_IMAGE_TAG=0.1
GCR_HOST=asia.gcr.io
GCP_ZONE=us-west1-b
DEFAULT_SERVICE_ACCOUNT=<default_service_account>
MACHINE_TYPE=n1-standard-2

set-project:
	gcloud config set project ${GCP_PROJECT_ID}

# コンテナの管理 ↓↓
up-gcr: build
	gcloud config set project ${GCP_PROJECT_ID}
	gcloud auth configure-docker
	docker push ${GCR_HOST}/${GCP_PROJECT_ID}/airflow:${AIRFLOW_IMAGE_TAG}
	gcloud container images list-tags ${GCR_HOST}/${GCP_PROJECT_ID}/airflow

release: up-gcr
	docker push ${GCR_HOST}/${GCP_PROJECT_ID}/airflow:latest

build:
	docker build --rm \
	 --build-arg AIRFLOW_DEPS="datadog,dask" \
	 -t ${GCR_HOST}/${GCP_PROJECT_ID}/airflow:${AIRFLOW_IMAGE_TAG} .

update-dependencies:
	docker build --rm \
	 --build-arg AIRFLOW_DEPS="datadog,dask" \
	 --build-arg UPDATE_DEPENDENCIES="TRUE" \
	 -t ${GCR_HOST}/${GCP_PROJECT_ID}/airflow:${AIRFLOW_IMAGE_TAG} .
	docker run --rm -it ${GCR_HOST}/${GCP_PROJECT_ID}/airflow:${AIRFLOW_IMAGE_TAG} pip freeze > requirements.lock

python_ver:
	docker run --rm -it ${GCR_HOST}/${GCP_PROJECT_ID}/airflow:${AIRFLOW_IMAGE_TAG} python -V
# コンテナの管理 ↑↑

down:
	docker-compose -p ${PROJECT} down

up:
	docker-compose -p ${PROJECT} up -d


# コンテナホスト(GCE)の管理 ↓↓
host-init:
	gcloud beta compute disks create postgres-pro \
	 --project=${GCP_PROJECT_ID} \
	 --type=pd-standard \
	 --description=postgres\用\の\追\加デ\ィ\ス\ク \
	 --size=10GB \
	 --zone=us-west1-b
	sleep 10
	docker run --rm --name packer \
	 -v `pwd`/host:/source/host \
	 -v  ~/.config/gcloud/:/source/gcloud\
	 -e GOOGLE_APPLICATION_CREDENTIALS=/source/gcloud/application_default_credentials.json \
	 hashicorp/packer:light \
	 build \
	 -var "project_id=${GCP_PROJECT_ID}" \
 	 -var 'key_path=/source/gcloud/application_default_credentials.json' \
 	 -var 'script_path=/source/host/provision.sh' \
	 /source/host/host-image.json

host-init2:
	# ディスクを指定して立ち上げた後にフォーマットと鍵の設定
	gcloud compute instances create airflow-pro-init \
	 --project=${GCP_PROJECT_ID} \
	 --zone=${GCP_ZONE} \
	 --machine-type="n1-standard-2" \
	 --image-project=${GCP_PROJECT_ID} \
	 --image="airflow-server" \
	 --service-account=${DEFAULT_SERVICE_ACCOUNT} \
	 --scopes=https://www.googleapis.com/auth/cloud-platform \
	 --disk name="postgres-pro"

firewall-init:
	gcloud compute --project=${GCP_PROJECT_ID} firewall-rules create airflow-web \
	 --project=${GCP_PROJECT_ID} \
	 --description=airflow-web\ \へ\の\ア\ク\セ\ス\の\み\許\可 \
	 --direction=INGRESS \
 	 --priority=1000 \
 	 --network=default \
 	 --target-tags=airflow-web \
 	 --action=ALLOW  \
 	 --rules=tcp:8080  \
 	 --source-ranges=0.0.0.0/0 # ※全てを許可

gcs-init:
	gsutil mb -p ${GCP_PROJECT_ID}  -c STANDARD -l US-WEST1 -b on gs://<gcs_bucket>/

make-hostimage:
	# ホストイメージを更新する
	gcloud compute images create airflow-server-has-deploykey \
	 --project=${GCP_PROJECT_ID} \
	 --description=airflow-server\の\ホ\ス\ト\イ\メ\ー\ジ \
	 --source-disk=airflow-pro-init \
	 --source-disk-zone=${GCP_ZONE} \
	 --storage-location=us

deploy:
	gcloud compute instances create airflow-pro \
	 --project=${GCP_PROJECT_ID} \
	 --zone=${GCP_ZONE} \
	 --machine-type=${MACHINE_TYPE} \
	 --image-project=${GCP_PROJECT_ID} \
	 --image="airflow-server-has-deploykey" \
	 --service-account=${DEFAULT_SERVICE_ACCOUNT} \
	 --tags=airflow-web \
	 --scopes=https://www.googleapis.com/auth/cloud-platform \
	 --disk name="postgres-pro" \
	 --metadata-from-file startup-script=host/startup-script.sh

# コンテナホスト(GCE)の管理 ↑↑

# docker開発のユーティリティ ↓↓
log:
	docker logs ${PROJECT}_webserver_1

no-trunk:
	docker ps --no-trunc

docker-clean:
	docker container prune

docker-clean2:
	docker rmi `docker images -f "dangling=true" -q`