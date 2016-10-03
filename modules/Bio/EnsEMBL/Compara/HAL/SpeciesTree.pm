=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::HAL::SpeciesTree

=cut

package Bio::EnsEMBL::Compara::HAL::SpeciesTree;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Compara::SpeciesTree;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
            'label'                 => 'default',
            'newick_format'         => 'full',    # the desired output format
            'mlss_id'               => undef,
    };
}

sub fetch_input {
    my $self = shift;

    my $gdb_adap = $self->compara_dba->get_GenomeDBAdaptor;
    my $mlss_adap = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    
    my $hal_path = $mlss->url;
    my %species_map = %{ eval $mlss->get_tagvalue('HAL_mapping') };

    die "Path to HAL file missing from  MLSS (id " . $self->param('mlss_id') . ") url field\n" unless (defined $hal_path);
    die "Species name mapping missing from method_link_species_set_tag\n" unless (%species_map);
    die "$hal_path does not exist" unless ( -e $hal_path );

    my $cmd = $self->require_executable('halStats_exe').' --tree '.$hal_path;
    my $newick_tree =  `$cmd`;
    foreach my $gdb_id ( keys %species_map ) {
        my $hal_species = $species_map{$gdb_id};
        my $gdb = $gdb_adap->fetch_by_dbID($gdb_id);
        my $ens_species = $gdb->name;
        $newick_tree =~ s/$hal_species/$ens_species/g;
    }

    my $blength_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $newick_tree, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' );
    my $species_tree_root  = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree( $blength_tree, $self->compara_dba );
    
    $species_tree_root->build_leftright_indexing();
    $self->param('species_tree_root', $species_tree_root);
}

sub write_output {
    my $self = shift;

    my $species_tree_root = $self->param('species_tree_root');
    my $newick_format = $self->param('newick_format');
    my $species_tree_string = $species_tree_root->newick_format( $newick_format );

    my $species_tree = Bio::EnsEMBL::Compara::SpeciesTree->new();
    $species_tree->species_tree($species_tree_string);
    $species_tree->method_link_species_set_id($self->param_required('mlss_id'));
    $species_tree->root($species_tree_root);

    $species_tree->label($self->param('label'));

    my $speciesTree_adaptor = $self->compara_dba->get_SpeciesTreeAdaptor();

    # To make sure we don't leave the database with a half-stored tree
    $self->call_within_transaction(sub {
        $speciesTree_adaptor->store($species_tree);
    });

    print "species_tree_root_id: " . $species_tree->root_id . "\n";

    #$self->dataflow_output_id( {'species_tree_root_id' => $species_tree->root_id}, 2);
}

1;
