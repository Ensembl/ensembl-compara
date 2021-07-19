=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

### Prints the dynamically created components. Loaded via AJAX

use strict;
use warnings;

use base qw(EnsEMBL::Web::Controller);

sub parse_path_segments {
  # Abstract method implementation
  my $self = shift;
  my @path = @{$self->path_segments};

  $self->{'component_code'} = pop @path;
  ($self->{'type'}, $self->{'action'}, $self->{'function'}, $self->{'sub_function'}) = (@path, '', '', '', '');
}

sub component_code  { $_[0]{'component_code'};  }
sub component       { $_[0]{'component'};       }
sub page_type       { return 'Component';       }
sub cacheable       { return 1;                 }
sub request         { return $_[0]{'request'} ||= $_[0]->species_defs->OBJECT_TO_CONTROLLER_MAP->{$_[0]->hub->type} eq 'Modal' ? 'modal' : ''; }

sub init {
  my $self  = shift;
  my $hub   = $self->hub;

  return if ($hub->function ne 'Export' && $self->get_cached_content('component')); # Page retrieved from cache

  $self->builder->create_objects;
  $self->page->initialize; # Adds the components to be rendered to the page module

  if ($hub->user) {
    my $hash_change = $hub->param('hash_change');
    $self->update_user_history($hash_change) if $hash_change;
  }
  
  $self->configure;

  $self->{'component'} = { @{$self->node->{'data'}{'components'}} }->{$self->{'component_code'}};

  $self->render_page;
}

1;
