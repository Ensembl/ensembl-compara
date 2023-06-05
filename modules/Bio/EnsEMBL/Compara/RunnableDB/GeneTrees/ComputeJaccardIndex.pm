
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

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

    $self->param( 'compara_dba',       $self->compara_dba );
    $self->param( 'reuse_compara_dba', $self->get_cached_compara_dba('reuse_db') );

    #get current tree adaptor
    $self->param( 'current_tree_adaptor', $self->param('compara_dba')->get_GeneTreeAdaptor ) || die "Could not get current GeneTreeAdaptor";

    #get reused tree adaptor
    $self->param( 'reused_tree_adaptor', $self->param('reuse_compara_dba')->get_GeneTreeAdaptor ) || die "Could not get reused GeneTreeAdaptor";

}

sub run {
    my $self = shift @_;

    my $all_trees = $self->param('current_tree_adaptor')->fetch_all( -TREE_TYPE => 'tree', -MEMBER_TYPE => 'protein', -CLUSTERSET_ID => 'default' );

    open( my $plot_jaccard_file, ">", $self->param('output_jaccard_file') ) || die "Could not open '".$self->param('output_jaccard_file')."': $!";
    open( my $plot_gini_file, ">", $self->param('output_gini_file') ) || die "Could not open '".$self->param('output_gini_file')."': $!";

    foreach my $tree ( @{$all_trees} ) {

        my $stable_id = $tree->stable_id();

        my $reused_tree = $self->param('reused_tree_adaptor')->fetch_by_stable_id($stable_id);

        if ($reused_tree) {
            my @leaves_current  = @{ $tree->get_all_Members };
            my @leaves_previous = @{ $reused_tree->get_all_Members };

            #Computing the Jaccard Index give the sets of current and previous members:
            my %members_current = map {$_->gene_member->stable_id => 1} @leaves_current;
            my $union = scalar(@leaves_current);
            my $inter = 0;
            foreach my $leaf (@leaves_previous) {
                if ($members_current{$leaf->gene_member->stable_id}) {
                    $inter++;
                } else {
                    $union++;
                }
            }
            my $tree_jaccard_index = $inter/$union;

            print $plot_jaccard_file "$stable_id\t$tree_jaccard_index\n";
            print $plot_gini_file scalar(@leaves_previous)."\t".scalar(@leaves_current)."\n";

            #Cleaning up memory
            $reused_tree->release_tree;
            $tree->release_tree;
            undef @leaves_previous;
            undef @leaves_current;
        }
    } ## end foreach my $tree ( @{$all_trees...})

    close ($plot_jaccard_file);
    close ($plot_gini_file);

    # contains neeeded libs such as ggplot2
    $ENV{'R_LIBS'} = $self->param_required('renv_dir');

    #Plot Jaccard:
    my $cmd = [ $self->param_required('rscript_exe'), $self->param_required('jaccard_index_script'), $self->param('output_jaccard_file'), $self->param('output_jaccard_pdf')];
    my $cmd_out = $self->run_command($cmd, { die_on_failure => 1 });

    #Plot the Lorentz curve for the Gini coefficient:
    $cmd = [ $self->param_required('rscript_exe'), $self->param_required('lorentz_curve_script'), $self->param('output_gini_file'), $self->param('output_gini_pdf')];
    $cmd_out = $self->run_command($cmd, { die_on_failure => 1 });


} ## end sub run


1;
