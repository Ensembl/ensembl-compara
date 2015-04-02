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

package EnsEMBL::Web::Controller::Component;

### Prints the dynamically created components. Loaded either via AJAX (if available) or parallel HTTP requests.

use strict;

use base qw(EnsEMBL::Web::Controller);

sub parse_path_segments {
  ## @override
  my $self = shift;

  my $package_path;

  ($self->{'type'}, $package_path, $self->{'action'}, $self->{'function'}) = (@{$self->path_segments}, '', '', '', '');

  # Set action of component to be the same as the action of the referer page for view configs
#  my $referer = $self->referer;

#  $self->{'action'}     = $self->query_param('force_action')    || $referer->{'ENSEMBL_ACTION'};
#  $self->{'function'}   = $self->query_param('force_function')  || $self->{'function'} || $referer->{'ENSEMBL_FUNCTION'};

#  $self->{'component'} = join('::', grep $_, 'EnsEMBL', $package_path, 'Component', $self->{'type'}, $self->{'action'}, $self->{'function'}) =~ s/__/::/gr;
  $self->{'component'} = join('::', grep $_, 'EnsEMBL', $package_path, 'Component', $self->{'type'}, $self->{'action'}) =~ s/__/::/gr;
}

sub component { shift->{'component'}; }
sub page_type { return 'Component';   }
sub cacheable { return 1;             }
sub request   { return $_[0]{'request'} ||= $_[0]->species_defs->OBJECT_TO_SCRIPT->{$_[0]->hub->type} eq 'Modal' ? 'modal' : undef; }

sub init {
  my $self  = shift;
  my $hub   = $self->hub;
 
  return if ($hub->function ne 'Export' && $self->get_cached_content('component')); # Page retrieved from cache
  
  $self->builder->create_objects;
  $self->page->initialize; # Adds the components to be rendered to the page module
  
  my $object = $self->object;
  
  if ($object) {
    $object->__data->{'_action'}   = $self->action;
    $object->__data->{'_function'} = $self->function;
  }
  
  if ($hub->user) {
    my $hash_change = $hub->param('hash_change');
    $self->update_user_history($hash_change) if $hash_change;
  }
  
  $self->configure;
  $self->render_page;
}

1;
