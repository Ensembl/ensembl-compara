=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Compara::Graph::NewickParser;
use Bio::EnsEMBL::Compara::Utils::SpeciesTree;
use Bio::EnsEMBL::Compara::SpeciesTree;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'newick_format'         => 'ncbi_taxon',    # the desired output format
            'do_transactions'       => 0,
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
        $species_tree_root = $species_tree_root->minimize_tree;     # The user-defined trees may have some 1-child nodes

        # Let's try to find genome_dbs and ncbi taxa
        my $gdb_a = $self->compara_dba->get_GenomeDBAdaptor;

        # We need to build a hash locally because # $gdb_a->fetch_by_name_assembly()
        # doesn't return non-default assemblies, which can be the case !
        my %all_genome_dbs = map {(lc $_->name) => $_} (grep {not $_->genome_component} @{$gdb_a->fetch_all});

        # First, we remove the extra species that the tree may contain
        foreach my $node (@{$species_tree_root->get_all_leaves}) {
            my $gdb = $all_genome_dbs{lc $node->name};
            if ((not $gdb) and ($node->name =~ m/^(.*)_([^_]*)$/)) {
                # Perhaps the node represents the component of a polyploid genome
                my $pgdb = $all_genome_dbs{lc $1};
                if ($pgdb) {
                    die "$1 is not a polyploid genome\n" unless $pgdb->is_polyploid;
                    $gdb = $pgdb->component_genome_dbs($2) or die "No component named '$2' in '$1'\n";
                }
            }
            if ($gdb) {
                $node->genome_db_id($gdb->dbID);
                $node->taxon_id($gdb->taxon_id);
                $node->node_name($gdb->taxon->name . ( $gdb->principal_genome_db ? sprintf(' (component %s)', $gdb->genome_component) : ''));
                $node->{_tmp_gdb} = $gdb;
            } else {
                warn $node->name, " not found in the genome_db table";
                $node->disavow_parent();
                $species_tree_root = $species_tree_root->minimize_tree;
            }
        }

        # Secondly, we can search the LCAs in the NCBI tree
        my $ncbi_taxa_a = $self->compara_dba->get_NCBITaxonAdaptor;
        foreach my $node (reverse @{$species_tree_root->get_all_nodes}) {
            if (not $node->is_leaf) {
                my $int_taxon = $ncbi_taxa_a->fetch_first_shared_ancestor_indexed(map {$_->{_tmp_gdb}->taxon} @{$node->get_all_leaves});
                $node->taxon_id($int_taxon->taxon_id);
                $node->node_name($int_taxon->name) unless $node->name;
            }
        }

    } else {    # generate the tree from the database+params

        my @tree_creation_args = ();

        foreach my $config_param
                (qw(no_previous species_set_id extrataxon_sequenced multifurcation_deletes_node multifurcation_deletes_all_subnodes)) {

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

    # To make sure we don't leave the database with a half-stored tree
    $self->call_within_transaction(sub {
        $speciesTree_adaptor->store($species_tree);
    });

    $self->dataflow_output_id( {'species_tree_root_id' => $species_tree->root_id}, 2);
}


1;

