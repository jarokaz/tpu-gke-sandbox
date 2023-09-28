# TPU training workloads examples

This folder contains examples of how to configure and run TPU training workloads using the following methods:
- Using a Kubernetes **Job** to run single-slice TPU training jobs
- Using a Kubernetes **JobSet** to run multi-slice TPU training jobs

To simplify the configuration of **Job** and **JobSet** resources, we use Kustomize. The `base_single_slice_job_spec` folder contains base configurations for a single-slice job. Specific single-slice job examples are Kustomize **overlays** using this **base**. 

For example, the `maxtext_single_slice` contains patches to adapt the base Job configuration to run pretraining of the *Maxtext* model. Similarly, the `base_multi_slice_job_spec` contains base configurations for multi-slice JobSet based training jobs.

Before running any examples, update the `namespace` field in `kustomization.yaml` in both `base_single_slice_job_spec` and `base_multi_slice_job_spec` to match the namespace for running TPU jobs configured in your environment. This is required to make sure that the service account created in this namespace is used for Workload Identity.


## Example 1 - Running single slice pretraining of Maxtext LLM

The sample demonstrates how to configure and run a job that pretrains Maxtext LLM using the C4 dataset.

This sample is located in the `maxtext_single_slice` folder. Make sure to execute any commands in the following steps from this folder.

### Download the C4 dataset

Before starting a training job you need to download the C4 dataset to a GCS location in your environments GCS bucket. 

```
PROJECT_ID=jk-mlops-dev
GCS_BUCKET=gs://jk-gke-aiml-repository
DATASET_LOCATION="$GCS_BUCKET/datasets"

gsutil -u $PROJECT_ID -m cp gs://allennlp-tensorflow-datasets/c4/en/3.0.1/* $DATASET_LOCATION

```

### Build the training image

The `build.yaml` file is a **Cloud Build** configuration that automates a process of packaging the Maxtext code base into a docker container image and pushing it to your project's **Container Registry**


```
CLOUD_BUILD_REGION=us-central1
MAXTEXT_IMAGE_NAME=maxtext-runner-image

gcloud builds submit \
--project $PROJECT_ID \
--region $CLOUD_BUILD_REGION \
--substitutions _MAXTEXT_IMAGE_NAME=$MAXTEXT_IMAGE_NAME \
--config build.yaml \
--machine-type=e2-highcpu-32
```

