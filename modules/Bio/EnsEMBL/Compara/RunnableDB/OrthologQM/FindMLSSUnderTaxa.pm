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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FindMLSSUnderTaxa

=cut


package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::FindMLSSUnderTaxa;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
    my $self = shift @_;

    my $threshold_levels    = $self->param_required('threshold_levels');

    my $gdb_adaptor         = $self->compara_dba->get_GenomeDBAdaptor;
    my $ncbi_adaptor        = $self->compara_dba->get_NCBITaxonAdaptor;
    my $all_orthology_mlsss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES');

    # Lookup table for the mlsss that haven't matched any taxa (yet)
    my %mlss_per_gdbs;
    foreach my $mlss (@$all_orthology_mlsss) {
        my ($gdb1, $gdb2) = @{ $mlss->species_set->genome_dbs };
        $mlss_per_gdbs{$gdb1->dbID."_".$gdb2->dbID} = $mlss;
        $mlss_per_gdbs{$gdb2->dbID."_".$gdb1->dbID} = $mlss;
    }

    # Process each level and each taxon sequentially
    my @output_ids;
    for (my $i=0; $i<scalar(@$threshold_levels); $i++) {
        foreach my $taxon_name (@{$threshold_levels->[$i]->{'taxa'}}) {
            my $taxon = $ncbi_adaptor->fetch_node_by_name($taxon_name)
                         || !die "Cannot find the taxon '$taxon_name' in the database";
            my $genome_db_ids = [map {$_->dbID} @{$gdb_adaptor->fetch_all_by_ancestral_taxon_id($taxon->dbID)}];

            # Iterate over all the pairs of genome_db_id
            while (my $gdb_id1 = shift @{$genome_db_ids}) {
                foreach my $gdb_id2 (@{$genome_db_ids}) {
                    my $key12 = ($gdb_id1).'_'.($gdb_id2);
                    my $key21 = ($gdb_id2).'_'.($gdb_id1);
                    next unless $mlss_per_gdbs{$key12};
                    my $mlss = $mlss_per_gdbs{$key12};
                    delete $mlss_per_gdbs{$key12};
                    delete $mlss_per_gdbs{$key21};
                    push @output_ids, { 'mlss_id' => $mlss->dbID, 'threshold_index' => $i };
                }
            }
        }
    }
    $self->param('output_ids', \@output_ids);
}


sub write_output {      # dataflow the results
    my $self = shift;

    $self->dataflow_output_id($self->param('output_ids'), 2);
}

1;
