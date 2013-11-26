=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a nc_tree cluster as input
Run an MCOFFEE multiple alignment on it, and store the resulting alignment
back into the nc_tree_member table.

input_id/parameters format eg: "{'gene_tree_id'=>726093}"
    gene_tree_id       : use family_id to run multiple alignment on its members
    options            : commandline options to pass to the 'mcoffee' program

=head1 SYNOPSIS

my $db     = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $mcoffee = Bio::EnsEMBL::Compara::RunnableDB::Mcoffee->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$mcoffee->fetch_input(); #reads from DB
$mcoffee->run();
$mcoffee->write_output(); #writes to DB

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ncRNAtrees::MSAChooser;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'treebreak_gene_count'  => 400,                     # if the resulting cluster is bigger, it is dataflown to QuickTreeBreak
    };
}


=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for mcoffee from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
    my( $self) = @_;

    # Getting parameters and objects from the database
    my $nc_tree_id = $self->param_required('gene_tree_id');

    my $tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id($nc_tree_id);
    die "Unfetchable tree root_id=$nc_tree_id\n" unless $tree;

    my $gene_count = scalar(@{$tree->get_all_Members});
    die "Unfetchable leaves root_id=$nc_tree_id\n" unless $gene_count;

    if ($gene_count > $self->param('treebreak_gene_count')) {
        # Create an alignment job and the waiting quicktree break job
        $self->dataflow_output_id($self->input_id, 3);
        $self->dataflow_output_id($self->input_id, 4);
        $self->input_job->incomplete(0);
        die "Cluster root_id=$nc_tree_id over threshold (gene_count=$gene_count > ".($self->param('treebreak_gene_count'))."), dataflowing to QuickTreeBreak\n";
    }

    # The tree follows the "normal" path: create an alignment job
    $self->dataflow_output_id($self->input_id, 1);
}


1;
