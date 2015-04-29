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

package EnsEMBL::Web::Filter::UserData;

### Error messages for userdata database actions

use strict;

use base qw(EnsEMBL::Web::Filter);

sub init {
  my $self = shift;
  
  $self->messages = {
    no_file => 'Unable to save uploaded file contents to your account',
    no_das  => 'Unable to save DAS details to your account',
    no_url  => 'Unable to save remote URL to your account',
  };
}

1;
