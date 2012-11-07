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

Bio::EnsEMBL::Compara::GeneAlign

=head1 DESCRIPTION

Class to represent an alignment of genes, used as the base for a
gene tree. It implements the AlignedMemberSet interface.

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::GeneAlign
  +- Bio::EnsEMBL::Compara::AlignedMemberSet

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

package Bio::EnsEMBL::Compara::GeneAlign;

use Bio::EnsEMBL::Utils::Argument;
use Bio::EnsEMBL::Utils::Scalar qw(:assert);

use strict;

use base ('Bio::EnsEMBL::Compara::AlignedMemberSet');


##############################
# Constructors / Destructors #
##############################

=head2 new

  Example    :
  Description:
  Returntype : Bio::EnsEMBL::Compara::GeneAlign
  Exceptions :
  Caller     :

=cut

sub new {
    my($class,@args) = @_;

    my $self = $class->SUPER::new(@args);

    if (scalar @args) {
        my ($aln_method, $aln_length) = rearrange([qw(ALN_METHOD ALN_LENGTH)], @args);

        $aln_method && $self->aln_method($aln_method);
        $aln_length && $self->aln_length($aln_length);
    }

    return $self;
}


#####################
# Object attributes #
#####################
=head2 aln_length

  Description : Getter/Setter for the aln_length field. This field contains
                the length of the alignment
  Returntype  : Integer
  Example     : my $len = $tree->aln_length();
  Caller      : General

=cut

sub aln_length {
    my $self = shift;
    $self->{'_aln_length'} = shift if(@_);
    return $self->{'_aln_length'};
}


=head2 aln_method

  Description : Getter/Setter for the aln_method field. This field should
                represent the method used for the alignment
  Returntype  : String
  Example     : my $method = $tree->aln_method();
  Caller      : General

=cut

sub aln_method {
    my $self = shift;
    $self->{'_aln_method'} = shift if(@_);
    return $self->{'_aln_method'};
}


#######################
# MemberSet interface #
#######################

=head2 _attr_to_copy_list

  Description: Returns the list of all the attributes to be copied by deep_copy()
  Returntype : Array of String
  Caller     : General

=cut

sub _attr_to_copy_list {
    my $self = shift;
    my @sup_attr = $self->SUPER::_attr_to_copy_list();
    push @sup_attr, qw(_aln_length _aln_method);
    return @sup_attr;
}


1;

