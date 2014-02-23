=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
                3 => { 'mysql:////meta' => { 'meta_key' => 'test_species_tree', 'meta_value' => '#species_tree_string#' } },    # store the tree in 'meta' table (as an example)
            },
        },

=head1 DESCRIPTION

    This module is supposed to be a cleaner way of creating species trees in Newick string format needed by various pipelines.

=cut


package Bio::EnsEMBL::Compara::RunnableDB::MakeSpeciesTree;

use strict;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Compara::SpeciesTree;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'newick_format'         => 'njtree',    # the desired output format
    };
}


sub fetch_input {
    my $self = shift @_;

    return if($self->param('species_tree_string'));     # skip the functionality if the tree has been provided

    my $species_tree_root;
    my $species_tree_string;

    if(my $species_tree_input_file = $self->param('species_tree_input_file')) {     # load the tree given from a file
        die "The file '$species_tree_input_file' cannot be open for reading" unless(-r $species_tree_input_file);

        $species_tree_string = `cat $species_tree_input_file`;
#        chomp $species_tree_string;

        $species_tree_root = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( $species_tree_string, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' );

        # Let's try to find genome_dbs and ncbi taxa
        my $gdb_a = $self->compara_dba->get_GenomeDBAdaptor;
        my $ncbi_taxa_a = $self->compara_dba->get_NCBITaxonAdaptor;
        foreach my $node (reverse @{$species_tree_root->get_all_nodes}) {
            if ($node->is_leaf) {
                my $gdb = $gdb_a->fetch_by_name_assembly($node->name) or die $node->name." is not a valid GenomeDB name";
                $node->genome_db_id($gdb->dbID);
                $node->taxon_id($gdb->taxon_id);
                $node->node_name($gdb->taxon->name);
                $node->{_tmp_gdb} = $gdb;
            } else {
                my $int_taxon = $ncbi_taxa_a->fetch_first_shared_ancestor_indexed(map {$_->{_tmp_gdb}->taxon} @{$node->get_all_leaves});
                $node->taxon_id($int_taxon->taxon_id);
                $node->node_name($int_taxon->name) unless $node->name;
            }
        }

    } else {    # generate the tree from the database+params

        my @tree_creation_args = ();

        foreach my $config_param
                (qw(no_previous species_set_id extrataxon_sequenced extrataxon_incomplete multifurcation_deletes_node multifurcation_deletes_all_subnodes)) {

            if(defined(my $config_value = $self->param($config_param))) {
                push @tree_creation_args, ("-$config_param", $config_value);
            }
        }

        if(my $blength_tree_file = $self->param('blength_tree_file')) {     # defines the mode
            my $blength_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( `cat $blength_tree_file`, 'Bio::EnsEMBL::Compara::SpeciesTreeNode' );
#            my $blength_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( `cat $blength_tree_file`);
            $species_tree_root  = Bio::EnsEMBL::Compara::Utils::SpeciesTree->prune_tree( $blength_tree, $self->compara_dba );

        } else {
            $species_tree_root = Bio::EnsEMBL::Compara::Utils::SpeciesTree->create_species_tree ( -compara_dba => $self->compara_dba, @tree_creation_args );
        }


    }
    $species_tree_root->build_leftright_indexing();
    $self->param('species_tree_root', $species_tree_root);
}


sub write_output {
    my $self = shift @_;

    my $species_tree_root = $self->param('species_tree_root');
    my $newick_format = $self->param('newick_format');
    my $species_tree_string = $species_tree_root->newick_format( $newick_format );

    my $species_tree = Bio::EnsEMBL::Compara::SpeciesTree->new();
    $species_tree->species_tree($species_tree_string);
    $species_tree->method_link_species_set_id($self->param_required('mlss_id'));
    $species_tree->root($species_tree_root);

    my $label = $self->param('label') || 'default';
    $species_tree->label($label);

    my $speciesTree_adaptor = $self->compara_dba->get_SpeciesTreeAdaptor();
    $speciesTree_adaptor->store($species_tree);

    if ($self->param('for_gene_trees')) {
        # We need to create a fast lookup: genome_db_id => species_tree_node_id
        my $str = '{'.join(', ', map {sprintf('%d=>%d', $_->genome_db_id, $_->node_id)} @{$species_tree_root->get_all_leaves} ).'}';
        $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param('mlss_id'))->store_tag('gdb2stn', $str);
    }
}


1;

