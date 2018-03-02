
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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self         = shift @_;
    my $gene_tree_id = $self->param_required('gene_tree_id');
    $self->param( 'tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    my $gene_tree = $self->param('tree_adaptor')->fetch_by_dbID($gene_tree_id) or die "Could not fetch gene_tree with gene_tree_id='$gene_tree_id'";

    #print Dumper $gene_tree;
    $self->param( 'gene_tree', $gene_tree );
}

sub run {
    my $self = shift @_;

    my $n_removed_columns = $self->_get_removed_columns();
    $self->param( 'n_removed_columns', $n_removed_columns );

    my $shrinking_factor = $self->_get_shrinking_factor( $n_removed_columns );
    $self->param( 'shrinking_factor', $shrinking_factor );

    my $gene_count = $self->_get_gene_count();
    $self->param( 'gene_count', $gene_count );

    my $cigar_breakout = $self->_get_cigar_breakout();
    $self->param( 'cigar_breakout', $cigar_breakout);

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
sub _get_gene_count {
    my $self       = shift;
    my $gene_count = $self->param('gene_tree')->get_all_Members() || die "Could not get_all_Members for genetree: " . $self->param_required('gene_tree_id');
    return scalar(@{$gene_count});
}

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

sub _get_cigar_breakout {
    my $self = shift;

    $self->param( 'gene_tree_id',      $self->param_required('gene_tree_id') );
    $self->param( 'gene_tree_adaptor', $self->compara_dba->get_GeneTreeAdaptor );
    $self->param( 'gene_tree',         $self->param('gene_tree_adaptor')->fetch_by_dbID( $self->param('gene_tree_id') ) ) or die "Could not fetch gene_tree with gene_tree_id='" . $self->param('gene_tree_id');

    #Fetch tags
    $self->param( 'cigar_lines', $self->compara_dba->get_AlignedMemberAdaptor->fetch_all_by_gene_align_id( $self->param('gene_tree')->gene_align_id ) );

    my @cigar_breakout;

    print "\ncigar:\n";

    foreach my $member ( @{ $self->param('cigar_lines') } ) {

        #get cigar line
        my $cigar_line = $member->cigar_line;
        #print "$cigar_line\n";

        #break the cigar line
        my %break = $member->get_cigar_breakout( $member->cigar_line );

        push(@cigar_breakout, \%break);
    }

    return \@cigar_breakout;
}

sub _get_gappiness {
    my $self = shift;

    #Amount of positions on the alignment
    my $sum = 0;

    #Quantity of gaps in the alignment
    my $gaps = 0;

    foreach my $member_break ( @{ $self->param('cigar_breakout') } ) {
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

    my $aln_length = $self->param('gene_tree')->get_value_for_tag('aln_length') || die "Could not fetch tag aln_length for root_id=" . $self->param_required('gene_tree_id');

    my @cigar_lines_arrays;
    my $member_counter = 0;

    #COLLAPSED VERSION
    print "expanded:\n";
    foreach my $member ( @{ $self->param('cigar_lines') } ) {

        #get cigar line
        my $cigar_line          = $member->cigar_line;
        $cigar_lines_arrays[$member_counter] = $member->get_cigar_array;
        $member_counter++;
    }

    #cigar_lines_arrays => [
    #           member_1    [[D,3], [M,3], [D2]],
    #           member_2    [[M,8]],
    #           member_3    [[D,1], [M,5], [D,2]]
    #                      ]

    # We could use this example to test the code:
    # We need to comment the declarations of cigar_lines_arrays and member_counter above and redefine them like this:
    #my @v1 = ('D',3);
    #my @v2 = ('M',3);
    #my @v3 = ('D',2);
    #my @v4 = ('M',8);
    #my @v5 = ('D',1);
    #my @v6 = ('M',5);
    #my @v7 = ('D',2);

    #my @m1 = (\@v1,\@v2,\@v3);
    #my @m2 = (\@v4);
    #my @m3 = (\@v5,\@v6,\@v7);

    #$cigar_lines_arrays[0] = \@m1;
    #$cigar_lines_arrays[1] = \@m2;
    #$cigar_lines_arrays[2] = \@m3;
    #$member_counter = 3;

    #print Dumper @cigar_lines_arrays;
    #print scalar(@cigar_lines_arrays)."\n";
    #print "$cigar_lines_arrays[0]->[0]->[0]\n";

    #load

    #Contains the sum of the aligned sequences per alignment column (iteration)
    my %sum;
    my @seq_num_of_aligned_positions;

    #while number of memebers > 0
    while (scalar(@{ $cigar_lines_arrays[0] })) {

        my @aligned_members;
        for ( my $member = 0; $member < $member_counter; $member++ ) {
            #We always read the first element, No need to iterate in the position we always read from position 0
            if ( $cigar_lines_arrays[$member]->[0]->[0] eq 'M' ) {
                push(@aligned_members, $member);
            }
            $cigar_lines_arrays[$member]->[0]->[1]--;
            if ( $cigar_lines_arrays[$member]->[0]->[1] == 0 ) {
                shift(@{ $cigar_lines_arrays[$member] });
            }
        }

        foreach my $aligned_member (@aligned_members) {
            $sum{$aligned_member} += scalar(@aligned_members) - 1;
            $seq_num_of_aligned_positions[$aligned_member]++;
        }

    } ## end while ( scalar(@cigar_lines_arrays...))

    #average
    my $total = 0;
    foreach my $member ( keys %sum ) {
        my $seq_avg = $sum{$member}/$seq_num_of_aligned_positions[$member];
        #print $sum{$member} . "/" . $seq_num_of_aligned_positions[$member] . " = $seq_avg\n" if ($self->debug);
        $total += $seq_avg;
    }
    my $avg = $total/scalar(keys(%sum));

} ## end sub _get_alignment_depth

1;
