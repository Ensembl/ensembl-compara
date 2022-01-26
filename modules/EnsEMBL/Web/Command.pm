=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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
  warn "ERROR - contructor expects a hashref!" unless ref($data) eq 'HASH';
  my $self = $data;
  bless $self, $class;
  return $self;
}

sub object { 
  ## @getter
  ## @return EnsEMBL::Web::Object::[type]
  my $self = shift;
  return $self->{'object'};
}

sub hub { 
  ## @getter
  ## @return EnsEMBL::Web::Hub
  my $self = shift;
  return $self->{'hub'};
}

sub page { 
  ## @getter
  ## @return EnsEMBL::Web::Document::Page::[type]
  my $self = shift;
  return $self->{'page'};
}
 
sub node { 
  ## @getter
  ## @return EnsEMBL::Web::DOM::Node
  my $self = shift;
  return $self->{'node'};
}

sub r { 
  ## @getter
  ## @return Apache2::RequestRec
  my $self = shift;
  return $self->{'page'}->renderer->r;
}

sub script_name {
  ## Builds a valid URL for a given page
  my $self = shift;
  my $object = $self->object;
  my $path = $object->species_path . '/' if $object->species =~ /_/;
  return $path . $object->type . '/' . $object->action;
}

sub ajax_redirect {
  ## Wrapper around Page::ajax_redirect method
  my ($self, $url, $param, $anchor, $redirect_type, $modal_tab) = @_;
  $self->page->ajax_redirect($self->url($url, $param, $anchor), $redirect_type, $modal_tab);
}

1;
