
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

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentFilteringTagging;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::Utils::Cigars;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self         = shift @_;
    my $gene_tree_id = $self->param_required('gene_tree_id');
    $self->param( 'tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    my $gene_tree = $self->param('tree_adaptor')->fetch_by_dbID($gene_tree_id) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";

    #print Dumper $gene_tree;
    $self->param( 'gene_tree', $gene_tree );

    my $aligned_members = $self->compara_dba->get_AlignedMemberAdaptor->fetch_all_by_gene_align_id( $gene_tree->gene_align_id );
    $self->param( 'aligned_members', $aligned_members );
}

sub run {
    my $self = shift @_;

    my $n_removed_columns = $self->_get_removed_columns();
    $self->param( 'n_removed_columns', $n_removed_columns );

    my $shrinking_factor = $self->_get_shrinking_factor( $n_removed_columns );
    $self->param( 'shrinking_factor', $shrinking_factor );

    my $gene_count = scalar( @{$self->param('aligned_members')} );
    $self->param( 'gene_count', $gene_count );

    my $gappiness = $self->_get_gappiness();
    my $aligned_proportion = 1-$gappiness;
    $self->param( 'gappiness', $gappiness );
    $self->param( 'aligned_proportion', $aligned_proportion);

    my $alignment_depth = $self->_get_alignment_depth();
    $self->param( 'alignment_depth', $alignment_depth);
}

sub write_output {
    my $self = shift;
    $self->param('gene_tree')->store_tag( 'aln_n_removed_columns',   $self->param('n_removed_columns') );
    $self->param('gene_tree')->store_tag( 'aln_shrinking_factor',    $self->param('shrinking_factor') );
    $self->param('gene_tree')->store_tag( 'aln_after_filter_length', $self->param('after_filter_length') );
    $self->param('gene_tree')->store_tag( 'gene_count',              $self->param('gene_count') );
    $self->param('gene_tree')->store_tag( 'gappiness',               $self->param('gappiness') );
    $self->param('gene_tree')->store_tag( 'aligned_proportion',      $self->param('aligned_proportion') );
    $self->param('gene_tree')->store_tag( 'alignment_depth',         $self->param('alignment_depth') );
}

##########################################
#
# internal methods
#
##########################################

sub _get_removed_columns {
    my $self = shift;
    if ( $self->param('gene_tree')->has_tag('removed_columns') ) {
        my $removed_columns_str = $self->param('gene_tree')->get_value_for_tag('removed_columns');
        #In some cases, alignment filter is ran, but no columns are removed, hence the removed_columns tag is empty.
        #So we should check it and return 0 for those cases.
        if ($removed_columns_str) {
            my @removed_columns = eval($removed_columns_str);
            my $removed_aa;

            foreach my $pos (@removed_columns) {
                my $removed_seq = $pos->[1] - $pos->[0];
                $removed_aa += $removed_seq;
            }
            return $removed_aa;
        }
        else {
            return 0;
        }
    }
    else {
          return 0;
    }
}

sub _get_shrinking_factor {
    my ( $self, $n_removed_columns ) = @_;

    my $aln_length = $self->param('gene_tree')->get_value_for_tag('aln_length') || die "Could not fetch tag aln_length for root_id=" . $self->param_required('gene_tree_id');

    #If no columns were removed, the alignment hasn't shrinked at all.
    if ( $n_removed_columns == 0 ) {
        $self->param( 'after_filter_length', $aln_length );
        return 0;
    }
    my $after_filter_length = $aln_length - $n_removed_columns;
    $self->param( 'after_filter_length', $after_filter_length );
    my $ratio = 1 - ( $after_filter_length/$aln_length );
    return $ratio;
}


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
