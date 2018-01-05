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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DeleteOneTree

=head1 SYNOPSIS

This runnable removes the tree with the given roo
This runnable loads the members from the current database and a previous one, compares them
and performs a list of rename operations to do on the gene-tree tables.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::DeleteOneTree;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub write_output {
    my $self = shift @_;

    $self->call_within_transaction( sub {
        my $gene_tree_adaptor = $self->compara_dba->get_GeneTreeAdaptor;
        my $tree = $gene_tree_adaptor->fetch_by_dbID($self->param_required('gene_tree_id'))
                    or die 'Could not find the tree root_id='.$self->param('gene_tree_id').'. Already deleted ?';
        $tree->preload;
        $gene_tree_adaptor->delete_tree($tree);
        $tree->release_tree;
    } );
}

1;

