=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SummariseWGAStats

=head1 SYNOPSIS



=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::SummariseWGAStats;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my $self = shift;

    my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
    my $ortholog_mlsses = $mlss_adaptor->fetch_all_by_method_link_type('ENSEMBL_ORTHOLOGUES');
    foreach my $omlss ( @$ortholog_mlsses ) {
        my $prot_orths_above_thresh  = $omlss->get_tagvalue('orth_above_protein_wga_thresh');
        # If the tag is not defined, there is no WGA for this mlss
        next unless defined $prot_orths_above_thresh;
        my $prot_orths_total_count   = $omlss->get_tagvalue('total_protein_wga_orth_count');
        # ncRNA pipeline is not run for plants, and Perl does not like summing
        # an integer and an undef
        my $ncrna_orths_above_thresh = $omlss->get_tagvalue('orth_above_ncrna_wga_thresh') || 0;
        my $ncrna_orths_total_count  = $omlss->get_tagvalue('total_ncrna_wga_orth_count') || 0;
        
        my $perc_orths_above_thresh = 100*($prot_orths_above_thresh+$ncrna_orths_above_thresh)/($prot_orths_total_count+$ncrna_orths_total_count);
        $omlss->store_tag('perc_orth_above_wga_thresh', $perc_orths_above_thresh);
    }
}

1;
