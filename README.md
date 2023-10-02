#  Running TPU training workloads on GKE

This repository contains prescriptive guidance and code samples for running large-scale TPU v4 and TPU v5e training workloads on Google Kubernetes Engine (GKE).


## Environment setup

This section describes the steps to set up the Google Cloud environment needed to run the code samples in this repository.
A high-level diagram of the environment is shown below.

![arch](/images/tpu-training.png)

The environment is based on a zonal, VPC-native GKE cluster with multiple node pools. There is a single node pool with CPU-only nodes, as well as multiple multi-host TPU slice node pools.

TPU node pools are used to run single-slice or multi-slice TPU training jobs. If your environment has been provisioned with a single TPU node pool you can only run single-slice jobs. If you have multiple TPU node pools you can run multiple single-slice jobs simultaneously or a single multi-slice job that uses multiple node pools.

The CPU node pool is used to run auxiliary workloads, such as data preprocessing jobs or Tensorboard logs management jobs.

Training datasets and artifacts generated by training jobs (such as logs and checkpoints) are saved in Google Cloud Storage.

Training, data processing, and other workloads are packaged as Docker container images and managed in Google Cloud Container Registry.

Vertex AI TensorBoard is used to track and visualize training metrics.

The GKE cluster is configured with Workload Identity. Training and other jobs impersonate an Identity and Access Management service account to access Google Cloud services, including Google Cloud Storage and Tensorboard.

### Provision the environment

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
aiplatform.googleapis.com 

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
| tpu_sa_roles | The roles to assign to the service account | roles/storage.objectAdmin |
| gke_sa_name | The name of the custom service account for node pools | gke-sa |
| gke_sa_roles | The roles to assigne to the custom service account for node pools | roles/storage.objectAdmin |
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
TF_STATE_PREFIX=gke-tpu-training

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
export TPU_TOPOLOGY=2x2x2
export TPU_NUM_NODES=2
export NUM_TPU_POOLS=2


terraform apply \
-var=project_id=$PROJECT_ID \
-var=region=$REGION \
-var=network_name=$NETWORK_NAME \
-var=subnet_name=$SUBNET_NAME \
-var=cluster_name=$CLUSTER_NAME \
-var=artifact_repository_bucket_name=$ARTIFACT_REPOSITORY_BUCKET_NAME \
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
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
gcloud container clusters get-credentials $CLUSTER_NAME
```

Install `JobSet`

```
kubectl apply --server-side -f https://github.com/kubernetes-sigs/jobset/releases/download/v0.2.1/manifests.yaml

```

Verify that the `JobSet` controller is running

```
kubectl get pods -n jobset-system
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
-var=tpu_machine_type=$TPU_MACHINE_TYPE \
-var=tpu_topology=$TPU_TOPOLOGY \
-var=tpu_num_nodes=$TPU_NUM_NODES \
-var=num_tpu_pools=$NUM_TPU_POOLS \
-var=zone=$ZONE
```


## Running training workloads

This repo includes a number of examples of TPU training workloads in the `examples` folder. Refer to the README in this folder for detailed instructions.
