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

package EnsEMBL::Web::Object::ImageExport;

### Object for ImageExport pages

### STATUS: Under development

### DESCRIPTION: Unlike most other EnsEMBL::Web::Object children,
### this module is not a wrapper around a specific API object.
### Instead it uses the individual components to fetch and munge 
### data via their own Objects, and does any additional 
### export-specific munging as required. 

use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::File::User;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::Object);

sub caption       { return 'Export';  }
sub short_caption { return 'Export';  }

sub create_component {
## Creates the component that the user requested data from. This both 
### avoids code duplication and ensures we are using exactly the same 
### data that the user sees 
### @return Array: object (Component::<data_type>::<component_name>)
###                plus error message (if any)
  my $self = shift;
  my $hub  = $self->hub;
  my ($component, $error);

  my $class = 'EnsEMBL::Web::Component::'.$hub->param('data_type').'::'.$hub->param('component');
  if ($self->dynamic_use($class)) {
    my $builder = EnsEMBL::Web::Builder->new({
                      hub           => $hub,
                      object_params => EnsEMBL::Web::Controller::OBJECT_PARAMS,
    });
    $builder->create_objects(ucfirst($hub->param('data_type')), 'lazy');
    $hub->set_builder($builder);
    $component = $class->new($hub, $builder);
  }
  if (!$component) {
    warn "!!! Could not create component $class";
    $error = 'Export not available';
  }
  return ($component, $error);
}


1;
