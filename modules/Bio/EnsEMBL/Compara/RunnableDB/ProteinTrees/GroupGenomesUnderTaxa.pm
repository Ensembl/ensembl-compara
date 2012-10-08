
=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa

=head1 DESCRIPTION

This Runnable takes in a list of internal taxonomic nodes by their names and an MLSS_id,
and in the output maps each of the input taxonomic nodes onto a list of high coverage genome_db_ids belonging to the given MLSS_id

The format of the input_id follows the format of a Perl hash reference.
Example:
    { 'mlss_id' => 40069, 'taxlevels' => ['Theria', 'Sauria', 'Tetraodontiformes'] }

supported keys:
    'mlss_id'               => <number>

    'taxlevels'             => <list-of-names>

    'filter_high_coverage'  => 0|1

=cut


package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::GroupGenomesUnderTaxa;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $mlss_id     = $self->param('mlss_id')
                        or die "'mlss_id' is an obligatory parameter";

    my $mlss        = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    my $genome_dbs  = $mlss->species_set_obj->genome_dbs();

    my $filter_high_coverage = $self->param('filter_high_coverage');

    my %selected_gdb_ids = ();

    foreach my $genome_db (@$genome_dbs) {
        if($filter_high_coverage) {
            my $core_adaptor = $genome_db->db_adaptor()
                    or die "Could not connect to core database adaptor";

            my $coverage_depth = $core_adaptor->get_MetaContainer()->list_value_by_key('assembly.coverage_depth')->[0]
                    or die "'assembly.coverage_depth' is not defined in core database's meta table". $core_adaptor->dbc->dbname; 

            if( ($coverage_depth eq 'high') or ($coverage_depth eq '6X')) {
                $selected_gdb_ids{$genome_db->dbID} = 1;
            }
        } else {    # take all of them
            $selected_gdb_ids{$genome_db->dbID} = 1;
        }
    }

    ###

    my $taxlevels   = $self->param('taxlevels')
                        or die "'taxlevels' is an obligatory parameter";

    my @species_sets = ();

    my $gdb_a = $self->compara_dba()->get_GenomeDBAdaptor;
    my $ncbi_a = $self->compara_dba()->get_NCBITaxonAdaptor;
    foreach my $taxlevel (@$taxlevels) {
        my $taxon = $ncbi_a->fetch_node_by_name($taxlevel);
        my $all_gdb_ids = [map {$_->dbID} @{$gdb_a->fetch_all_by_ancestral_taxon_id($taxon->dbID)}];
        push @species_sets, [grep {exists $selected_gdb_ids{$_}} @$all_gdb_ids];
    }

    $self->param('species_sets', \@species_sets);
}


sub write_output {      # dataflow the results
    my $self = shift;

    my $species_sets = $self->param('species_sets');

    foreach my $ss (@$species_sets) {
        $self->dataflow_output_id( { 'species_set' => $ss }, 2);
    }
}

1;
