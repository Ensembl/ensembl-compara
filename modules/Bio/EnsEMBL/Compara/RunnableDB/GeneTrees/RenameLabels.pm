=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabels

=head1 DESCRIPTION

Simple Runnable based on eHive's SqlCmd that offsets all the gene-related tables

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabels;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::SqlCmd');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        'sql'   => [
                    'UPDATE gene_tree_root SET clusterset_id = CONCAT("#label_prefix#", clusterset_id) WHERE clusterset_id NOT LIKE "#label_prefix#%" AND clusterset_id != "default"',
                    'UPDATE gene_tree_root SET clusterset_id = "#clusterset_id#" WHERE clusterset_id = "default"',
                    'UPDATE gene_tree_root SET stable_id = CONCAT("#label_prefix#", stable_id) WHERE stable_id IS NOT NULL AND stable_id NOT LIKE "#label_prefix#%"',
                    'UPDATE hmm_profile SET type = CONCAT("#label_prefix#", type) WHERE type NOT LIKE "#label_prefix#%"',
                    'UPDATE other_member_sequence SET seq_type = CONCAT("#label_prefix#", seq_type) WHERE "#clusterset_id#" != "default" AND seq_type = "filtered"',
                    'UPDATE gene_align SET seq_type = CONCAT("#label_prefix#", seq_type) WHERE "#clusterset_id#" != "default" AND seq_type = "filtered"',
                ],
    }
}

1;
