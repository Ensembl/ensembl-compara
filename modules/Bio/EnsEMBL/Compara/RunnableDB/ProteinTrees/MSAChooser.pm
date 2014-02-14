=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MCoffee

=head1 DESCRIPTION

This Analysis/RunnableDB is designed to take a protein_tree cluster as input
Run an MCOFFEE multiple alignment on it, and store the resulting alignment
back into the protein_tree_member table.

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

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSAChooser;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    return {
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
    my $protein_tree_id = $self->param_required('gene_tree_id');

    my $tree = $self->compara_dba->get_GeneTreeAdaptor->fetch_by_root_id($protein_tree_id);
    die "Unfetchable tree root_id=$protein_tree_id\n" unless $tree;

    my $gene_count = $tree->get_value_for_tag('gene_count');
    die "Unfetchable leaves root_id=$protein_tree_id\n" unless $gene_count;
    
    # The tree follows the "normal" path: create an alignment job
    my $reuse_aln_runtime = $tree->get_value_for_tag('reuse_aln_runtime', 0) / 1000;

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
