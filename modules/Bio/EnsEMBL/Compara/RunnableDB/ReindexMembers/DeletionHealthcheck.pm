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

=cut

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::DeletionHealthcheck

=head1 DESCRIPTION

This Runnable checks if the number of gene trees or homologies decreased significantly 
compared to the previous pipeline database. 
The difference between the current and previous counts is normalised by the previous count
and expressed as a perecentage.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ReindexMembers::DeletionHealthcheck;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {

}


sub fetch_input {
    my $self = shift @_;

    $self->param('curr_db', $self);

}

sub run {
    my $self = shift @_;
    my $prev_dbc = $self->get_cached_compara_dba('prev_tree_db')->dbc;
    my $curr_dbc = $self->param('curr_db')->dbc;
    my $diff_limit = $self->param('diff_limit');
    
    my $tree_count = $self->count_gene_trees($curr_dbc);
    my $tree_count_prev = $self->count_gene_trees($prev_dbc);
    # Calculate the difference in gene tree counts and normalise by the previous count:
    my $tree_diff = (($tree_count - $tree_count_prev) * 100) / $tree_count_prev;
    if ($tree_diff < $diff_limit) {
        my $msg = sprintf("WARNING: The decrease in number of trees is higher than the limit: %.3f%% Current count: %d Previous count: %d!\n", abs($tree_diff), $tree_count, $tree_count_prev);
        print $msg;
        $self->throw($msg)
    }

    my $hom_count = $self->count_homologies($curr_dbc);
    my $hom_count_prev = $self->count_homologies($prev_dbc);
    # Calculate the difference in homology counts and normalise by the previous count:
    my $hom_diff = (($hom_count - $hom_count_prev) * 100) / $hom_count_prev;
    if ($hom_diff < $diff_limit) {
        my $msg = sprintf("WARNING: The decrease in number of homologies is higher than the limit: %.3f%% Current count: %d Previous count: %d!\n", abs($hom_diff), $hom_count, $hom_count_prev);
        print $msg;
        $self->throw($msg)
    }

}

sub count_gene_trees {
    my $self = shift;
    my $dbc = shift;

    my $count = $dbc->db_handle->selectrow_array("SELECT COUNT(*) FROM gene_tree_root WHERE tree_type='tree' AND ref_root_id IS NULL;");
    return $count
}

sub count_homologies {
    my $self = shift;
    my $dbc = shift;

    my $count = $dbc->db_handle->selectrow_array("SELECT COUNT(*) FROM homology;");
    return $count;
}

1;
