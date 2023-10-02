#  Model and data parallelism examples

The samples in this folder use the [shardings.py](https://github.com/google/maxtext/blob/main/pedagogical_examples/shardings.py) script from the [Maxtext repo](https://github.com/google/maxtext). The script is designed to faciliate experimentation with different parallelism strategies available on TPUs, including data parallelism (DP), fully sharded data parallelism (FSDP) and tensor parallelism. For more information, on these topics refer to [TPU Multislice documentation](https://cloud.google.com/tpu/docs/multislice-introduction#get-started).

The samples are **overlays** on top of the base **Job** and **JobSet** settings that execute the `shardings.py` script runs with different parallelism configurations.

