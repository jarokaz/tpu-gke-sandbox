#  Running TPU training workloads on GKE

This reference guide compiles best practices, prescriptive guidance, and code samples for running large-scale TPU v4 and TPU v5e machine learning training workloads on Google Kubernetes Engine (GKE).
The guide covers two main topics:
- **Configuring a GKE based environment for large scale training on Cloud TPUs**
  - This section describes how to configure a GKE cluster to optimize for running large-scale machine learning training workloads on **Cloud TPUs**.
- **Defining, Submitting, and Monitoring Training Jobs**
  - This section provides guidance on how to define, submit, and manage training jobs using the Kubernetes [JobSet](https://github.com/kubernetes-sigs/jobset) and [Kueue](https://github.com/kubernetes-sigs/kueue) APIs.

We also include Terraform configuration for provisioning the training environment and code samples for a variety of training workloads.



## The training environment

The diagram below depicts a high-level architecture of the training environment.


![arch](/images/training-cluster.png)

The foundation of the environment is a regional, VPC-native GKE cluster. The cluster comprises a single node pool with CPU-only nodes and several [Multi-host TPU node pools](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus).

This cluster topology supports running both [single-slice and multi-slice TPU](https://cloud.google.com/tpu/docs/multislice-introduction) training jobs.

Training datasets and artifacts produced by training jobs (such as logs and checkpoints) are saved in Google Cloud Storage.

Training, data processing, and other components of a training workload are packaged as Docker container images and managed in Google Cloud Container Registry.

[Vertex AI TensorBoard](https://cloud.google.com/vertex-ai/docs/experiments/tensorboard-introduction) is used to track and visualize training metrics.

Cloud Monitoring is used to collect and analyze non-functional performance metrics, and Cloud Logging is used to manage logs produced by training workloads.

The GKE cluster is configured with Workload Identity. Training workloads impersonate an Identity and Access Management service account to access Google Cloud services, such as Google Cloud Storage and Vertex AI TensorBoard.


## Training workload processing 

The following diagram illustrates the process of submitting and processing training workloads in the training environment.

![training workloads](/images/workload-processing.png)


Provisioning of the environment has been automated with Terraform. The Terraform configuration can be found in the `env_setup/terraform` folder. Before applying the configuration you need to select an existing GCP project or create a new one and enable the following services:

```
PROJECT_ID=jk-mlops-dev

gcloud config set project $PROJECT_ID

gcloud services enable \
cloudbuild.googleapis.com \
compute.googleapis.com \
cloudresourcemanager.googleapis.com \
iam.googleapis.com \
container.googleapis.com \
cloudtrace.googleapis.com \
iamcredentials.googleapis.com \
monitoring.googleapis.com \
logging.googleapis.com \
aiplatform.googleapis.com \
config.googleapis.com 

```

### A service account for Infrastructure Manager

```
IM_SERVICE_ACCOUNT_NAME=infrastructure-manager-sa

gcloud iam service-accounts create $IM_SERVICE_ACCOUNT_NAME

gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$IM_SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/config.agent
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$IM_SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/compute.networkAdmin
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$IM_SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/compute.storageAdmin
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$IM_SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/aiplatform.user
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$IM_SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/iam.serviceAccountCreator
gcloud projects add-iam-policy-binding $PROJECT_ID --member="serviceAccount:$IM_SERVICE_ACCOUNT_NAME@$PROJECT_ID.iam.gserviceaccount.com" --role=roles/container.clusterAdmin



```

The Terraform configuration performs the following tasks:
- Creates a network and a subnet for a VPC-native GKE cluster.
- Creates a VPC-native cluster.
- Creates a node pool with nodes equipped with CPUs only.
- Creates a specified number of multi-host TPU node pools.
- Creates an IAM service account for Workload Identity.
- Assigns a specified set of roles to the Workload Identity service account.
- Configures the cluster for Workload Identity.
- Creates an IAM service account to be used as a custom service account for both CPU and TPU node pools
- Assigns a specified set of roles to the custom node pool service account
- Creates a Google Cloud Storage bucket.
- Adds the service account to `roles/storage.legacyBucketReader` bucket level permissions.

The Terraform configuration supports the following input variables:

| Variable | Description | Default |
| -------- | ------------|---------|
| region | The compute region for the environment | NA|
| artifact_repository_bucket_name|The name of the GCS bucket|NA|
| zone | The zone for the cluster. Make sure that the zone supports the required TPU resources| NA |
| networt_name | The name of the network for the cluster | NA |
| subnet_name | The name of the subnet  for the cluster | NA |
| subnet_ip_range | The IP address range for the subnet | 10.129.0.0/20 |
| pods_ip_range | A secondary IP range for pods | 192.168.64.0/20 |
| services_ip_range | A secondary IP range for services | 192.168.80.0/20 |
| cluster_name | The name of the cluster. | NA |
| gke_version | The version of GKE to deploy | 1.27.3-gke.100 |
| cluster_description | The cluster's description | GKE cluster for running TPU training workloads |
| cpu_pool_node_count | The number of nodes in a CPU node pool | 3 |
| cpu_pool_machine_type | The machine type for the CPU node pool | n1-standard-4 |
| cpu_pool_disk_type | The disk type for nodes in the CPU node pool | pd-standard|
| cpu_pool_disk_size | The disk size for noded in the CPU node pool | 200GB |
| tpu_sa_name | The name of the service account that will be provisioned and used for Workload Identity | cloud-tpu-sa |
| tpu_sa_roles | The roles to assign to the service account | roles/storage.objectAdmin, roles/logging.logWriter |
| gke_sa_name | The name of the custom service account for node pools | gke-sa |
| gke_sa_roles | The roles to assigne to the custom service account for node pools | roles/storage.objectAdmin, roles/logging.logWriter |
| tpu_namespace | The K8s namespace for TPU workloads | tpu-training |
| tpu_machine_type | The machine type for TPU node pools | ct4p-hightpu-4t |
| tpu_topology | A topology of a TPU slice to provision | 2x2x2 |
| tpu_num_nodes | The number of TPU hosts to provision. Must align with the TPU machine type and TPU topology | 2 |
| num_tpu_pools | The number of multi-host TPU node pools to provision | 1 |
| enable_tpu_autoscaling | Whether to enable outoscaling of TPU node pools | false |
| tpu_node_pool_name_prefix | A prefix that will be used to name TPU node pools. An index starting with 0 will be appended to the prefix to form a TPU node pool name | tpu-node-pool |
| multislice_group_name | A name that will be used to label a TPU node pools to support multi-slice jobs | multi-slice-group |

The Terraform is configured to maintain the configuration state in  Google Cloud Storage. To intialize Terraform execute the following command from the `terraform` folder:

```
TF_STATE_BUCKET=jk-mlops-dev-tf-state
TF_STATE_PREFIX=gke-tpu-training-environment

terraform init \
-backend-config="bucket=$TF_STATE_BUCKET" \
-backend-config="prefix=$TF_STATE_PREFIX"
```

To provision the environment configure the input variables and apply the configuration. For example, to create an environment with a single TPU v4-16 slice use the following settings.



```
export PROJECT_ID=jk-mlops-dev
export REGION=us-central2
export ZONE=us-central2-b
export ARTIFACT_REPOSITORY_BUCKET_NAME=jk-gke-aiml-repository
export NETWORK_NAME=jk-gke-network
export SUBNET_NAME=jk-gke-subnet
export CLUSTER_NAME=jk-tpu-training-cluster
export TPU_MACHINE_TYPE=ct4p-hightpu-4t
export TPU_TOPOLOGY=2x2x4
export TPU_NUM_NODES=4
export NUM_TPU_POOLS=2
export FORCE_DESTROY=true


terraform apply \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=force_destroy=$FORCE_DESTROY \
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
-var=num_tpu_pools=$NUM_TPU_POOLS \
-var=zone=$ZONE
```


```
export TF_STATE_BUCKET=jk-mlops-dev-tf-state
export TF_STATE_PREFIX=gke-tpu-training-environment

export PROJECT_ID=jk-mlops-dev
export REGION=us-central2
export ZONE=us-central2-b
export ARTIFACT_REPOSITORY_BUCKET_NAME=jk-gke-aiml-repository
export NETWORK_NAME=jk-gke-network
export SUBNET_NAME=jk-gke-subnet
export CLUSTER_NAME=jk-tpu-training-cluster
export NAMESPACE=tpu-training
export TPU_TYPE=v4-32
export NUM_TPU_POOLS=2
export NUM_OF_CHIPS=32

export JOBSET_API_VERSION="v0.2.3"
export KUEUE_API_VERSION=v0.4.2

gcloud builds submit \
  --config cloudbuild.provision.yaml \
  --substitutions _TF_STATE_BUCKET=$TF_STATE_BUCKET,_TF_STATE_PREFIX=$TF_STATE_PREFIX,_REGION=$REGION,_ZONE=$ZONE,_ARTIFACT_REPOSITORY_BUCKET_NAME=$ARTIFACT_REPOSITORY_BUCKET_NAME,_NETWORK_NAME=$NETWORK_NAME,_SUBNET_NAME=$SUBNET_NAME,_CLUSTER_NAME=$CLUSTER_NAME,_NAMESPACE=$NAMESPACE,_TPU_TYPE=$TPU_TYPE,_NUM_TPU_POOLS=$NUM_TPU_POOLS,_NUM_OF_CHIPS=$NUM_OF_CHIPS,_JOBSET_API_VERSION=$JOBSET_API_VERSION,_KUEUE_API_VERSION=$KUEUE_API_VERSION \
  --timeout "2h" \
  --machine-type=e2-highcpu-32 \
  --quiet


```


## Destroy
export TF_STATE_BUCKET=jk-mlops-dev-tf-state
export TF_STATE_PREFIX=gke-tpu-training-environment

export PROJECT_ID=jk-mlops-dev
export REGION=us-central2
export ZONE=us-central2-b
export ARTIFACT_REPOSITORY_BUCKET_NAME=jk-gke-aiml-repository
export NETWORK_NAME=jk-gke-network
export SUBNET_NAME=jk-gke-subnet
export CLUSTER_NAME=jk-tpu-training-cluster
export TPU_TYPE=v4-32
export NUM_TPU_POOLS=2
export NAMESPACE=tpu-training

export TPU_MACHINE_TYPE=ct4p-hightpu-4t
export TPU_TOPOLOGY=2x2x4
export TPU_NUM_NODES=4



gcloud builds submit \
  --config cloudbuild.destroy.yaml \
  --substitutions _TF_STATE_BUCKET=$TF_STATE_BUCKET,_TF_STATE_PREFIX=$TF_STATE_PREFIX,_REGION=$REGION,_ZONE=$ZONE,_ARTIFACT_REPOSITORY_BUCKET_NAME=$ARTIFACT_REPOSITORY_BUCKET_NAME,_NETWORK_NAME=$NETWORK_NAME,_SUBNET_NAME=$SUBNET_NAME,_CLUSTER_NAME=$CLUSTER_NAME,_NAMESPACE=$NAMESPACE,_TPU_TYPE=$TPU_TYPE,_NUM_TPU_POOLS=$NUM_TPU_POOLS \
  --timeout "2h" \
  --machine-type=e2-highcpu-32 \
  --quiet

```

export PROJECT_ID=jk-mlops-dev
export REGION=us-central2
export ZONE=us-central2-b
export ARTIFACT_REPOSITORY_BUCKET_NAME=jk-gke-aiml-repository
export NETWORK_NAME=jk-gke-network
export SUBNET_NAME=jk-gke-subnet
export CLUSTER_NAME=jk-tpu-training-cluster
export TPU_TYPE=v4-32
export NUM_TPU_POOLS=2

export TPU_MACHINE_TYPE=ct4p-hightpu-4t
export TPU_TOPOLOGY=2x2x4
export TPU_NUM_NODES=4


terraform plan \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=force_destroy=$FORCE_DESTROY \
-var=tpu_type=$TPU_TYPE \
-var=num_tpu_pools=$NUM_TPU_POOLS \
-var=zone=$ZONE
```


### Removing or reconfiguring TPU node pools

If you want to remove or reconfigure TPU node pools but maintain all other configurations unchanged you can modify the input variables that control TPU node pool provisioning and reapply the Terraform configuration.

For example to remove TPU node pools while not in use, execute the following command.

```
export NUM_TPU_POOLS=0

terraform apply \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=force_destroy=$FORCE_DESTROY \
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
-var=num_tpu_pools=$NUM_TPU_POOLS \
-var=zone=$ZONE
```

To add them later on, set `tpu_machine_type`, `tpu_topology`, and `num_tpu_pools` to reflect the desired TPU configuration and re-apply Terraform.


### Installing JobSet CRD

Multislice examples use `JobSet` CRD which is not installed by default.

Get cluster credentials.

```
gcloud container clusters get-credentials $CLUSTER_NAME --region=$REGION
```

Install `JobSet`

```
JOBSET_API_VERSION="v0.2.3"

kubectl apply --server-side -f "https://github.com/kubernetes-sigs/jobset/releases/download/$JOBSET_API_VERSION/manifests.yaml"

```

Verify that the `JobSet` controller is running

```
kubectl get pods -n jobset-system

```

### Installing Kueue

We use [Kueue](https://kueue.sigs.k8s.io/) for training job scheduling and coordination.

```
KUEUE_API_VERSION=v0.4.2
kubectl apply -f "https://github.com/kubernetes-sigs/kueue/releases/download/$KUEUE_API_VERSION/manifests.yaml"

```

#### Configuring Kueue

Set the `namespace` field in  `kueue/local_queue.yaml` to your namespace

```
kubectl apply -k kueue
```

### Clean up

If you want to remove all the components provisioned in the environment you can execute the following command:

```
terraform destroy \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=force_destroy=$FORCE_DESTROY \
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
-var=num_tpu_pools=$NUM_TPU_POOLS \
-var=zone=$ZONE
```


## Running training workloads

This repo includes a number of examples of TPU training workloads in the `examples` folder. Refer to the README in this folder for detailed instructions.
