# Running TPU workloads with xpk

**xpk** [(Accelerated Processing Kit, pronounced x-p-k,)](https://github.com/google/maxtext/tree/main/xpk) i is a Python based tool to help Cloud developers to orchestrate training jobs on accelerators such as TPUs and GPUs on GKE. 

**xpk** provides a simple command-line interface for managing GKE clusters and submitting training workloads that are encapsulated as JobSet configurations. In this reference guide, we do not use cluster management capabilities. We use **xpk** to configure and submit training workloads to the GKE-based training environment provisioned during the setup.


**xpk** uses [JobSet](https://github.com/kubernetes-sigs/jobset) and [Kueue](https://kueue.sigs.k8s.io/docs/overview/) for running training workloads. It assumes that there is a LocalQueue named `multislice-queue` in the `default` namespace and submits workloads this queue. If you used the `default` namespace when provisioning your environment you can use it as is. If you used a different namespace, create a local queue using the following command.

```
cat <<EOF >./local-queue.yaml
apiVersion: kueue.x-k8s.io/v1beta1
kind: LocalQueue
metadata:
  namespace: default 
  name: multislice-queue
spec:
  clusterQueue: cluster-queue 
EOF

kubectl apply -f local-queue.yaml
```

**xpk** uses a simplified naming convention for specifying TPU slice configuration. When submitting workloads make sure to use an xpk name that maps to TPU node pools provisioned in your environment.

|xpk name | slice type| topology|
|---------|-----------|---------|
|v4-16|tpu-v4-podslice|2x2x2|
|v4-32|tpu-v4-podslice|2x2x4|
|v4-64|tpu-v4-podslice|2x4x4|
|v4-128|tpu-v4-podslice|4x4x4|
|v4-256|tpu-v4-podslice|4x4x8|
|v4-512|tpu-v4-podslice|4x8x8|
|v4-1024|tpu-v4-podslice|8x8x8|
|v4-1536|tpu-v4-podslice|8x8x12|
|v4-2048|tpu-v4-podslice|8x8x16|
|v4-4096|tpu-v4-podslice|8x16x16|
|v5litepod-16|tpu-v5-lite-podslice|4x4|
|v5litepod-32|tpu-v5-lite-podslice|4x8|
|v5litepod-64|tpu-v5-lite-podslice|8x8|
|v5litepod-128|tpu-v5-lite-podslice|8x16|
|v5litepod-256|tpu-v5-lite-podslice|16x16|


Refer to [xpk documentation](https://github.com/google/maxtext/tree/main/xpk) for detailed information on how to create, delete, and list workloads.

## Installing **xpk**

**xpk** is implemented as a [Python script](https://github.com/google/maxtext/blob/main/xpk/xpk.py) and currently distributed through the MaxText repo. To access **xpk** you can either clone the whole repo or download the `xpk.py` module.

## **xpk** and container images

By default, when xpk prepares a workload it layers the local directory (--script-dir) into the base docker image, uploads the updated image to your project's Container Registry, and references the uploaded image in the JobSet template. You can specify the base docker image through the `--base-docker-image` parameter. If you do not specify the base image, xpk attempt to create one using the default settings embedded in `xpk.py` and a local installation of **docker**.

If you don't want this layering behavior, you can specify the image to use through the `--docker-image` parameter.

In our examples, we will set the `--base-docker-image` to the MaxText training image. Make sure that you have a working installation of **docker** before running the below examples.


## Running **xpk** smoke test

To verify that you can successfuly run **xpk** workloads on your cluster execute the following command. Make sure to update the below variables to reflect your environment. Use the MaxText training image URI to set the `CONTAINER_IMAGE` variable.

```
CLUSTER_NAME=jk-tpu-training-cluster
TPU_TYPE=v4-32
ZONE=us-central2-b
MAXTEXT_TRAINING_CONTAINER_IMAGE=gcr.io/jk-mlops-dev/maxtext-runner
```

Submit the smoke test workload.

```
WORKLOAD_ID=xpk-test-workload-1

python3 xpk.py workload create \
--workload $WORKLOAD_ID \
--base-docker-image $MAXTEXT_TRAINING_CONTAINER_IMAGE \
--cluster $CLUSTER_NAME \
--tpu-type=$TPU_TYPE \
--zone=$ZONE \
--command "echo goodbye" 
```

To delete the smoke test workload execute:

```
python3 xpk.py workload delete \
--workload $WORKLOAD_ID \
--cluster $CLUSTER_NAME
```

## Running sharding experiments

In this section we provide instructions for running parallelism experiments similar to the `tpu_hello_world` examples in the `jobset` section.

### Single slice ICI FSDP

Create a workload script.

```
cat <<EOF >./ici-fsdp.sh
#!/bin/bash
set -e

python3 pedagogical_examples/shardings.py --ici_fsdp_parallelism=16 --batch_size=131072 --embedding_dimension=2048

EOF
```

Submit a workload.

```
WORKLOAD_ID=xpk-hello-world-single-slice-1
NUM_SLICES=1


python3 xpk.py workload create \
--workload $WORKLOAD_ID \
--base-docker-image $MAXTEXT_TRAINING_CONTAINER_IMAGE \
--cluster $CLUSTER_NAME \
--tpu-type=$TPU_TYPE \
--zone=$ZONE \
--num-slices=$NUM_SLICES \
--command "bash ici-fsdp.sh" 
```


If you wanted to delete the workload.

```
python3 xpk.py workload delete \
--workload $WORKLOAD_ID \
--cluster $CLUSTER_NAME
```

### Multislice DCN DP and ICI FSDP

Create a workload script.

```
cat <<EOF >./dcn-dp-ici-fsdp.sh
#!/bin/bash
set -e

python3 pedagogical_examples/shardings.py --dcn_data_parallelism=2 --ici_fsdp_parallelism=16 --batch_size=131072 --embedding_dimension=2048

EOF
```

Submit a workload.

```
WORKLOAD_ID=xpk-hello-world-multi-slice-1
NUM_SLICES=2


python3 xpk.py workload create \
--workload $WORKLOAD_ID \
--base-docker-image $MAXTEXT_TRAINING_CONTAINER_IMAGE \
--cluster $CLUSTER_NAME \
--tpu-type=$TPU_TYPE \
--zone=$ZONE \
--num-slices=$NUM_SLICES \
--command "bash dcn-dp-ici-fsdp.sh" 
```


If you wanted to delete the workload.

```
python3 xpk.py workload delete \
--workload $WORKLOAD_ID \
--cluster $CLUSTER_NAME
```

## Running MaxText pretraining workloads

In this section we provide instructions for running MaxText pretraining for a 6.5B parameters model using the same configuration settings as in the `examples\jobset\maxtext`.

### Single slice pretraining

Create a workload script. Make sure to modify the settings to reflect your environment

```
cat <<EOF >./single-slice-6b.sh
#!/bin/bash
set -e

export LIBTPU_INIT_ARGS="--xla_enable_async_all_gather=true TPU_MEGACORE=MEGACORE_DENSE"

python3 MaxText/train.py MaxText/configs/base.yml \
run_name=single-slice-6b-101 \
dataset_path=gs://jk-gke-aiml-repository/datasets \
base_output_directory=gs://jk-gke-aiml-repository/runs \
steps=200 log_period=50 save_period=100 \
per_device_batch_size=16 \
dcn_data_parallelism=1 ici_fsdp_parallelism=16 \
remat_policy=full \
base_emb_dim=4096 base_num_heads=16 base_mlp_dim=16384 head_dim=256 base_num_decoder_layers=32

EOF
```

Submit a workload.

```
CLUSTER_NAME=jk-tpu-training-cluster
TPU_TYPE=v4-32
ZONE=us-central2-b
MAXTEXT_TRAINING_CONTAINER_IMAGE=gcr.io/jk-mlops-dev/maxtext-runner

WORKLOAD_ID=single-slice-6b-101
NUM_SLICES=1

python3 xpk.py workload create \
--workload $WORKLOAD_ID \
--base-docker-image $MAXTEXT_TRAINING_CONTAINER_IMAGE \
--cluster $CLUSTER_NAME \
--tpu-type=$TPU_TYPE \
--zone=$ZONE \
--num-slices=$NUM_SLICES \
--command "bash single-slice-6b.sh"
```


To delete the workload.

```
python3 xpk.py workload delete \
--workload $WORKLOAD_ID \
--cluster $CLUSTER_NAME
```

### Multislice pretraining

Create a workload script. Make sure to modify the settings to reflect your environment

```
cat <<EOF >./multi-slice-6b.sh
#!/bin/bash
set -e

export LIBTPU_INIT_ARGS="--xla_enable_async_all_gather=true TPU_MEGACORE=MEGACORE_DENSE"

python3 MaxText/train.py MaxText/configs/base.yml \
run_name=multi-slice-6b-501 \
dataset_path=gs://jk-gke-aiml-repository/datasets \
base_output_directory=gs://jk-gke-aiml-repository/runs \
steps=200 log_period=50 save_period=100 \
per_device_batch_size=16 \
dcn_data_parallelism=1 ici_fsdp_parallelism=16 \
remat_policy=full \
base_emb_dim=4096 base_num_heads=16 base_mlp_dim=16384 head_dim=256 base_num_decoder_layers=32

EOF
```

Submit a workload.

```
CLUSTER_NAME=jk-tpu-training-cluster
TPU_TYPE=v4-32
ZONE=us-central2-b
MAXTEXT_TRAINING_CONTAINER_IMAGE=gcr.io/jk-mlops-dev/maxtext-runner

WORKLOAD_ID=multi-slice-6b-501
NUM_SLICES=1

python3 xpk.py workload create \
--workload $WORKLOAD_ID \
--base-docker-image $MAXTEXT_TRAINING_CONTAINER_IMAGE \
--cluster $CLUSTER_NAME \
--tpu-type=$TPU_TYPE \
--zone=$ZONE \
--num-slices=$NUM_SLICES \
--command "bash multi-slice-6b.sh"
```

To delete the workload.

```
python3 xpk.py workload delete \
--workload $WORKLOAD_ID \
--cluster $CLUSTER_NAME
```


