-- See the NOTICE file distributed with this work for additional information
-- regarding copyright ownership.
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--      http://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

# patch_100_101_d.sql
#
# Title: Use the correct integer type for node_id foreign keys
#
# Description:
#   The left_node_id and right_node_id columns of the genomic_align_tree
#   table are references to the node_id column of the same table and
#   should have the same integer type.


ALTER TABLE genomic_align_tree
  MODIFY left_node_id bigint(20) unsigned,
  MODIFY right_node_id bigint(20) unsigned,
  ADD FOREIGN KEY (`left_node_id`) REFERENCES genomic_align_tree(node_id),
  ADD FOREIGN KEY (`right_node_id`) REFERENCES genomic_align_tree(node_id);

# Patch identifier
INSERT INTO meta (species_id, meta_key, meta_value)
  VALUES (NULL, 'patch', 'patch_100_101_d.sql|gat.node_ids');

