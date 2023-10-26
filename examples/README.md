# TPU training workloads examples

This reference guide recommends using the JobSet and Kueue APIs as the preferred way to orchestrate large-scale distributed training workloads on GKE. You can create JobSet yaml configurations in a variety of ways. Our examples demonstrate two approaches:
- Using [Kustomize](https://kustomize.io/). **Kustomize** is a tool that streamlines and simplifies the creation and adaptation of complex configurations like JobSets. It provides robust configuration management and template-free customization. There are examples of creating JobSet configurations using Kustomize in the `jobset` folder.
- Using [xpk](https://github.com/google/maxtext/tree/main/xpk). **xpk** (Accelerated Processing Kit) is a Python-based tool that helps to orchestrate large-scale training jobs on GKE. **xpk** provides a simple command-line interface for managing GKE clusters and submitting training workloads that are encapsulated as JobSet configurations. In this reference guide, we do not use cluster management capabilities. We use **xpk** to configure and submit training workloads to the GKE-based training environment provisioned during the setup. The **xpk** examples are in the `xpk` folder.

The examples are all based on the [MaxText](https://github.com/google/maxtext/tree/main) code base. MaxText is a high-performance, highly scalable, open-source LLM code base written in pure Python/Jax. It is optimized for Google Cloud TPUs and can achieve 55% to 60% MFU (model flops utilization). MaxText is designed to be a launching point for ambitious LLM projects in both research and production. It is also an excellent code base for demonstrating large-scale training design and operational patterns as attempted in this guide.

Before you can run the examples, you need to package MaxText as a training container image. We have automated this process with Cloud Build. 

To build and push the container image to your Container Registry, run the following command:

```
PROJECT_ID=jk-mlops-dev
MAX_TEXT_IMAGE_NAME=gcr.io/$PROJECT_ID/maxtext-runner

gcloud builds submit \
--config build-maxtext.yaml \
--substitutions _MAXTEXT_IMAGE_NAME=$MAX_TEXT_IMAGE_NAME \
--machine-type=e2-highcpu-32 \
--quiet
```

For detailed instructions on running specific examples refer to README documents in the `jobset` and `xpk` folders.


