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

Bio::EnsEMBL::Compara::RunnableDB::DetermineGenomeAlignmentDepth

=head1 DESCRIPTION


=cut

package Bio::EnsEMBL::Compara::RunnableDB::GenomicAlignBlock::DetermineGenomeAlignmentDepth;

use strict;
use warnings;
use List::Util qw(reduce);
use Data::Dumper;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    return {
    	
#    	'aligned_seqs' 		=> [15726,1345, 7983,73649,63638],
#    	'aligned_positions'	=> [37464,8163,9173,52733,6382],
#    	'genome_id'			=> 148,
    }
}

sub fetch_input {
    my $self = shift @_;
    my $mlss_adap = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor;
    my $mlss = $mlss_adap->fetch_by_dbID( $self->param_required('mlss_id') );
    my $species_tree = $mlss->species_tree();
    my $species_tree_root = $species_tree->root();
    my $node = $species_tree_root->find_leaves_by_field('genome_db_id', $self->param('genome_id') )->[0];
    print "this is the node id : ", $node->node_id, "\n \n" if ( $self->debug >3 );
    $self->param('node', $node);
}

sub run {
	my $self = shift @_;
	my $sum_aligned_seqs = reduce{$a+$b} @{$self->param_required('aligned_seqs')};
	my $sum_aligned_positions = reduce{$a+$b} @{$self->param_required('aligned_positions')};
	$self->param('genome_alignment_depth', $sum_aligned_seqs/$sum_aligned_positions);
	print Dumper($self->param('genome_alignment_depth')) if ( $self->debug >3 );
    print "this is the node : " , $self->param('node'), "  \n\n" if ( $self->debug >3 );
    my $tag = "alignment_depth";
    $self->param('node')->store_tag($tag, $self->param('genome_alignment_depth'));

}

1;
