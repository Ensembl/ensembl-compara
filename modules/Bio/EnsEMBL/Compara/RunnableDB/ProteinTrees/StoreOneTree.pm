
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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::StoreOneTree;

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a:
    - gene tree in newick format
    - input_clusterset_id
    - output_clusterset_id

And store the tree in the database.

#standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::StoreOneTree -compara_db mysql://admin:XXXXX@mysql-treefam-prod:4401/TreeFam10 -gene_tree_id 3 -output_clusterset_id raxml -tree_file -no_write

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::StoreOneTree;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GenericRunnable');

sub param_defaults {
    my $self = shift;
    return {
             %{$self->SUPER::param_defaults},
             'cmd'                        => 'cat #tree_file# > tree_#gene_tree_id#.tree',
             'output_file'                => 'tree_#gene_tree_id#.tree',
             'run_treebest_sdi'           => 1,
             'reroot_with_sdi'            => 1,
             'binarize'                   => 1,
    };
}

1;
