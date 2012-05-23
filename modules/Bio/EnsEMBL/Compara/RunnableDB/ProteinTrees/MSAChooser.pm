=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a protein_tree cluster as input
Run an MCOFFEE multiple alignment on it, and store the resulting alignment
back into the protein_tree_member table.

input_id/parameters format eg: "{'protein_tree_id'=>726093}"
    protein_tree_id       : use family_id to run multiple alignment on its members
    options               : commandline options to pass to the 'mcoffee' program

=head1 SYNOPSIS

my $db     = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $mcoffee = Bio::EnsEMBL::Compara::RunnableDB::Mcoffee->new (
                                                    -db      => $db,
                                                    -input_id   => $input_id,
                                                    -analysis   => $analysis );
$mcoffee->fetch_input(); #reads from DB
$mcoffee->run();
$mcoffee->output();
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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSAChooser;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
        'treebreak_gene_count'  => 400,                     # if the resulting cluster is bigger, it is dataflown to QuickTreeBreak
        'mafft_gene_count'      => 200,                     # if the cluster is biggger, automatically switch to Mafft
        'mafft_runtime'         => 7200,                    # if the previous run was longer, automatically switch to mafft
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
    my $protein_tree_id = $self->param('protein_tree_id') or die "'protein_tree_id' is an obligatory parameter";

    my $tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id($protein_tree_id);
    die "Unfetchable tree root_id=$protein_tree_id\n" unless $tree;

    my $gene_count = scalar(@{$self->compara_dba->get_GeneTreeNodeAdaptor->fetch_all_AlignedMember_by_root_id($protein_tree_id)});
    die "Unfetchable leaves root_id=$protein_tree_id\n" unless $gene_count;
    
    if ($gene_count > $self->param('treebreak_gene_count')) {
        # Create an alignment job and the waiting quicktree break job
        $self->dataflow_output_id($self->input_id, 4);
        $self->dataflow_output_id($self->input_id, 5);
        $self->input_job->incomplete(0);
        die "Cluster root_id=$protein_tree_id over threshold (gene_count=$gene_count > ".($self->param('treebreak_gene_count'))."), dataflowing to QuickTreeBreak\n";
    }

    # The tree follows the "normal" path: create an alignment job
    my $reuse_aln_runtime = $tree->get_tagvalue('reuse_aln_runtime', 0) / 1000;

    if ($gene_count > $self->param('mafft_gene_count')) {
        # Cluster too large
        $self->dataflow_output_id($self->input_id, 3);

    } elsif ($reuse_aln_runtime > $self->param('mafft_runtime')) {
        # Cluster too long to compute
        $self->dataflow_output_id($self->input_id, 3);

    } else {
        # Default branch
        $self->dataflow_output_id($self->input_id, 2);
    }
    # And let the default dataflow make it :)

}


1;
