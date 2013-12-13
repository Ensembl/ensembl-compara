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

package EnsEMBL::Web::Command;

### Parent module for "Command" steps, in a wizard-type process, which 
### munge data and redirect to a new page rather than rendering HTML

use strict;

use base qw(EnsEMBL::Web::Root); 

sub new {
  my ($class, $data) = @_;
  my $self = {%$data};
  bless $self, $class;
  return $self;
}

sub object :lvalue { $_[0]->{'object'}; }
sub hub    :lvalue { $_[0]->{'hub'};    }
sub page   :lvalue { $_[0]->{'page'};   }
sub node   :lvalue { $_[0]->{'node'};   }
sub r              { return $_[0]->page->renderer->r; }

sub script_name {
  my $self = shift;
  my $object = $self->object;
  my $path = $object->species_path . '/' if $object->species =~ /_/;
  return $path . $object->type . '/' . $object->action;
}

sub ajax_redirect {
  my ($self, $url, $param, $anchor, $redirect_type, $modal_tab) = @_;
  $self->page->ajax_redirect($self->url($url, $param, $anchor), $redirect_type, $modal_tab);
}

1;
