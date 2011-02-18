
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
    my $species_set = $mlss->species_set;
    my $genome_dbs  = (ref($species_set) eq 'ARRAY') ? $species_set : $species_set->genome_dbs();

    my $filter_high_coverage = $self->param('filter_high_coverage');

    my @selected_gdb_ids = ();

    foreach my $genome_db (@$genome_dbs) {
        if($filter_high_coverage) {
            my $core_adaptor = $genome_db->db_adaptor()
                    or die "Could not connect to core database adaptor";

            my $coverage_depth = $core_adaptor->get_MetaContainer()->list_value_by_key('assembly.coverage_depth')->[0]
                    or die "'assembly.coverage_depth' is not defined in core database's meta table";

            if( ($coverage_depth eq 'high') or ($coverage_depth eq '6X')) {
                push @selected_gdb_ids, $genome_db->dbID();
            }
        } else {    # take all of them
            push @selected_gdb_ids, $genome_db->dbID();
        }
    }

    my $selected_gdb_id_string = join(',', @selected_gdb_ids);

    ###

    my $dbc         = $self->compara_dba()->dbc();

    my $taxlevels   = $self->param('taxlevels')
                        or die "'taxlevels' is an obligatory parameter";

    my @species_sets = ();

    foreach my $taxlevel (@$taxlevels) {
        push @species_sets, filter_genomes_by_taxlevel($dbc, $selected_gdb_id_string, $taxlevel);
    }

    $self->param('species_sets', \@species_sets);
}


sub write_output {      # dataflow the results
    my $self = shift;

    my $species_sets = $self->param('species_sets');

    $self->dataflow_output_id( { 'species_sets' => $species_sets }, 2);
}


# ------------------------- non-interface subroutines -----------------------------------


sub filter_genomes_by_taxlevel {    # not a method
    my ($dbc, $selected_gdb_id_string, $taxlevel) = @_;

    my $sql = qq{
        SELECT DISTINCT g.genome_db_id
          FROM ncbi_taxa_name parent_name, ncbi_taxa_node parent_node, ncbi_taxa_node child_node, genome_db g
         WHERE parent_name.name='$taxlevel'
           AND parent_name.taxon_id=parent_node.taxon_id
           AND parent_node.left_index<child_node.left_index
           AND child_node.right_index<=parent_node.right_index
           AND child_node.taxon_id=g.taxon_id
           AND g.genome_db_id in ($selected_gdb_id_string)
      ORDER BY g.genome_db_id
    };

    my @species_subset = ();

    my $sth = $dbc->prepare($sql);
    $sth->execute();

    while(my ($genome_db_id) = $sth->fetchrow()) {
        push @species_subset, $genome_db_id;
    }

    return \@species_subset;
}

1;
