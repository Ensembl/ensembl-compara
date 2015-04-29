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

package EnsEMBL::Web::Controller::DAS;

### Prints the dynamically created components. Loaded either via AJAX (if available) or parallel HTTP requests.

use strict;

use EnsEMBL::Web::Configuration::DAS;
use EnsEMBL::Web::Document::Page::Dynamic;

use base qw(EnsEMBL::Web::Controller::Component);

sub page_type     { return 'Dynamic';                 }
sub renderer_type { return 'Apache';                  }
sub request       { return $_[0]->hub->script;        }
sub page          { return $_[0]->SUPER::page('DAS'); }

sub configure {
  my $self          = shift;
  my $request       = $self->request;
  my $configuration = EnsEMBL::Web::Configuration::DAS->new($self->page, $self->hub, $self->builder);
  
  if ($configuration->can($request)) {
    $configuration->$request();
  } else {
    $self->add_error('Fatal error - bad request', "Function '$request' is not implemented");
  }
}

1;
