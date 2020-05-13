
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentTagging;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Utils::Cigars;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self         = shift @_;
    my $gene_tree_id = $self->param_required('gene_tree_id');
    my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($gene_tree_id) or $self->die_no_retry("Could not fetch gene_tree with gene_tree_id='$gene_tree_id'");

    #print Dumper $gene_tree;
    $self->param( 'gene_tree', $gene_tree );

    my $aligned_members = $self->compara_dba->get_AlignedMemberAdaptor->fetch_all_by_gene_align_id( $gene_tree->gene_align_id );
    $self->param( 'aligned_members', $aligned_members );
}

sub run {
    my $self = shift @_;

    my $gappiness = $self->_get_gappiness();
    my $aligned_proportion = 1-$gappiness;
    $self->param( 'gappiness', $gappiness );
    $self->param( 'aligned_proportion', $aligned_proportion);

    my $alignment_depth = $self->_get_alignment_depth();
    $self->param( 'alignment_depth', $alignment_depth);
}

sub write_output {
    my $self = shift;
    $self->param('gene_tree')->store_tag( 'gappiness',               $self->param('gappiness') );
    $self->param('gene_tree')->store_tag( 'aligned_proportion',      $self->param('aligned_proportion') );
    $self->param('gene_tree')->store_tag( 'alignment_depth',         $self->param('alignment_depth') );
}

##########################################
#
# internal methods
#
##########################################

sub _get_gappiness {
    my $self = shift;

    #Amount of positions on the alignment
    my $sum = 0;

    #Quantity of gaps in the alignment
    my $gaps = 0;

    foreach my $member ( @{ $self->param('aligned_members') } ) {

        #break the cigar line
        my $member_break = Bio::EnsEMBL::Compara::Utils::Cigars::get_cigar_breakout($member->cigar_line);

        #get percentages
        foreach my $k ( sort keys %{$member_break} ) {
            $sum += $member_break->{$k};
            if ( $k eq "D" ) {
                $gaps += $member_break->{$k};
            }
        }
    }

    my $gappiness = $gaps/$sum;

    return $gappiness;
}

sub _get_alignment_depth {
    my $self = shift;

    my @cigars = map {$_->cigar_line} @{ $self->param('aligned_members') };
    my $total_depths = Bio::EnsEMBL::Compara::Utils::Cigars::compute_alignment_depth(\@cigars);

    #average
    my $s = 0;
    my $n = 0;
    foreach my $val (values %$total_depths) {
        $s += $val->{'depth_sum'} / $val->{'n_total_pos'};
        $n++;
    }
    return $s/$n;
}

1;
