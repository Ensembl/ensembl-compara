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

package Bio::EnsEMBL::Compara::Domain;

use strict;
use warnings;

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
