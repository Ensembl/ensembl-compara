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
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Data::Dumper;
sub fetch_input {
    my $self = shift @_;

    my $mlss_id     = $self->param_required('mlss_id');
    
    my $mlss        = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    my $genome_dbs  = $mlss->species_set->genome_dbs();

    my $filter_high_coverage = $self->param('filter_high_coverage');

    my %selected_gdb_ids = ();

    foreach my $genome_db (@$genome_dbs) {
        next if $genome_db->genome_component;
        if($filter_high_coverage) {
            if ($genome_db->is_high_coverage) {
                $selected_gdb_ids{$genome_db->dbID} = 1;
            }
        } else {    # take all of them
            $selected_gdb_ids{$genome_db->dbID} = 1;
        }
    }

    ###

    my $taxlevels   = $self->param_required('taxlevels');

    my @species_sets = ();

    my $gdb_a = $self->compara_dba()->get_GenomeDBAdaptor;
    my $ncbi_a = $self->compara_dba()->get_NCBITaxonAdaptor;

    foreach my $taxlevel (@$taxlevels) {
        my $taxon = $ncbi_a->fetch_node_by_name($taxlevel);
        die "Cannot find the taxon '$taxlevel' in the database" unless $taxon;
        my $all_gdb_ids = [map {$_->dbID} @{$gdb_a->fetch_all_by_ancestral_taxon_id($taxon->dbID)}];
        push @species_sets, [grep {exists $selected_gdb_ids{$_}} @$all_gdb_ids];
    }

    $self->param('species_sets', \@species_sets);
}


sub write_output {      # dataflow the results
    my $self = shift;

    my $species_sets = $self->param('species_sets');

    foreach my $ss (@$species_sets) {
        $self->dataflow_output_id( { 'genome_db_ids' => $ss }, 2);
    }
}

1;
