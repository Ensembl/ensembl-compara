
=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

    my $n_removed_columns = $self->get_removed_columns();
    $self->param( 'n_removed_columns', $n_removed_columns );

    my $shrinking_factor = $self->get_shrinking_factor();
    $self->param( 'shrinking_factor', $shrinking_factor );

    my $gene_count = scalar( @{ $self->get_gene_count() } );
    $self->param( 'gene_count', $gene_count );
}

sub write_output {
    my $self = shift;
    $self->param('gene_tree')->store_tag( 'n_removed_columns',   $self->param('n_removed_columns') );
    $self->param('gene_tree')->store_tag( 'shrinking_factor',    $self->param('shrinking_factor') );
    $self->param('gene_tree')->store_tag( 'after_filter_length', $self->param('after_filter_length') );
    $self->param('gene_tree')->store_tag( 'gene_count',          $self->param('gene_count') );
}

##########################################
#
# internal methods
#
##########################################
sub get_gene_count {
    my $self       = shift;
    my $gene_count = $self->param('gene_tree')->get_all_Members();
    return $gene_count;
}

sub get_removed_columns {
    my $self = shift;
    if ( $self->param('gene_tree')->has_tag('removed_columns') ) {
        my $removed_columns = $self->param('gene_tree')->get_value_for_tag('removed_columns');
        my @removed_columns = eval($removed_columns);
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

sub get_shrinking_factor {
    my $self = shift;

    my $aln_length = $self->param('gene_tree')->get_value_for_tag('aln_length') || die "Could not fetch tag aln_length for root_id=" . $self->param_required('gene_tree_id');
    if ( $self->param('gene_tree')->has_tag('removed_columns') ) {
        my $n_removed_columns = $self->param('n_removed_columns');

        my $after_filter_length = $aln_length - $n_removed_columns;
        $self->param( 'after_filter_length', $after_filter_length );
        my $ratio = 1 - ( $after_filter_length/$aln_length );
        return $ratio;
    }
    else {
        $self->param( 'after_filter_length', $aln_length );
        return 0;
    }
}

1;
