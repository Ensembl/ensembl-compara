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

Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree

=head1 SYNOPSIS

            # a configuration example:
        {   -logic_name    => 'make_species_tree',
            -module        => 'Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree',
            -parameters    => { },
            -input_ids     => [
                { 'species_tree_input_file' => $self->o('species_tree_input_file') },   # if this parameter is set, the tree will be taken from the file, otherwise it will be generated
            ],
            -flow_into  => {
                # Will receive the root_id of the species-tree
                2 => [ 'hc_species_tree' ],
            },
        },

=head1 DESCRIPTION

    This module is supposed to be a cleaner way of creating species trees in Newick string format needed by various pipelines.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Compara::SpeciesTree;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
            'label'                 => 'default',
            'species_set_id'        => undef,
            'no_previous'           => undef,
            'extrataxon_sequenced'  => undef,
            'multifurcation_deletes_node'           => undef,
            'multifurcation_deletes_all_subnodes'   => undef,
    };
}


## Make the tree (can be overriden in subclasses)
sub fetch_input {
    my $self = shift @_;

    my $species_tree_root;

    if(my $species_tree_input_file = $self->param('species_tree_input_file')) {     # load the tree given from a file
        die "The file '$species_tree_input_file' cannot be open for reading" unless(-r $species_tree_input_file);

        my $species_tree_string = $self->_slurp($species_tree_input_file);
#        chomp $species_tree_string;

        $species_tree_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->new_from_newick( $species_tree_string, $self->compara_dba );

    } else {    # generate the tree from the database+params

        my @tree_creation_args = ();

        foreach my $config_param
                (qw(no_previous species_set extrataxon_sequenced multifurcation_deletes_node multifurcation_deletes_all_subnodes allow_subtaxa)) {

            if(defined(my $config_value = $self->param($config_param))) {
                push @tree_creation_args, ("-$config_param", $config_value);
            }
        }

        $species_tree_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree ( -compara_dba => $self->compara_dba, @tree_creation_args );

    }
    $self->param('species_tree_root', $species_tree_root);
}


## Further preparation of the objects (should be common to all trees)
sub run {
    my $self = shift @_;

    my $species_tree_root = $self->param('species_tree_root');
    $species_tree_root->build_leftright_indexing();
    $species_tree_root->print_tree(0.3) if $self->debug;

    my $species_tree = Bio::EnsEMBL::Compara::SpeciesTree->new();
    $species_tree->method_link_species_set_id($self->param_required('mlss_id'));
    $species_tree->root($species_tree_root);

    $species_tree->label($self->param_required('label'));
    $self->param('species_tree', $species_tree);
}


## Store the tree in the database
sub write_output {
    my $self = shift @_;

    my $species_tree = $self->param('species_tree');

    my $speciesTree_adaptor = $self->compara_dba->get_SpeciesTreeAdaptor();

    # To make sure we don't leave the database with a half-stored tree
    $self->call_within_transaction(sub {
        $speciesTree_adaptor->store($species_tree);
    });

    $self->dataflow_output_id( {'species_tree_root_id' => $species_tree->root_id}, 2);
}


1;

