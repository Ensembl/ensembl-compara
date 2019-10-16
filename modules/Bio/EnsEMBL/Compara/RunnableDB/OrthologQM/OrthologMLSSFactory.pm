=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2019] EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologMLSSFactory

=cut

package Bio::EnsEMBL::Compara::RunnableDB::OrthologQM::OrthologMLSSFactory;

use strict;
use warnings;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift;
    
    my $dba = $self->param('alt_homology_db') ? $self->get_cached_compara_dba('alt_homology_db') : $self->compara_dba;
    $self->param('current_dba', $dba);
    $self->dbc->disconnect_if_idle() if $self->dbc;
    
    my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor;
        
    my $aln_mlsss = $self->param_required('alignment_mlsses');
    my @orth_mlss_dataflow;
    foreach my $aln_info ( @$aln_mlsss ) {
        my $orth_mlss = $mlss_adaptor->fetch_by_method_link_type_genome_db_ids('ENSEMBL_ORTHOLOGUES', [$aln_info->{species1_id}, $aln_info->{species2_id}]);
        $aln_info->{orth_mlss_id} = $orth_mlss->dbID;
        push @orth_mlss_dataflow, $aln_info;
    }
    
    $self->param('orth_mlss_dataflow', \@orth_mlss_dataflow);
}

sub write_output {
	my $self = shift;

	$self->dataflow_output_id( $self->param_required('orth_mlss_dataflow'), 2 ); # to prepare_orthologs
}

1;
