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


=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::LoadTimeTree

=head1 DESCRIPTION

=cut


package Bio::EnsEMBL::Compara::RunnableDB::SpeciesTree::LoadTimeTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    # Build the NCBI taxonomy tree
    print "Building the NCBI tree ...\n" if $self->debug;
    my $species_tree_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree ( -COMPARA_DBA => $self->compara_dba, -ALLOW_SUBTAXA => 1, -RETURN_NCBI_TREE => 1 );
    $species_tree_root->print_tree(0.3) if $self->debug;
    $self->param('species_tree_root', $species_tree_root);
}


sub run {
    my $self = shift @_;

    my @timetree_data;
    my $species_tree_root = $self->param('species_tree_root');
    foreach my $node (@{$species_tree_root->get_all_nodes}) {
        next if $node->is_leaf;
        print "Querying ", $node->name, " ..." if $self->debug;
        my $mya = Bio::EnsEMBL::Compara::Utils::SpeciesTree->get_timetree_estimate_for_node($node);
        printf(" %s mya\n", $mya // 'N/A') if $self->debug;
        push @timetree_data, [$node, $mya];
    }
    $self->param('timetree_data', \@timetree_data);
}


sub write_output {
    my $self = shift @_;

    foreach my $a (@{$self->param('timetree_data')}) {
        $a->[0]->store_tag('ensembl timetree mya', $a->[1]) if defined $a->[1];
    }
}


1;

