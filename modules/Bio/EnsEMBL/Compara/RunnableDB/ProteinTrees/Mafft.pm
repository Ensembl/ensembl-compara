=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::Mafft

=head1 DESCRIPTION

This RunnableDB implements Bio::EnsEMBL::Compara::RunnableDB::ProteinTrees::MSA
by calling Mafft. It only needs the 'mafft_home' pararameters

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
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'mafft_exe'         => '/bin/mafft'             # where to find the mafft executable from $mafft_home
    };
}



#
# Abstract methods from the base class (MSA) 
##############################################

sub get_msa_command_line {
    my $self = shift;

    my $mafft_home = $self->param('mafft_home') or die "'mafft_home' is an obligatory parameter";
    my $mafft_exe = $self->param('mafft_exe') or die "'mafft_exe' is an obligatory parameter";
    die "Cannot execute '$mafft_exe' in '$mafft_home'" unless(-x $mafft_home.'/'.$mafft_exe);

    return sprintf('%s/%s --anysymbol --auto %s > %s', $mafft_home, $mafft_exe, $self->param('input_fasta'), $self->param('msa_output'));
}

1;
