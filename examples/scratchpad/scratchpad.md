```
METADATA=GKE_METADATA
CLUSTER=jk-tpu-training-cluster

gcloud container node-pools update tpu-node-pool-0 \
    --cluster=$CLUSTER \
    --workload-metadata=$METADATA

gcloud container node-pools update tpu-node-pool-1 \
    --cluster=$CLUSTER \
    --workload-metadata=$METADATA
```

