#  Running TPU training workloads on GKE

This reference guide compiles best practices, prescriptive guidance, and code samples for running large-scale machine learning training workloads with [TPU v4 and TPU v5e on Google Kubernetes Engine (GKE)](https://cloud.google.com/tpu/docs/tpus-in-gke).

The guide covers two main topics:
- **Configuring a GKE based environment for large scale training on Cloud TPUs**
  - This section describes how to configure a GKE cluster to optimize it for running large-scale machine learning training workloads on [Cloud TPUs](https://cloud.google.com/tpu).
- **Defining, Submitting, and Monitoring Training Jobs**
  - This section provides guidance on how to define, submit, and manage training jobs using the Kubernetes [JobSet](https://github.com/kubernetes-sigs/jobset) and [Kueue](https://github.com/kubernetes-sigs/kueue) APIs.

We also include Terraform configuration for provisioning the training environment and code samples for a variety of training workloads.



## Architecture of the training environment

The diagram below depicts a high-level architecture of the training environment.


![arch](/images/training-cluster.png)

The foundation of the environment is a regional, VPC-native GKE cluster. The cluster has two types of node pools: 
- A single node pool with CPU-only nodes and 
- Several [Multi-host TPU node pools](https://cloud.google.com/kubernetes-engine/docs/concepts/tpus)

This cluster topology supports running both [single-slice and multislice TPU](https://cloud.google.com/tpu/docs/multislice-introduction) training jobs.

Following are the components supporting the environment:

- [Cloud Storage](https://cloud.google.com/storage) buckets for saving training datasets and artifacts produced by training jobs (such as logs and checkpoints)
- [Cloud Artifact Registry](https://cloud.google.com/artifact-registry) for packaging and managing the training, data processing, and other components of a training workload as Docker container images.
- [Vertex AI TensorBoard](https://cloud.google.com/vertex-ai/docs/experiments/tensorboard-introduction) for tracking and visualizing training metrics.
- [Cloud Monitoring](https://cloud.google.com/monitoring) for collecting and analyzing non-functional performance metrics
- [Cloud Logging](https://cloud.google.com/logging) for managing logs produced by training workloads.
- Training workloads [impersonate an Identity and Access Management (IAM) service accounts](https://cloud.google.com/iam/docs/service-account-impersonation) to access Google Cloud services, such as Cloud Storage and Vertex AI TensorBoard.


## Training workload processing 

The following diagram illustrates the process of submitting and processing training workloads in the training environment.

![training workloads](/images/workload-processing.png)

In this guide we advocate using the [Kubernetes JobSet API](https://github.com/kubernetes-sigs/jobset) as the preferred method of coordinating large-scale distributed machine learning training workloads on Kubernetes. When combined with the [Kubernetes Kueue](https://github.com/kubernetes-sigs/kueue) job queuing API, it provides flexible and comprehensive training job orchestration.

The training environment's **Kueue** configuration  consists of a single [ClusterQueue](https://kueue.sigs.k8s.io/docs/concepts/cluster_queue/) and multiple [LocalQueues](https://kueue.sigs.k8s.io/docs/concepts/local_queue/). This topology provides basic multi-tenancy and supports managing and prioritizing jobs submitted by multiple teams.

All training workloads are represented as JobSet resources. A JobSet resource may contain multiple job types, such as a core distributed training job and an auxiliary job that manages TensorBoard logs and other artifacts generated by the training job.

JobSet workloads are submitted to a namespaced LocalQueue that points to a ClusterQueue. As illustrated in the diagram, in our reference implementation, there is a single cluster queue.

Kueue monitors when resources (such as TPU slices) required by a workload (JobSet) are available, and then decides when to admit the workload and how to allocate the workload's components to the cluster's node pools. 

For example, a training workload can contain two types of jobs:
- A multislice distributed training job
- A job that uploads TensorBoard logs generated by the training job to Vertex AI TensorBoard

When all the resources required by this workload become available, the training job's workers are started on the requested number of TPU slices. The TensorBoard uploader is started on one of the nodes in the CPU node pool.

If the compute resources required by other submitted workloads are not available, these workloads are queued and scheduled for admission based on the priorities that have been defined in the Kueue configuration.

To submit a JobSet-defined workload, you need to create a YAML JobSet resource definition. There are a few different ways to do this. In this guide, we demonstrate two approaches:
- Using [Kustomize](https://kustomize.io/), which helps you create YAML JobSet resource definitions directly.
- Using  [xpk](https://github.com/google/maxtext/tree/main/xpk), which provides an easy-to-use Python-based CLI.


## Provision infrastructure

The provisioning of the environment described in the previous section has been automated with [Terraform](https://cloud.google.com/docs/terraform) and [Cloud Build](https://cloud.google.com/build). The following are the tasks performed by the Terraform configuration:

- [ ] Creates a network and a subnet for a VPC-native GKE cluster.
- [ ] Creates a VPC-native cluster.
- [ ] Creates a node pool with nodes equipped with CPUs only.
- [ ] Creates a specified number of multi-host TPU node pools.
- [ ] Creates an IAM service account for Workload Identity and an IAM service account to be used as a custom node pool service account.
- [ ] Assigns a specified set of roles to these service accounts.
- [ ] Configures the cluster for Workload Identity.
- [ ] Creates a Google Cloud Storage bucket.
- [ ] Adds the service accounts to `roles/storage.legacyBucketReader` bucket level permissions.

> [!WARNING]
>  A few things to note:
>
>  1. You need to be a project owner to set up the environment.
>  2. Your project must have sufficient [quota to provision TPU resources](https://cloud.google.com/tpu/docs/quota). Else, you can [request for a higher quota limit](https://cloud.google.com/docs/quota/view-manage#requesting_higher_quota).


You can use [Cloud Shell](https://cloud.google.com/shell/docs/using-cloud-shell) to start and monitor the setup process. Click on the link below to navigate to Cloud Shell and clone the repo.

<a href="https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/jarokaz/tpu-gke-sandbox&cloudshell_git_branch=main&tutorial=README.md">
    <img alt="Open in Cloud Shell" src="http://gstatic.com/cloudssh/images/open-btn.png">
</a>

To set up the environment execute the following steps.

### Select a Google Cloud project

 - In the Google Cloud Console, on the project selector page, [select or create a Google Cloud project](https://console.cloud.google.com/projectselector2/home/dashboard?_ga=2.77230869.1295546877.1635788229-285875547.1607983197&_gac=1.82770276.1635972813.Cj0KCQjw5oiMBhDtARIsAJi0qk2ZfY-XhuwG8p2raIfWLnuYahsUElT08GH1-tZa28e230L3XSfYewYaAlEMEALw_wcB). 


- Clone the GitHub repo. Skip this step if you have launched through Cloud Shell link.

```bash
git clone https://github.com/jarokaz/tpu-gke-sandbox.git
```

### Configure environment

As mentioned earlier, environment provisioning is done using a Cloud Build job that runs Terraform manifests and environment setup steps. The Terraform configuration can be found in the [`env_setup/terraform`](env_setup/terraform) folder. The Terraform configuration supports a number of configurable inputs which are set using the included [`env_setup/vars.env`](env_setup/vars.env) file. Cloud Build provides Terraform the values set in this file to configure Terraform variables in [`env_setup/terraform/variables.tf`](env_setup/terraform/variables.tf). The configuration uses Google Cloud Storage as the backend for maintaining Terraform state.

> [!IMPORTANT] 
> To proceed, set the below environment variables in [`env_setup/vars.env`](tpu-gke-sandbox/env_setup/vars.env) to reflect your environment. By default, you will only need to provide your `PROJECT_ID`; replace "YOUR_PROJECT_ID" with the project ID of your Google Cloud project.

```bash
export PROJECT_ID=YOUR_PROJECT_ID
export REGION=us-central2
export ZONE=us-central2-b
export NETWORK_NAME=${PROJECT_ID}-network
export SUBNET_NAME=${PROJECT_ID}-subnet
export CLUSTER_NAME=gke-tpu-training-cluster
export NAMESPACE=tpu-training
export TPU_TYPE=v4-16
export NUM_TPU_POOLS=1
export NUM_OF_CHIPS=8

export TENSORBOARD_REGION=us-central1
export ARTIFACT_REGISTRY_NAME=gke-tpu-training
export ARTIFACT_REPOSITORY_BUCKET_NAME=${PROJECT_ID}-aiml-repository

export JOBSET_API_VERSION="v0.2.3"
export KUEUE_API_VERSION="v0.4.2"

export TF_STATE_BUCKET=${PROJECT_ID}-tf-state
export TF_STATE_PREFIX=gke-tpu-training-environment
```

- `PROJECT_ID` - your project ID
- `REGION` - the region for a GKE cluster network (default: `us-central2`)
- `ZONE` - the zone for your GKE cluster (default: `us-central2-b`)
- `NETWORK_NAME` - the name for the network 
- `SUBNET_NAME` - the name for the subnet
- `CLUSTER_NAME` - the name of your GKE cluster (default: `gke-tpu-training-cluster`)
- `NAMESPACE` - the kubernetes namespace for TPU workloads (default: `tpu-training`)
- `TPU_TYPE` - the TPU type for the Triton GPU node pool (default: `v4-16`)
- `NUM_TPU_POOLS` - the number of TPU slices to create (default: `1`)
- `NUM_OF_CHIPS` - Number of chips based on the [selected TPU type](https://cloud.google.com/tpu/docs/supported-tpu-configurations) and number of TPU pools
- `TENSORBOARD_REGION` - The region for a Vertex TensorBoard instance (default: `us-central1`)
- `ARTIFACT_REPOSITORY_BUCKET_NAME` - the name of the model artifacts repository Cloud Storage bucket
- `ARTIFACT_REGISTRY_NAME` - the name of Artifact Registry repository to manage docker images
- `JOBSET_API_VERSION` - the version of the (JobSet API)(https://github.com/kubernetes-sigs/jobset/releases) to download and setup
- `KUEUE_API_VERSION` - the version of the (Kueue API)(https://github.com/kubernetes-sigs/kueue/releases) to download and setup
- `TF_STATE_BUCKET` - the name of Cloud Storage bucket for Terraform to maintains configuration state
- `TF_STATE_PREFIX` - the object prefix for Terraform to maintains configuration state in Cloud Storage bucket


### Run environment provisioning job

Start provisioning by using [Cloud Build job](env_setup/cloudbuild.provision.yaml) to run Terraform and provision resources, installs the **JobSet** and **Kueue** APIs and configures Kueue resources and finalizes the setup. To start provisioning execute the following command:

```bash
export PROJECT_ID=YOUR_PROJECT_ID
./env_setup/build.sh
```

Navigate to the Cloud Build logs using the link displayed on Cloud Shell or go to the [Cloud Build page on the Cloud console](https://console.cloud.google.com/cloud-build). You should see similar page when the environment provision job is completed successfully:

![provision](/images/cloudbuild_provision.jpg)


#### Input variables in the Terraform configuration 

Note that we only set a subset of variables in [`env_setup/vars.env`](env_setup/vars.env) exposed by the Terraform configuration. For the other ones we use the defaults. If you want to change the default values of other variables you need to update the [`env_setup/cloudbuild.provision.yaml`](env_setup/cloudbuild.provision.yaml) file and the `gcloud builds submit` command in [`env_setup/build.sh`](env_setup/build.sh) file. 

The Terraform configuration supports the following input variables:

| Variable | Description | Default |
| -------- | ------------|---------|
| region | The compute region for the Cluster | NA|
| tensorboard_region | The compute region for Vertex AI TensorBoard  | NA|
| artifact_repository_bucket_name|The name of the GCS bucket|NA|
| zone | The zone for the TPU node pools. Make sure that the zone supports the required TPU resources| NA |
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
| tpu_type | The TPU slice type for TPU node pools. See below for more info | v4-16 |
| num_tpu_pools | The number of multi-host TPU node pools to provision | 1 |
| enable_tpu_autoscaling | Whether to enable outoscaling of TPU node pools | false |
| tpu_node_pool_name_prefix | A prefix that will be used to name TPU node pools. An index starting with 0 will be appended to the prefix to form a TPU node pool name | tpu-node-pool |
| multislice_group_name | A name that will be used to label a TPU node pools to support multislice jobs | multi-slice-group |

The `tpu_type` variable is a name of a TPU slice configuration as defined in the following table.

| TPU type name | Slice type | Slice topology | TPU VM type | Number of VMs in a slice | Number of chips in a VM |
| ------------- | -----------|----------------|-------------|--------------------------| ------------------------|
| v5litepod-16 | tpu-v5-lite-podslice | 4x4 | ct5lp-hightpu-4t | 4 | 4 |
| v5litepod-32 | tpu-v5-lite-podslice | 4x8 | ct5lp-hightpu-4t | 8 | 4 |
| v5litepod-64 | tpu-v5-lite-podslice | 8x8 | ct5lp-hightpu-4t | 16 | 4 |
| v5litepod-128 | tpu-v5-lite-podslice | 8x16 | ct5lp-hightpu-4t | 32 | 4 |
| v5litepod-256 | tpu-v5-lite-podslice | 26x16 | ct5lp-hightpu-4t | 64 | 4 |
| v4-8| tpu-v4-podslice | 2x2x1 | ct4p-hightpu-4t | 1 | 4 |
| v4-16| tpu-v4-podslice | 2x2x2 | ct4p-hightpu-4t | 2 | 4 |
| v4-32| tpu-v4-podslice | 2x2x4 | ct4p-hightpu-4t | 4 | 4 |
| v4-64| tpu-v4-podslice | 2x4x4 | ct4p-hightpu-4t | 8 | 4 |
| v4-128| tpu-v4-podslice | 4x4x4 | ct4p-hightpu-4t | 16 | 4 |
| v4-256| tpu-v4-podslice | 4x4x8 | ct4p-hightpu-4t | 32| 4 |
| v4-512| tpu-v4-podslice | 4x8x8 | ct4p-hightpu-4t | 64 | 4 |
| v4-1024| tpu-v4-podslice | 8x8x8 | ct4p-hightpu-4t | 128 | 4 |
| v4-1536| tpu-v4-podslice | 8x8x12 | ct4p-hightpu-4t | 192 | 4 |
| v4-2048| tpu-v4-podslice | 8x8x16 | ct4p-hightpu-4t | 256 | 4 |
| v4-4096| tpu-v4-podslice | 8x16x16 | ct4p-hightpu-4t | 512 | 4 |


## Training workloads examples

The [`examples`](examples/) folder contains code samples that demonstrate how to configure, submit and manage a number of different training workloads. Refer to the [README](examples/README.md) in this folder for detailed instructions.

### TODO: Examples navigation


## Cleanup Environment 

To destroy the environment and clean up all the provisioned resources, run the [Cloud Build job](env_setup/cloudbuild.destroy.yaml) that runs Terraform to clean up the resources. The job refers to the environment variables in [`env_setup/vars.env`](env_setup/vars.env) that was used for provisioning the environment. To start cleaning up the provisioned resources execute the following command:

```bash
./env_setup/destroy.sh
```

You should see similar page when the environment cleanup job is completed successfully:

![destroy](/images/cloudbuild_destroy.jpg)