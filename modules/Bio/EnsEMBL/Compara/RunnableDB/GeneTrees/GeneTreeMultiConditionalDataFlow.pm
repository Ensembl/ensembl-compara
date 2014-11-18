=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeMultiConditionalDataFlow

=head1 SYNOPSIS

    standaloneJob.pl Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeMultiConditionalDataFlow \
                    -compara_db mysql://anonymous@ensembldb.ensembl.org/ensembl_compara_77 \
                    -gene_tree_id 3 \
                    -branches '{ 2 => "#tree_gene_count# > #threshold_large#", 4 => "#tree_gene_count# < #threshold_small#" }' \
                    -else_branch 3 \
                    -threshold_large 400 \
                    -threshold_small 200 \
                    -debug 1

=head1 DESCRIPTION

This is another implementation of condition-based dataflows (see RunnableDB::ConditionalDataFlow). Whilst the later is
a if-then-else structure, this is more like if-if*-else.
The hash "branches" lists all the branches that can be dataflown to, and the conditions that should first be met to do so.

The recognized parameters are:
    - branches: A hash of the form "branch number" -> "condition"
    - else_branch: the branch number to dataflow to in case none of the conditions have been met

In the above example, the RunnableDB will dataflow on branch #2 if there are more than 400 genes in the tree with root_id=3,
to branch #4 if there are less than 200 genes, and to branch #3 otherwise, which is between 200 and 400 genes.

=head1 LICENSE

    Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

    Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

         http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software distributed under the License
    is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and limitations under the License.

=head1 CONTACT

    Please subscribe to the Hive mailing list:  http://listserver.ebi.ac.uk/mailman/listinfo/ehive-users  to discuss Hive-related questions or to be notified of our updates

=cut


package Bio::EnsEMBL::Compara::RunnableDB::GeneTrees::GeneTreeMultiConditionalDataFlow;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


=head2 param_defaults

    Description : "defaults" must contain the default values of the parameters that could be missing

=cut

sub param_defaults {
    my $self = shift;
    return {
        defaults => {},
        else_branch => undef,
        branches => {},
    }
}


=head2 fetch_input

    Description : Loads all the gene-tree tags with the "tree_" prefix, and the tree itself in "gene_tree".

    param('gene_tree_id'): The root_id of the tree to read the paramters of

=cut

sub fetch_input {
    my $self = shift;

    my $gene_tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_dbID($self->param_required('gene_tree_id'));
    $self->param('gene_tree', $gene_tree);

    my $defaults = $self->param_required('defaults');
    foreach my $tag (keys %$defaults) {
        $self->param($tag, $defaults->{$tag});
    }

    foreach my $tag ($gene_tree->get_all_tags()) {
        warn sprintf("setting %s=%s\n", 'tree_'.$tag, $gene_tree->get_value_for_tag($tag)) if $self->debug;
        $self->param('tree_'.$tag, $gene_tree->get_value_for_tag($tag));
    }
}


=head2 run

    Description : Check each condition and list the branches we have to dataflow to

    param('branches'): The hash describing the branch numbers and the conditions

=cut

sub run {
    my $self = shift;

    my $branches = $self->param('branches');
    die "'branches' must be a HASHREF parameter\n" unless ref($branches) and (ref($branches) eq 'HASH');
    die "'branches' must contain at least one branch\n" unless keys %$branches;

    my @branches_to_dataflow = ();
    foreach my $branch (keys %$branches) {
        my $condition = $branches->{$branch};
        print STDERR "Condition for branch #$branch is: ", $condition, "\n" if $self->debug;

        if (not ref($condition)) {
            $condition = eval($condition);
            $self->throw("Cannot evaluate 'condition' because of: $@") if $@;
            print STDERR "eval() returned $condition\n" if $self->debug;
        }

        push @branches_to_dataflow, $branch if $condition;
    }

    $self->param('branches_to_dataflow', \@branches_to_dataflow);
}


=head2 write_output

    Description : Performs all the dataflows

    param('else_branch'): The default branch that should be activated in case no dataflows has been performed

=cut

sub write_output {
    my $self = shift @_;

    my $branches_to_dataflow = $self->param('branches_to_dataflow');
    foreach my $branch (@$branches_to_dataflow) {
        print STDERR "Dataflowing to branch #$branch\n" if $self->debug;
        $self->dataflow_output_id($self->input_id, $branch);
    }
    unless (@$branches_to_dataflow) {
        my $branch = $self->param('else_branch');
        if ($branch) {
            print STDERR "Dataflowing to the 'else' branch #$branch\n" if $self->debug;
            $self->dataflow_output_id($self->input_id, $branch);
        }
    }
}


1;
