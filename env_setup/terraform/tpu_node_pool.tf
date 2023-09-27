# Copyright 2023 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


locals {
  tpu_node_pool_names = [for index in range(var.num_tpu_pools) : "${var.tpu_node_pool_name_prefix}-${index}"]
}


resource "google_container_node_pool" "tpu_node_pool" {
  for_each = toset(local.tpu_node_pool_names)

  provider           = google-beta
  project            = var.project_id
  cluster            = module.gke.cluster_id 
  name               = each.key 
  node_locations     = [var.zone]
  initial_node_count = var.enable_tpu_autoscaling ? 0 : var.tpu_num_nodes 

  dynamic autoscaling {
    for_each = var.enable_tpu_autoscaling ? [1] : []
    content {
      max_node_count = var.tpu_num_nodes 
      location_policy      = "ANY"
    }
  }

  node_config {
    machine_type = var.tpu_machine_type
    labels = (var.num_tpu_pools > 1 ? 
              {
                MultisliceGroup=var.multislice_group_name, 
                MultisliceGroupSize=var.num_tpu_pools
              } : null)
  }

  placement_policy {
    type = "COMPACT"
    tpu_topology = var.tpu_topology 
  }
}