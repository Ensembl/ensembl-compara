
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

=head1 APPENDIX

This runnable computes the Jaccard index, which infers the similarity of a
cluster, it ranges from 0 to 1, with 1 being identical cluster with same set of
genes in the cluster.

It needs two database connections, one to the current release and another to
the previous release.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::ComputeJaccardIndex;

use strict;
use warnings;

use Data::Dumper;
use Set::Jaccard::SimilarityCoefficient;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    $self->param( 'compara_dba',       $self->get_cached_compara_dba('compara_db') );
    $self->param( 'reuse_compara_dba', $self->get_cached_compara_dba('reuse_db') );

    #get current tree adaptor
    $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor ) || die "Could not get current GeneTreeAdaptor";

    #get reused tree adaptor
    $self->param( 'reused_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor ) || die "Could not get reused GeneTreeAdaptor";

}

sub run {
    my $self = shift @_;

    my $all_trees = $self->param('current_tree_adaptor')->fetch_all( -TREE_TYPE => 'tree', -MEMBER_TYPE => 'protein', -CLUSTERSET_ID => 'default' );

    foreach my $tree ( @{$all_trees} ) {

        my @leaves_current = @{ $tree->get_all_Members };

        my $stable_id = $tree->stable_id();

        my $reused_tree = $self->param('reused_tree_adaptor')->fetch_by_stable_id($stable_id);

        if ($reused_tree) {
            my @leaves_previous = @{ $reused_tree->get_all_Members };

            my @members_current  = map { $_->gene_member->stable_id() } @leaves_current;
            my @members_previous = map { $_->gene_member->stable_id() } @leaves_previous;

            #print scalar(@members_current) . "-" . scalar(@members_previous) . "\n";
            #my $s1 = join " ", @members_current;
            #my $s2 = join " ", @members_previous;
            #print "=$s1\n=$s2\n";

            #Computing the Jaccard Index give the sets of current and previous members:
            my $tree_jaccard_index = Set::Jaccard::SimilarityCoefficient::calc( \@members_current, \@members_previous );

            print "$stable_id\t$tree_jaccard_index\n";

            #Cleaning up memory
            $reused_tree->release_tree;
            undef @members_previous;
            undef @leaves_previous;
            undef @members_current;
            undef @leaves_current;
        }
        $tree->release_tree;
    } ## end foreach my $tree ( @{$all_trees...})

} ## end sub run

sub write_output {
    my $self = shift;
}

1;
