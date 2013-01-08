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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the CVS log.

=cut

=head1 NAME

MemberDomain - DESCRIPTION of Object

=head1 DESCRIPTION

A subclass of Member which extends it to store a domain (start / end)
within the sequence

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::MemberDomain
  +- Bio::EnsEMBL::Compara::Member

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::MemberDomain;

use strict;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Compara::Member;

use base ('Bio::EnsEMBL::Compara::Member');


##################################
# overriden superclass methods
##################################

=head2 copy

  Arg [1]     : none
  Example     : $copy = $aligned_member->copy();
  Description : Creates a new MemberDomain object from an existing one
  Returntype  : Bio::EnsEMBL::Compara::MemberDomain
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub copy {
  my $self = shift;
  
  my $mycopy = @_ ? shift : {};     # extending or from scratch?
               $self->SUPER::copy($mycopy);
  bless $mycopy, 'Bio::EnsEMBL::Compara::MemberDomain';

  # The following does not Work if the initial object is only a Member
  if (UNIVERSAL::isa($self, 'Bio::EnsEMBL::Compara::MemberDomain')) {
    $mycopy->member_start($self->member_start);
    $mycopy->member_end($self->member_end);
  }

  return $mycopy;
}


=head2 member_start

  Arg [1]     : (optional) $member_start
  Example     : $object->member_start($member_start);
  Example     : $member_start = $object->member_start();
  Description : Getter/setter for the member_start attribute. For non-global
                alignments, this represent the starting point of the local
                alignment.
                Currently the data provided as MemberDomains (leaves of the
                GeneTree) are obtained using global alignments and the
                member_start is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub member_start {
  my $self = shift;
  $self->{'_member_start'} = shift if(@_);
  return $self->{'_member_start'};
}


=head2 member_end

  Arg [1]     : (optional) $member_end
  Example     : $object->member_end($member_end);
  Example     : $member_end = $object->member_end();
  Description : Getter/setter for the member_end attribute. For non-global
                alignments, this represent the ending point of the local
                alignment.
                Currently the data provided as MemberDomains (leaves of the
                GeneTree) are obtained using global alignments and the
                member_end is always undefined.
  Returntype  : integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub member_end {
  my $self = shift;
  $self->{'_member_end'} = shift if(@_);
  return $self->{'_member_end'};
}



1;
