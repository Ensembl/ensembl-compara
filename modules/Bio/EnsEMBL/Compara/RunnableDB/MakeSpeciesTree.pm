
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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
            'newick_format'         => 'njtree',    # the desired output format
    };
}


sub fetch_input {
    my $self = shift @_;

    return if($self->param('species_tree_string'));     # skip the functionality if the tree has been provided

    my $species_tree_string;

    if(my $species_tree_input_file = $self->param('species_tree_input_file')) {     # load the tree given from a file
        die "The file '$species_tree_input_file' cannot be open for reading" unless(-r $species_tree_input_file);

        $species_tree_string = `cat $species_tree_input_file`;
        chomp $species_tree_string;

    } else {    # generate the tree from the database+params

        my @tree_creation_args = ();

        foreach my $config_param
                (qw(no_previous species_set_id extrataxon_sequenced extrataxon_incomplete multifurcation_deletes_node multifurcation_deletes_all_subnodes)) {

            if(defined(my $config_value = $self->param($config_param))) {
                push @tree_creation_args, ("-$config_param", $config_value);
            }
        }

        my $species_tree;
        if(my $blength_tree_file = $self->param('blength_tree_file')) {     # defines the mode

            my $blength_tree = Bio::EnsEMBL::Compara::Graph::NewickParser::parse_newick_into_tree( `cat $blength_tree_file` );
            $species_tree  = $self->compara_dba()->get_SpeciesTreeAdaptor()->prune_tree( $blength_tree );

        } else {

            $species_tree = $self->compara_dba()->get_SpeciesTreeAdaptor()->create_species_tree( @tree_creation_args );
        }
        
        my $newick_format   = $self->param('newick_format');
        $species_tree_string = $species_tree->newick_format( $newick_format );
    }

    $self->param('species_tree_string', $species_tree_string);
}


sub write_output {
    my $self = shift @_;

    my $species_tree_string = $self->param('species_tree_string');
    my $output_branch = $self->param('blength_tree_file') ? 4 : 3;

    $self->dataflow_output_id( { 'species_tree_string'   => $species_tree_string }, $output_branch);
}

1;

