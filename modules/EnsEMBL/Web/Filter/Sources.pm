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

package EnsEMBL::Web::Filter::Sources;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Filter);

### Checks if the user has actually selected one or more DAS sources

sub init {
  my $self = shift;
  
  $self->messages = {
    none => 'No sources selected.'
  };
}

sub catch {
  my $self = shift;
  
  $self->redirect = '/UserData/SelectDAS';
  
  # Process any errors
  if (!$self->hub->param('dsn')) {
    $self->error_code = 'none'; # Store the server's message in the session
  }
}

1;
