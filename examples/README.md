# TPU training workloads examples

This folder contains examples of how to configure and run TPU training jobs using the following methods:
- Using the Kubernetes **Job** resource to run single-slice TPU training jobs
- Using the Kubernetes **JobSet** resource to run multi-slice TPU training jobs

To simplify the configuration of **Job** and **JobSet** resources, we use [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/). The `base_single_slice` folder contains base configurations for  single-slice jobs and the `base_multi_slice` folder base configurations for multi-slice jobs.  Specific job examples are Kustomize [overlays](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays) using these [bases](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays). 

For example, the `maxtext/single_slice` folder contains patches to adapt the base **Job** configuration in `base_single_slice`  to run pretraining of [Maxtext LLM](https://github.com/google/maxtext). 

Before running any examples, update the `namespace` field in `kustomization.yaml` in both `base_single_slice_job_spec` and `base_multi_slice_job_spec` to match the namespace for running TPU jobs configured in your environment. 

Refer to a README file in the given sample's subfolder for the detailed instructions on how to run that sample.



