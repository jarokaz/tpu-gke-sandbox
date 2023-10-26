# Configuring and running JobSet workloads with Kustomize


The examples in this folder show how to configure and run JobSet workloads using Kustomize. The `base_jobset` folder contains the base JobSet configuration that is used in overlays in the `tpu_hello_world` and `maxtext` folders.
Before running the examples, modify the `base_jobset\jobset.yaml` file to reflect the topology of TPU slices provisioned in your environment. For example, if you provisioned `v4-64` based node pools, update the node selector settings in  `spec.replicatedJobs.template.spec.template.spec.nodeSelector` with `tpu-v4-podslice` and `2x4x4` values and the `parallelism` and `completions` fields in the `spec.replicatedJobs.template.spec` with 4 - a v4-64 slice comprises 4 TPU VMs.

In addition, you need to install Kustomize. Please follow the instructions in the [Kustomize documentation](https://kubectl.docs.kubernetes.io/installation/kustomize/).


## TPU Hello World examples

In the `tpu_hello_world` folder you will find examples of experimenting with different data and model parallelism strategies. The examples use the `shardings.py` script from MaxText that is designed to make experimentation with different parallelism options easy for both single slice and multislice settings. For more information about parallelism strategies and TPU Multislice refer to the [Cloud TPU Multislice Overview](https://cloud.google.com/tpu/docs/multislice-introduction) article.

The `tpu_hello_world\single_slice` folder contains the example configuration of a single slice workload configured for  Interchip Interconnect (ICI) sharding using Fully Sharded Data Parallelism (FSDP). The `tpu_hello_world\multi-slice` is a configuration for a multi-slice workload with data parallelism (DP) over data-center network (DCN) connections and FSDP over ICI.

To adapt the samples to your environment update the `namespace` and `images` fields in the `kustomization.yaml` files to reflect your environment. Set the `namespace` field to a Kubernetes namespace created during setup. As your recall, the Kueue LocalQueue used to admit workloads has been provisioned in this namespace. Update the `newName` property of the `images` field with the name of MaxText training container image build in the previous steps.

To run a single slice example execute the following command from the `tpu_hello_world` folder:

```
kubectl apply -k single_slice
```

To run a Multislice sample execute:

```
kubectl apply -k multi_slice
```

Note that the multi-slice example is configured to run on two slices so you need at least two multi-host TPU node pools in your environment to execute it successfully.

You can review execution logs using [GKE Console](https://console.cloud.google.com/kubernetes/workload/overview) or from the command line using `kubectl`.

To get the Kueue workloads:

```
kubectl get workloads -n <YOUR NAMESPACE>
```

To get the JobSets:

```
kubectl get jobsets -n <YOUR NAMESPACE>
```

To get pods in your namespace, including pods started by your workload:

```
kubectl get pods -n <YOUR NAMESPACE>
```

Note, that if your workload failed the above command will not return the workload's pods as the JobSet operator cleans up all failed jobs.

If you want to review logs from the failed workload use [GKE Console](https://console.cloud.google.com/kubernetes/workload/overview).

To display logs for a pod:

```
kubectl logs <YOUR POD>
```

To remove your workload and all resources that it created execute:

```
kubectl delete -k single_slice
```

or

```
kubectl delete -k multi_slice
```

## MaxText pretraining examples

The `maxtext` folder contains examples of pretraining a MaxText 6.5 billion parameters model on the C4 dataset.

The `maxtext/base_maxtext` folder contains the base configuration of the JobSet workload. If you review the `maxtext\base_maxtext\jobset-spec-patch.yaml` you will notice that a JobSet resource is configured with two job templates. One (named `slice`) starts the MaxText trainer. The other (named `tensorboard`) starts the TensorBoard uploader. The runtime parameters to the MaxText trainer and the TensorBoard uploader are passed through environment variables that are set through the `maxtext-parameters` ConfigMap.

The `single-slice-6B` and `multi-slice-6B` folders contain the Kustomize overlays that customize the base MaxText JobSet configuration for running a single slice and multislice training workloads respectively.

To run the samples in your environment modify the `single-slice-6B\kustomization.yaml` and `multi-slice-6B\kustomization.yaml` as follows:

- Update the `namespace` and `images` fields as described in the `tpu_hello_world` section
- Update the `nameSuffix` field with a unique identifier of your workload. If you try to submit the workload using the same identifier as in any of the previous workloads you will receive an error.
- Update the values in the `configMapGenerator` 
  - REPLICAS - The number of TPU slices to use for the job. If set to a number higher than 1 a multi-slice job will be started
  - RUN_NAME - The MaxText run name. MaxText will use this value to name the folders for checkpoints and TensorBoard logs - see BASE_OUTPUT_DIRECTORY. If you want to restart from a previously set checkpoint set this to the run name used for the previous run. Although not required it may be convenient to use the same name as the `nameSuffix`
  - BASE_OUTPUT_DIRECTORY - The base Cloud Storage location for checkpoints and logs.
  - DATASET_PATH - The base Cloud Storage location for the C4 dataset. Do not include the `c4` folder name. E.g. if the `c4` datasaet was copied to `gs:\\bucket_name\datasets` set the DATASET_PATH to this URI.
  - TENSORBOARD_NAME - The full name of the TensorBoard instance you want to use for tracking. In the format `projects\YOUR_PROJECT_NUMBER\locations\YOUR_LOCATON\tensorboard\YOUR_TENSORBOARD_ID`
  - ARGS - Any additional parameters you want to pass to the MaxText trainer. Refer to the below notes and the MaxText documentation for more info
  - LIBTPU_INIT_ARGS - LIBTPU_INIT_ARGS is an environmental variable that controls `libtpu` including XLA compiler. Refer to MaxText documentation for more info.


The MaxText trainer - `MaxText/train.py` accepts a number of command line parameters that define a training regimen and model architecture. The required parameters are `run_name`, `base_output_directory`, and `dataset_path`. Other parameters are optional with default values set in the [MaxText config file](https://github.com/google/maxtext/blob/main/MaxText/configs/base.yml). 

In our examples, the required parameters are set through the `RUN_NAME`, `BASE_OUTPUT_DIRECTORY`, and `DATASET_PATH` fields and the optional ones through the `ARGS` field in the `maxtext-parameters` *configMap* as described above. 

In both single slice and multislice examples we use the `ARGS` field to set the training regimen parameters like training steps or batch size,  ICI and DCN parallelization settings, and parameters controlling model architecture for a ~6.5B parameter model pretraining task. These settings have been tested to achieve high model flops utilization (MFU). We encourage you to experiment with your settings.

IMPORTANT. Make sure that the `REPLICAS` field and the `dcn_data_parallelism` and `ici_fsdp_parallelism` trainer parameters align with TPU topology configured in your environment.

To start a single slice training example execute:

```
kustomize build single-slice-6B | kubectl apply -f -

```

Note that we use `kustomize` utility as some of the **Kustomize** features we utilize are not yet supported by `kubectl`.

To start a multi slice training example execute:

```
kustomize build multi-slice-6B | kubectl apply -f -
```

You can monitor the runs using the techniques described in the `tpu_hello_world` section. Since both single slice and multislice workloads also start a job that uploads TensorBoard metrics generated by the MaxText traininer to the configured TensorBoard instance you can monitor the run - in real time - through [Vertex Experiments](https://console.cloud.google.com/vertex-ai/experiments/experiments). The experiment name that will receive the metrics is the same as the value configured in `RUN_NAME`








