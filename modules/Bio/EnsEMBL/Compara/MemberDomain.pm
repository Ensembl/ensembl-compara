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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

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
use warnings;

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
