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

package EnsEMBL::Web::Object::ImageExport;

### Object for ImageExport pages

### STATUS: Under development

### DESCRIPTION: Unlike most other EnsEMBL::Web::Object children,
### this module is not a wrapper around a specific API object.
### Instead it uses the individual components to fetch and munge 
### data via their own Objects, and does any additional 
### export-specific munging as required. 

use EnsEMBL::Web::Constants;
use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Builder;
use EnsEMBL::Web::File::Dynamic::Image;

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

  my $class = 'EnsEMBL::Web::Component::'.$hub->param('data_type');
  $class   .= '::'.$hub->param('data_action') if $hub->param('data_type') eq 'Tools';
  $class   .= '::'.$hub->param('component');

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

sub handle_download {
### Retrieves file contents and outputs direct to Apache
### request, so that the browser will download it instead
### of displaying it in the window.
### Uses Controller::Download, via url /Download/ImageExport/
  my ($self, $r) = @_;
  my $hub = $self->hub;

  my $filename    = $hub->param('filename');
  my $format      = $hub->param('format');
  my $path        = $hub->param('file');

  ## Strip double dots to prevent downloading of files outside tmp directory
  $path =~ s/\.\.//g;
  ## Remove any remaining illegal characters
  $path =~ s/[^\w|-|\.|\/]//g;

  ## Get content
  my %format_info = EnsEMBL::Web::Constants::IMAGE_EXPORT_FORMATS;
  my $mime_type   = $format_info{$format}{'mime'} || 'text/plain';

  my %params = (hub => $hub, file => $path);
  my $file = EnsEMBL::Web::File::Dynamic::Image->new(%params);
  my $error;

  if ($file->exists) {
    my $result = $file->fetch;
    my $content = $result->{'content'};
    if ($content) {
      ## Create headers via hub, otherwise they get lost somewhere in the guts of the code. Don't ask...
      if ($hub->type eq 'ImageExport') {
        $hub->input->header(-type => $mime_type, -attachment => $filename);
      }
      else {
        $hub->input->header(-type => $mime_type, -inline => $filename);
      }
      print $content;
    }
    else {
      $error = $result->{'error'};
    }
  }
  else {
    $error =  ["Sorry, could not find download file $filename."];
  }

  if ($error) {
    warn ">>> DOWNLOAD ERROR: @$error";
  }
}

1;
