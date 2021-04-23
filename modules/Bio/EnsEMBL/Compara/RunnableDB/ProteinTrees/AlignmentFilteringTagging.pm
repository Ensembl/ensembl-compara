=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::AlignmentFilteringTagging

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
    my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($gene_tree_id) or $self->die_no_retry("Could not fetch gene_tree with gene_tree_id='$gene_tree_id'");

    #print Dumper $gene_tree;
    $self->param( 'gene_tree', $gene_tree );
}

sub run {
    my $self = shift @_;

    my $n_removed_columns = $self->_get_removed_columns();
    $self->param( 'n_removed_columns', $n_removed_columns );

    my $shrinking_factor = $self->_get_shrinking_factor( $n_removed_columns );
    $self->param( 'shrinking_factor', $shrinking_factor );
}

sub write_output {
    my $self = shift;
    $self->param('gene_tree')->store_tag( 'aln_n_removed_columns',   $self->param('n_removed_columns') );
    $self->param('gene_tree')->store_tag( 'aln_shrinking_factor',    $self->param('shrinking_factor') );
    $self->param('gene_tree')->store_tag( 'aln_after_filter_length', $self->param('after_filter_length') );
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
                my $removed_seq = $pos->[1] - $pos->[0] + 1;
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
    # When using cDNA, the alignment passed to noisy is DNA, so we need to correct the alignment length
    $aln_length = $aln_length * 3 if ($self->param('cdna'));

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

1;
