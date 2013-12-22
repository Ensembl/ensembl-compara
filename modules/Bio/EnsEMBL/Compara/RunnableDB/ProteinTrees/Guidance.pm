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

sub param_defaults {
    return {
        'guidance_exe'  => '/nfs/users/nfs_m/mm14/guidance.v1.3.1/www/Guidance/guidance.pl',
        'mafft_exe'     => '/software/ensembl/compara/mafft-7.017/bin/mafft',
    };
}

#
# Abstract methods from the base class (MSA) 
##############################################

sub get_msa_command_line {
    my $self = shift;

    my $tempdir = $self->worker_temp_directory.'/'.$self->param('gene_tree_id');
    $self->param('msa_output', "$tempdir/MSA.MAFFT.Without_low_SP_Col.With_Names");

    return sprintf('perl %s --seqFile %s --msaProgram MAFFT --seqType codon --mafft %s --outDir %s --colCutoff %f',
        $self->param('guidance_exe'),
        $self->param('input_fasta'),
        $self->param('mafft_exe'),
        $tempdir,
        $self->param('guidance_cutoff'),
    );
}

1;
