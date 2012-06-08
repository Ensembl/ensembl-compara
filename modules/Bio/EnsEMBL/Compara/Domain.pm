package Bio::EnsEMBL::Compara::Domain;

use strict;

use base ('Bio::EnsEMBL::Compara::MemberSet');

=head2 member_class

  Description: Returns the type of member used in the set
  Returntype : String: Bio::EnsEMBL::Compara::MemberDomain
  Caller     : general
  Status     : Stable

=cut

sub member_class {
    return 'Bio::EnsEMBL::Compara::MemberDomain';
}


1;
