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

package Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft;

use strict;

use base ('Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA');


#
# Abstract methods from the base class (MSA) 
##############################################

sub get_msa_command_line {
    my $self = shift;

    my $mafft_exe = $self->param('mafft_exe') or die "'mafft_exe' is an obligatory parameter";
    die "Cannot execute '$mafft_exe'" unless(-x $mafft_exe);

    my $mafft_binaries = $self->param('mafft_binaries') or die "'mafft_binaries' is an obligatory parameter";
    $ENV{MAFFT_BINARIES} = $mafft_binaries;

    return sprintf('%s --auto %s > %s', $mafft_exe, $self->param('input_fasta'), $self->param('msa_output'));
}

1;
