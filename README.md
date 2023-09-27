#  Running TPU training workloads on GKE

This repository compiles prescriptive guidance and code samples for running large scale TPU v4 and TPU v5e training workloads in Google Kubernetes Engine (GKE).

## Environment setup

This section outlines the steps to configure Google Cloud environment required to run the code samples in this repo:

![arch](/images/tpu-training.png)

### Environment Requirements

- All services should be provisioned in the same project and the same compute region
- NVIDIA Triton Inference Server is deployed to a dedicated GPU node pool on a GKE cluster
- Anthos Service Mesh is used to manage, observe and secure communication to Triton Inference Server
- All external traffic to Triton is routed through Istio Ingress Gateway, enabling fine-grained traffic management and progressive deployments
- Managed Prometheus is used to monitor the Triton Inference Server pods
- A Cloud Storage bucket located in the same region as the GKE cluster for managing model artifacts as in the model repository hosted on Triton server.
- Docker repository in Google Artifact Registry to manage images required to run the steps of the workflow

Google Cloud Build jobs with Terraform will be used to provision the environment. The setup builds the environment as follows:

- [ ] Enable APIs
- [ ] Run Terraform to provision the required resources
- [ ] Deploy Ingress Gateway
- [ ] Deploy NVIDIA GPU drivers
- [ ] Configure and deploy Triton Inference Server
- [ ] Run health check to validate the Triton deployment

A few things to note:

1. You need to be a project owner to set up the environment.
2. You will be using [Cloud Shell](https://cloud.google.com/shell/docs/using-cloud-shell) to start and monitor the setup process.

Click on the link below to navigate to Cloud Shell and clone the repo.

<a href="https://console.cloud.google.com/cloudshell/open?git_repo=https://github.com/jarokaz/triton-on-gke-sandbox&cloudshell_git_branch=main&tutorial=README.md">
    <img alt="Open in Cloud Shell" src="http://gstatic.com/cloudssh/images/open-btn.png">
</a>

To set up the environment execute the following steps.

## Provision infrastructure

### Select a Google Cloud project

In the Google Cloud Console, on the project selector page, [select or create a Google Cloud project](https://console.cloud.google.com/projectselector2/home/dashboard?_ga=2.77230869.1295546877.1635788229-285875547.1607983197&_gac=1.82770276.1635972813.Cj0KCQjw5oiMBhDtARIsAJi0qk2ZfY-XhuwG8p2raIfWLnuYahsUElT08GH1-tZa28e230L3XSfYewYaAlEMEALw_wcB). 

**NOTE: You need to be a project owner in order to set up the environment**

### Enable the required services

- Clone the GitHub repo. Skip this step if you have launched through Cloud Shell link.

```bash
git clone https://github.com/jarokaz/triton-on-gke-sandbox
```

- Granting permissions to your Cloud Build service account

```bash
export PROJECT_ID=<YOUR_PROJECT_ID>
gcloud config set project $PROJECT_ID
```

- Retrieve the email for your project's Cloud Build service account:
```bash
CLOUDBUILD_SA="$(gcloud projects describe $PROJECT_ID \
    --format 'value(projectNumber)')@cloudbuild.gserviceaccount.com"
```

- Grant the required access to your Cloud Build service account:
```bash
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member serviceAccount:$CLOUDBUILD_SA --role roles/owner
```

### Run environment provisioning job

Environment provisioning is done using a Cloud Build job that runs Terraform scripts and environment setup steps. The Terraform configuration supports a number of configurable inputs. Refer to the `/env-setup/variables.tf` for the full list and the default settings. You need to set a small set of the required parameters. Set the below environment variables to reflect your environment.

- `PROJECT_ID` - your project ID
- `REGION` - the region for a GKE cluster network
- `ZONE` - the zone for your GKE cluster
- `NETWORK_NAME` - the name for the network
- `SUBNET_NAME` - the name for the subnet
- `GCS_BUCKET_NAME` - the name of the model repository GCS bucket
- `GKE_CLUSTER_NAME` - the name of your cluster
- `TRITON_SA_NAME` - the name for the service account that will be used as the Triton's workload identity
- `TRITON_NAMESAPCE` - the name of a namespace where the solution's components are deployed
- `MACHINE_TYPE` - The machine type for the Triton GPU node pool (default: `n1-standard-4`)
- `ACCELERATOR_TYPE` - Type of accelerator (GPUs) for the Triton node pool (default: `nvidia-tesla-t4`)
- `ACCELERATOR_COUNT` - Number of accelerator(s) (GPUs) for the Triton node pool (default: `1`)


```bash
export PROJECT_ID=jk-mlops-dev
export REGION=us-central1
export ZONE=us-central1-a
export NETWORK_NAME=jk-gke-network
export SUBNET_NAME=jk-gke-subnet
export GCS_BUCKET_NAME=jk-triton-repository
export GKE_CLUSTER_NAME=jk-ft-gke
export TRITON_SA_NAME=triton-sa
export TRITON_NAMESPACE=triton
export MACHINE_TYPE=n1-standard-4
export ACCELERATOR_TYPE=nvidia-tesla-t4
export ACCELERATOR_COUNT=1
```

By default, the Terraform configuration uses Cloud Storage for the Terraform state. Set the following environment variables to the GCS location for the state.

```bash
export TF_STATE_BUCKET=jk-mlops-dev-tf-state
export TF_STATE_PREFIX=jax-to-ft-demo 
```

Create Cloud Storage bucket to save Terraform State

```bash
gcloud storage buckets create gs://$TF_STATE_BUCKET --location=$REGION
```

Start provisioning by using Cloud Build job to run Terraform and provision resources, deploy Triton Inference server and finalize the setup.

```bash
gcloud builds submit \
  --region $REGION \
  --config cloudbuild.provision.yaml \
  --substitutions _TF_STATE_BUCKET=$TF_STATE_BUCKET,_TF_STATE_PREFIX=$TF_STATE_PREFIX,_REGION=$REGION,_ZONE=$ZONE,_NETWORK_NAME=$NETWORK_NAME,_SUBNET_NAME=$SUBNET_NAME,_GCS_BUCKET_NAME=$GCS_BUCKET_NAME,_GKE_CLUSTER_NAME=$GKE_CLUSTER_NAME,_TRITON_SA_NAME=$TRITON_SA_NAME,_TRITON_NAMESPACE=$TRITON_NAMESPACE,_MACHINE_TYPE=$MACHINE_TYPE,_ACCELERATOR_TYPE=$ACCELERATOR_TYPE,_ACCELERATOR_COUNT=$ACCELERATOR_COUNT \
  --timeout "2h" \
  --machine-type=e2-highcpu-32 \
  --quiet
```

Navigate to the Cloud Build logs using the link displayed on Cloud Shell or go to the [Cloud Build page on the Cloud console](https://console.cloud.google.com/cloud-build?_ga=2.109004802.1605716039.1675990133-1112324367.1675987342). You should see similar page when the environment provision job is completed successfully:

![arch](/images/build-provision.png)

## Invoking sample model on Triton

You can now invoke the sample model. Use the NVIDIA Triton Inference Server SDK container image.

Start by configuring access to the cluster.

```bash
gcloud container clusters get-credentials ${GKE_CLUSTER_NAME} --project ${PROJECT_ID} --zone ${ZONE} 
kubectl create clusterrolebinding cluster-admin-binding --clusterrole cluster-admin --user "$(gcloud config get-value account)"
```

Get gateway IP address to access Triton server

```
ISTIO_GATEWAY_IP_ADDRESS=$(kubectl get services -n $TRITON_NAMESPACE \
   -o=jsonpath='{.items[?(@.metadata.name=="istio-ingressgateway")].status.loadBalancer.ingress[0].ip}')
```

Run Triton server locally

```
docker run -it --rm --net=host  \
-e ISTIO_GATEWAY_IP_ADDRESS=${ISTIO_GATEWAY_IP_ADDRESS} \
nvcr.io/nvidia/tritonserver:22.01-py3-sdk
```

After the container starts execute the following command from the containers command line:

```
/workspace/install/bin/image_client -u  $ISTIO_GATEWAY_IP_ADDRESS -m densenet_onnx -c 3 -s INCEPTION /workspace/images/mug.jpg
```

## Clean up


To clean up the environment run the Cloud Build job that runs Terraform to clean up the resources.


```bash
gcloud builds submit \
  --region $REGION \
  --config cloudbuild.destroy.yaml \
  --substitutions _TF_STATE_BUCKET=$TF_STATE_BUCKET,_TF_STATE_PREFIX=$TF_STATE_PREFIX,_REGION=$REGION,_ZONE=$ZONE,_NETWORK_NAME=$NETWORK_NAME,_SUBNET_NAME=$SUBNET_NAME,_GCS_BUCKET_NAME=$GCS_BUCKET_NAME,_GKE_CLUSTER_NAME=$GKE_CLUSTER_NAME,_TRITON_SA_NAME=$TRITON_SA_NAME,_TRITON_NAMESPACE=$TRITON_NAMESPACE \
  --timeout "2h" \
  --machine-type=e2-highcpu-32 \
  --quiet
```