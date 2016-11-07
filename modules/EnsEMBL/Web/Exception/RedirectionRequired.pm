=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Exception::RedirectionRequired;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Exception);

sub handle {
  ## Data needed to handle this exception:
  ##  - url       : URL to redirect to
  ##  - permanent : Optional flag if on will do a permanent redirect
  my ($self, $controller) = @_;

  $controller->r->subprocess_env($self->data->{'permanent'} ? 'ENSEMBL_REDIRECT_PERMANENT' : 'ENSEMBL_REDIRECT_TEMPORARY', $self->data->{'url'});
  $controller->r->subprocess_env('LOG_REQUEST_IGNORE', 1);

  return 1;
}

1;
