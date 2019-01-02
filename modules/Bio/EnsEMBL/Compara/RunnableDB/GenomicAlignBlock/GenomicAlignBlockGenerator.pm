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

Bio::EnsEMBL::Compara::RunnableDB::Genomic_align_block_generator

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::GenomicAlignBlockGenerator;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
    	'mlss_id'           => undef,
    	'fan_branch_code'   => 2,
    }
}

sub fetch_input {
    my $self = shift @_;

    # We try our best to get a list of GenomeDBs
    my $genomic_align_blocks;
    my $mlss_id = $self->param_required('mlss_id');
    my $mlss    = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    $genomic_align_blocks = $self->compara_dba->get_GenomicAlignBlockAdaptor->fetch_all_by_MethodLinkSpeciesSet($mlss);
    $self->param('genomic_align_blocks', $genomic_align_blocks);
}

sub write_output {
	my $self = shift @_;
	foreach my $genomic_align_block(@{$self->param('genomic_align_blocks')}) {
        my $genomic_aligns = $genomic_align_block->genomic_align_array();
        if (scalar @{$genomic_aligns} == 1){
            next;
        } 
        else{
            my @genome_ids;
            foreach my $ga (@{$genomic_aligns}){
                my $ga_genome_id = $ga->genome_db->dbID;
                
            }
        }
		$self->dataflow_output_id({'genomic_align_block_id' => $genomic_align_block->dbID}, $self->param('fan_branch_code'));
	}
}
1;
