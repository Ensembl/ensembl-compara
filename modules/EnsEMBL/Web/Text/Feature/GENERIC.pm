=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Text::Feature::GENERIC;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature);

sub seqname   	{  return $_[0]->{'__raw__'}[1]; }
sub rawstart 	{  return $_[0]->{'__raw__'}[2]; }
sub rawend 		{  return $_[0]->{'__raw__'}[3]; }
sub id       	{  return $_[0]->{'__raw__'}[4]; }
sub external_data { return undef; }

sub coords {
  my ($self, $data) = @_;
  return ($data->[1], $data->[2], $data->[3]);
}
 

1;
