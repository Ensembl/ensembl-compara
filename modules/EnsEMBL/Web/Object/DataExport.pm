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

package EnsEMBL::Web::Object::DataExport;

### Object for DataExport pages

### STATUS: Under development

### DESCRIPTION: Unlike most other EnsEMBL::Web::Object children,
### this module is not a wrapper around a specific API object.
### Instead it uses the individual components to fetch and munge 
### data via their own Objects, and does any additional 
### export-specific munging as required. 

use EnsEMBL::Web::File::User;

use EnsEMBL::Web::Utils::DynamicLoader qw(dynamic_require);

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object);

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

  my $builder     = $hub->controller->builder;
  my $object_type = ucfirst($hub->param('data_type'));
  $builder->create_object($object_type);

  my $component = dynamic_require('EnsEMBL::Web::Component::'.$hub->param('data_type').'::'.$hub->param('component'));
     $component = $component->new($hub, $builder, $hub->controller->renderer);
     $component->object($builder->object($object_type));

  return $component;
}

sub handle_download {
### Retrieves file contents and outputs direct to Apache
### request, so that the browser will download it instead
### of displaying it in the window.
### Uses Controller::Download, via url /Download/DataExport/
  my ($self, $r) = @_;
  my $hub = $self->hub;

  my $filename    = $hub->param('filename');
  my $format      = $hub->param('format');
  my $path        = $hub->param('file');
  my $compression = $hub->param('compression');
  
  ## Strip double dots to prevent downloading of files outside tmp directory
  $path =~ s/\.\.//g;
  ## Remove any remaining illegal characters
  $path =~ s/[^\w|-|\.|\/]//g;

  ## Get content
  my %mime_types = (
        'rtf'   => 'application/rtf',
        'gz'    => 'application/x-gzip',
        'zip'   => 'application/zip',
  );
  my $mime_type = $mime_types{$compression} || $format && $mime_types{$format} || 'text/plain';

  my %params = (hub => $hub, file => $path);
  my $file = EnsEMBL::Web::File::User->new(%params);
  my $error;

  if ($file->exists) {
    my $result = $file->fetch;
    my $content = $result->{'content'};
    if ($content) {

      $r->headers_out->add('Content-Type'         => $mime_type);
      $r->headers_out->add('Content-Length'       => length $content);
      $r->headers_out->add('Content-Disposition'  => sprintf 'attachment; filename=%s', $filename);

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

sub expand_slice {
### Helper method to ensure the feature slice is expanded to
### include required flanking distance
  my ($self, $slice) = @_;
  my $hub = $self->hub;
  $slice ||= $hub->core_object('location')->slice;
  my $lrg = $hub->param('lrg');
  my $lrg_slice;

  if ($slice) {
    my ($flank5, $flank3);
    if ($self->param('flanking')) {
      $flank5 = $flank3 = $self->param('flanking');
    }
    elsif ($self->param('flank_size')) {
      $flank5 = $flank3 = $self->param('flank_size');
    } 
    else {
      ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
    }
    $slice = $slice->invert if ($hub->param('strand') && $hub->param('strand') eq '-1');
    return $flank5 || $flank3 ? $slice->expand($flank5, $flank3) : $slice;
  }

  if ($lrg) {
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  }
  return $lrg_slice;
}



1;
