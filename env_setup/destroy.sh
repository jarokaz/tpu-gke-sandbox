# Setting variables for tutorial using vars.env
source vars.env

[[ ! "${PROJECT_ID}" ]] && echo -e "Please export PROJECT_ID variable (\e[95mexport PROJECT_ID=<YOUR PROJECT ID>\e[0m)\nExiting." && exit 0
echo -e "\e[95mPROJECT_ID is set to ${PROJECT_ID}\e[0m"

gcloud config set core/project ${PROJECT_ID} && \

gcloud builds submit \
  --config cloudbuild.destroy.yaml \
  --substitutions _TF_STATE_BUCKET=$TF_STATE_BUCKET,_TF_STATE_PREFIX=$TF_STATE_PREFIX,_REGION=$REGION,_TENSORBOARD_REGION=$TENSORBOARD_REGION,_ZONE=$ZONE,_ARTIFACT_REPOSITORY_BUCKET_NAME=$ARTIFACT_REPOSITORY_BUCKET_NAME,_NETWORK_NAME=$NETWORK_NAME,_SUBNET_NAME=$SUBNET_NAME,_CLUSTER_NAME=$CLUSTER_NAME,_NAMESPACE=$NAMESPACE,_TPU_TYPE=$TPU_TYPE,_NUM_TPU_POOLS=$NUM_TPU_POOLS \
  --timeout "2h" \
  --machine-type=e2-highcpu-32 \
  --quiet \
  --async && \

echo -e "\e[95mYou can view the Cloudbuild status through https://console.cloud.google.com/cloud-build/builds?project=${PROJECT_ID}\e[0m"