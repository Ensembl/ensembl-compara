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

Bio::EnsEMBL::Compara::RunnableDB::Alignment_depth_calculator

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::AlignmentDepthCalculator;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Utils::Cigars;
use Bio::EnsEMBL::Compara::Utils::Preloader;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
#    	'genomic_align_block_id'           => '11320000002048',
#    	'compara_db' 					   => 'mysql://ensro@mysql-ens-compara-prod-1.ebi.ac.uk:4485/ensembl_compara_93',
    }
}

sub fetch_input {
    my $self         = shift @_;
    my $genomic_align_block = $self->compara_dba->get_GenomicAlignBlockAdaptor->fetch_by_dbID($self->param('genomic_align_block_id'));

    $self->param('genomic_aligns', $genomic_align_block->genomic_align_array());
    Bio::EnsEMBL::Compara::Utils::Preloader::load_all_DnaFrags($self->compara_dba->get_DnaFragAdaptor, $self->param('genomic_aligns'));
  
    print "$_->dbID \n" foreach $self->param('genomic_aligns');
}

sub run {
    my $self = shift @_;
    $self->disconnect_from_databases;

    my @cigar_lines     = map {$_->cigar_line} @{$self->param('genomic_aligns')};
    my @genome_db_ids   = map {$_->dnafrag->genome_db_id} @{$self->param('genomic_aligns')};
    my $total_depths    = Bio::EnsEMBL::Compara::Utils::Cigars::compute_alignment_depth(\@cigar_lines, \@genome_db_ids);

    $self->param('total_depths', $total_depths);
}

sub write_output {
    my $self = shift @_;
    my $total_depths = $self->param('total_depths');
    foreach my $genome_id ( keys %$total_depths ) {
        my $n_aligned_pos       = $total_depths->{$genome_id}->{'n_aligned_pos'};
        my $sum_aligned_bases   = $total_depths->{$genome_id}->{'depth_sum'};
        print " \n genome_id : $genome_id,   number of positions : $n_aligned_pos   number of aligned bases : $sum_aligned_bases \n\n\n" if ( $self->debug >3 );
        $self->dataflow_output_id({ 'genome_db_id' => $genome_id, 'num_of_aligned_positions' => $n_aligned_pos} ,2);
        $self->dataflow_output_id({ 'genome_db_id' => $genome_id, 'sum_aligned_seq' => $sum_aligned_bases} ,3);
    }
}


1;
