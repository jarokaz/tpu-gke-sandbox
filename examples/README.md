# TPU training workloads examples

This folder contains examples of how to configure and run TPU training jobs using the following methods:
- Using the Kubernetes **Job** resource to run single-slice TPU training jobs
- Using the Kubernetes **JobSet** resource to run multi-slice TPU training jobs

To simplify the configuration of **Job** and **JobSet** resources, we use [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/). The `base_single_slice` folder contains base configurations for  single-slice jobs and the `base_multi_slice` folder base configurations for multi-slice jobs.  Specific job examples are Kustomize [overlays](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays) using these [bases](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays). 

For example, the `maxtext/single_slice` folder contains patches to adapt the base **Job** configuration in `base_single_slice`  to run pretraining of [Maxtext LLM](https://github.com/google/maxtext). 

Before running any examples, update the `namespace` field in `kustomization.yaml` in both `base_single_slice_job_spec` and `base_multi_slice_job_spec` to match the namespace for running TPU jobs configured in your environment. 

Refer to a README file in an example subfolder for the detailed instructions on how to run a given sample.

## Example 1 - Running single slice pretraining of Maxtext LLM

The sample demonstrates how to configure and run a job that pretrains [1B parameter Maxtext LLM](https://github.com/google/maxtext) using the [C4 dataset](https://www.tensorflow.org/datasets/catalog/c4).

This sample is located in the `maxtext` folder. Make sure to execute all commands  from this folder.

### Get cluster credentials

If you have not set cluster credentials before do it now.

```
CLUSTER_NAME=jk-tpu-training-cluster

gcloud container clusters get-credentials $CLUSTER_NAME
```

### Download the C4 dataset

Before starting a training run you need to download the C4 dataset to a GCS location in your environment's GCS bucket. 

```
PROJECT_ID=jk-mlops-dev
GCS_BUCKET=gs://jk-gke-aiml-repository
DATASET_LOCATION="$GCS_BUCKET/datasets/c4/en/3.0.1"

gsutil -u $PROJECT_ID -m cp gs://allennlp-tensorflow-datasets/c4/en/3.0.1/* $DATASET_LOCATION

```

### Build the training image

The `build.yaml` file is a **Cloud Build** configuration that automates a process of packaging the Maxtext code base into a docker container image and pushing it to your project's **Container Registry**





### Run a training job


TBD


## Example 2 - Running multi slice pretraining of Maxtext LLM

The sample demonstrates how to configure and run a job that pretrains [xB parameter Maxtext LLM](https://github.com/google/maxtext)  [Cloud TPU Multislice](https://cloud.google.com/blog/products/compute/using-cloud-tpu-multislice-to-scale-ai-workloads).

This sample is located in the `maxtext_multislice` folder. Make sure to execute all commands  from this folder.

### Download the dataset

Follow the instructions in Example 1

### Build the training image

Follow the instruction in Example 1

### Run a training job


Modify the `configs/jobset-spec-patch.yaml` file to reflect your environment. At minimum, modify the followining fields:
- Set the `metadata.name` field with to a unique job name. Although not mandatory, using a unique name for each job helps with managing multiple Job resources
- Update the `spec.template.spec.containers[name=tpu-job].image` field with your training image name
- Update the Maxtext trainer parameters defined in the `spec.template.spec.containers[name=tpu-job].command` field. For the detailed information on how to configure Maxtext training runs refer to [Maxtext github repo](https://github.com/google/maxtext/tree/main). At minimum, set the following parameters:
  - `run_name`. This is an identifier of your run. It is used to locate and store artifacts (including checkpoints) generated during training. They will be stored in the `run_name` folder in the `base_output_directory` path (see below). If there is an existing checkpoint in this location that checkpoint will auto-resume.    
  - `base_output_directory`. This a base GCS path for storing artifacts generated during runs.
  - `dataset_path`. This is the GCS location of the C4 dataset. This should be a GCS URI up to but not including the `c4` folder.
  - `steps`. The number of steps for this training run. If you do not set it the default (as defined in `MaxText/configs/base.yml`) is 150,000.
  - `ici_fsdp_parallelism`. This parameter controls the ICI Fully Sharded Data Parallelism (FSDP) sharding strategy. For this sample it is recommended to set it to a number of chips in a slice.
  - `dcn_data_parallelism`. This parameter controls the DCN Data Parallelism (DP) sharding strategy. For this sample it is recommended to set it to a number of slices.
  - The default configuration in this sample trains a xB parameter model with 16 decoder layers, 8 attention heads per layer, and 2560 model dimension. If you would like train a different model archicture adjust the following parameters: `base_emb_dim, base_num_heads, base_mlp_dim, base_num_decoder_layers, head_dim`

After updating the `configs/job-spec-patch.yaml` you can submit the job using the following command:

```
kubectl apply -k configs
```

You can monitor the job by retrieving logs generated by any worker.

First, list all pods started by the job

```
kubectl get pods -n <YOUR TPU TRAINING NAMESPACE>
```

Pick  any pod in your job and copy its ID. Retrieve the logs for this pod.

```
kubectl logs <YOUR POD ID> -n <YOUR TPU TRAINING NAMESPACE>
```

You can also monitor the job using GCP Console.

#### Monitoring training metrics using Vertex AI Tensorboard

TBD






