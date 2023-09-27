# Provisioning and configuring a TPU training environment on GKE

Provisioning of a GKE based training environment for TPU v4 or v5e has been automated with Terraform. The example Terraform configuration performs the following provisioning tasks:

- Creates a network and a subnetwork
- Creates a service account to use for Workload Identity
- Adds the service account to a set of user defined roles. The default is `roles/storage.objectAdmin`
- Creates a GCS bucket to use for data and training artifacts
- Gives the service account `roles/storage.legacyBucketReader` permission on the bucket
- Creates a VPC-native zonal cluster
- Configures the cluster for Workload Identity
- Creates a CPU node pool to run CPU only workload - e.g. data preprocessing, or metrics management
- Creates a requested number of multi-host TPU node pools. Each node pool has the same topology. 

## Provision the environment

### Initialize Terraform
```
cd terraform

TF_STATE_BUCKET=jk-mlops-dev-tf-state
TF_STATE_PREFIX=gke-tpu-training

terraform init \
-backend-config="bucket=$TF_STATE_BUCKET" \
-backend-config="prefix=$TF_STATE_PREFIX"
```

### Apply configuration

Modify the following environment variables to reflect an environment topology required for your workload.

```
export PROJECT_ID=jk-mlops-dev
export ZONE=us-central2-b
export ARTIFACT_REPOSITORY_BUCKET_NAME=jk-gke-aiml-repository
export NETWORK_NAME=jk-gke-network
export SUBNET_NAME=jk-gke-subnet
export CLUSTER_NAME=jk-tpu-training-cluster
export TPU_SA_NAME=cloud-tpu-sa
export TPU_NAMESPACE=tpu-training
export TPU_MACHINE_TYPE=ct4p-hightpu-4t
export TPU_TOPOLOGY=2x2x2
export TPU_NUM_NODES=2
export NUM_TPU_POOLS=2
export CPU_NODE_POOL_MACHINE_TYPE=n1-standard-4


terraform apply \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=tpu_sa_name=$TPU_SA_NAME \
-var=tpu_namespace=$TPU_NAMESPACE \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
-var=num_tpu_pools=$NUM_TPU_POOLS \
-var=default_pool_machine_type=$CPU_NODE_POOL_MACHINE_TYPE \
-var=zone=$ZONE

```

### Get cluster credentials

```
gcloud container clusters get-credentials $CLUSTER_NAME
```

## Clean up

```
terraform destroy \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=zone=$ZONE \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=tpu_sa_name=$TPU_SA_NAME \
-var=tpu_namespace=$TPU_NAMESPACE \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
-var=default_pool_machine_type=$CPU_NODE_POOL_MACHINE_TYPE \
-var=zone=$ZONE
```


## TO BE DELETED - gcloud based setup

```
CLUSTER_NAME=jk-tpu-cluster
PROJECT_ID=jk-mlops-dev
REGION=us-central2
ZONE=us-central2-b
VERSION=1.27.3-gke.100
NUM_NODES=1
WORKLOAD_POOL="$PROJECT_ID.svc.id.goog"

gcloud container clusters create $CLUSTER_NAME \
--zone $ZONE \
--cluster-version $VERSION \
--workload-pool $WORKLOAD_POOL

```

## Create cluster credentials

```
gcloud container clusters get-credentials $CLUSTER_NAME
```

## Configure service account for Workload Identity

```
NAMESPACE=default
KSA_NAME=tpu-ksa

kubectl create serviceaccount $KSA_NAME \
--namespace $NAMESPACE
```

```
GSA_NAME=tpu-wid-sa

gcloud iam service-accounts create $GSA_NAME \
 --project=$PROJECT_ID
```

```
GSA_EMAIL=$GSA_NAME@$PROJECT_ID.iam.gserviceaccount.com

gcloud projects add-iam-policy-binding $PROJECT_ID \
--member "serviceAccount:$GSA_EMAIL" \
--role "roles/storage.objectAdmin" 
```

```
BUCKET_NAME=gs://jk-maxtext-logs

gcloud storage buckets add-iam-policy-binding $BUCKET_NAME \
--member=serviceAccount:$GSA_EMAIL \
--role="roles/storage.legacyBucketReader"
```


```
gcloud iam service-accounts add-iam-policy-binding $GSA_EMAIL \
    --role roles/iam.workloadIdentityUser \
    --member "serviceAccount:$PROJECT_ID.svc.id.goog[$NAMESPACE/$KSA_NAME]"
```

```
kubectl annotate serviceaccount $KSA_NAME \
--namespace $NAMESPACE \
iam.gke.io/gcp-service-account=$GSA_EMAIL
```

## Create a single host TPU node pool

```
NODE_POOL_NAME=single-host-v4-pool
MACHINE_TYPE=ct4p-hightpu-4t
NUM_NODES=2

gcloud container node-pools create $NODE_POOL_NAME \
--cluster=$CLUSTER_NAME \
--workload-metadata=GKE_METADATA \
--machine-type=$MACHINE_TYPE \
--num-nodes=$NUM_NODES
```

## Create a multi-host TPU slice

```
NODE_POOL_NAME=multi-host-v4-pool
MACHINE_TYPE=ct4p-hightpu-4t
TPU_TOPOLOGY=2x2x2
NUM_NODES=2

gcloud container node-pools create $NODE_POOL_NAME \
--cluster=$CLUSTER_NAME \
--workload-metadata=GKE_METADATA \
--zone=$ZONE \
--machine-type=$MACHINE_TYPE \
--tpu-topology=$TPU_TOPOLOGY \
--num-nodes=$NUM_NODES
```

## Remove a node pool

gcloud container node-pools delete $NODE_POOL_NAME \
--cluster=$CLUSTER_NAME



