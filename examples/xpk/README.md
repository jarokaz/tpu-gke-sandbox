# Running TPU workloads with xpk

**xpk** [(Accelerated Processing Kit, pronounced x-p-k,)](https://github.com/google/maxtext/tree/main/xpk) is a Python script that simplifies provisioning of GKE clusters and managing of TPU/GPU training workloads. 

In the following examples we only employ workload submission and management functionality, using the GKE environment created during the setup.


**xpk** uses [JobSet](https://github.com/kubernetes-sigs/jobset) and [Kueue](https://kueue.sigs.k8s.io/docs/overview/) for running training workloads. It runs the workloads in the `default` k8s namespace and assumes that there is a [LocalQueue](https://kueue.sigs.k8s.io/docs/concepts/local_queue/) named `multislice-queue`. **xpk** configures all **JobSet** workloads to be admitted through this queue. If you used the `default` namespace when provisioning your environment you can use it as is. If you used a different namespace, create a local queue using the following command.

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
|v5litepod-16|tpu-v5-lite-podslice|4x4|
|v5litepod-32|tpu-v5-lite-podslice|4x8|
|v5litepod-64|tpu-v5-lite-podslice|8x8|
|v5litepod-128|tpu-v5-lite-podslice|8x16|
|v5litepod-256|tpu-v5-lite-podslice|16x16|





For detailed information about **xpk** refer to [its documentation](https://github.com/google/maxtext/tree/main/xpk).



## Smoke test 

```
CLUSTER_NAME=jk-tpu-training-cluster
TPU_TYPE=v4-16
ZONE=us-central2-b

python3 xpk.py workload create \
--workload xpk-test-workload \
--cluster $CLUSTER_NAME \
--tpu-type=$TPU_TYPE \
--zone=$ZONE \
--command "echo goodbye" 
```