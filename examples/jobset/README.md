To simplify the configuration of **Job** and **JobSet** resources, we use [Kustomize](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/). The `base_single_slice` folder contains base configurations for  single-slice jobs and the `base_multi_slice` folder base configurations for multi-slice jobs.  Specific job examples are Kustomize [overlays](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays) using these [bases](https://kubernetes.io/docs/tasks/manage-kubernetes-objects/kustomization/#bases-and-overlays). 

For example, the `maxtext/single_slice` folder contains patches to adapt the base **Job** configuration in `base_single_slice`  to run a single slice pretraining of [Maxtext LLM](https://github.com/google/maxtext). 

## Update the base configurations

Before running any examples, you need to update the base configurations for **Job** and **JobSet** so they reflect your environment.

- Update the `namespace` field in `kustomization.yaml` in both `base_single_slice_job_spec` and `base_multi_slice_job_spec` to match the namespace for running TPU jobs as configured in your environment.
- Optional: Update `hostNetwork` and `dnsPolicy` in `base_multi_slice_job_spec/jobset.yaml`. Multislice training benefits from the performance optimized configuration configuration of internode network (DCN). The default settings for `hostNetwork` - `true` and `dnsPolicy` - `ClusterFirstWithHostNet` configure Kubernetes Pods to use the host network directly for VM to VM communication. This maximizes network performance but constraints some security controls. For example, Workload Identity cannot be used with this network configuration. If you want to turn off host networking remove these to settings from `base_multi_slice_job_spec/jobset.yaml`. 


To run a specific sample follow instructions in the sample's README file.


