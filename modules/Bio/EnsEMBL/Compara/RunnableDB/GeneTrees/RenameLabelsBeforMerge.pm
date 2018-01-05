=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabelsBeforMerge

=head1 SYNOPSIS

Simple Runnable based on eHive's SqlCmd that offsets all the gene-related tables

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::RenameLabelsBeforMerge;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::SqlCmd');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults() },

        'sql'   => [
                    'UPDATE gene_tree_root SET clusterset_id = CONCAT("#label_prefix#", clusterset_id) WHERE clusterset_id NOT LIKE "#label_prefix#%" AND clusterset_id != "default"',
                    'UPDATE gene_tree_root SET clusterset_id = "#division#" WHERE clusterset_id = "default"',
                    'UPDATE hmm_profile SET type = CONCAT("#label_prefix#", type) WHERE type NOT LIKE "#label_prefix#%"',
                ],
    }
}

1;
