=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

<<<<<<< HEAD
use EnsEMBL::Web::Controller;
use EnsEMBL::Web::Builder;
=======
>>>>>>> efe4c129eb79dd979f7eb90ceeb7a1da2a52c9d4
use EnsEMBL::Web::TmpFile::Text;

use strict;
use warnings;

use base qw(EnsEMBL::Web::Object);

sub caption       { return 'Export';  }
sub short_caption { return 'Export';  }

<<<<<<< HEAD
sub create_component {
## Create the component we need to get data from, to be sure we're
## using exactly the same data that the user sees 
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
  elsif (!$component->can('export_type')) {
    warn "!!! Export not implemented in component $class";
    $error = 'Export not available';
  }
  return ($component, $error);
}

=======
>>>>>>> efe4c129eb79dd979f7eb90ceeb7a1da2a52c9d4
sub handle_download {
  ## Method reached by url ensembl.org/Download/DataExport/
  my ($self, $r) = @_;
  my $hub = $self->hub;

  my $file        = $hub->param('file');
  my $name        = $hub->param('name') || $file;
  my $format      = $hub->param('format');
  my $prefix      = $hub->param('prefix');
  my $ext         = $hub->param('ext');
  my $compression = $hub->param('compression');
  
  ## Strip any invalid characters from params to prevent downloading of arbitrary files!
  $prefix =~ s/\W//g;

  ## Match only our tmp file path structure (NNN/N/N/NNNNNNN.nnn[.nnn]) !
  if ($file =~ m#^\w[\w/]*(?:\.\w{1,4}(\.\w{1,3})?)?$#) {
    ## Get content
    my %mime_types = (
        'rtf'   => 'application/rtf',
        'gz'    => 'application/x-gzip',
        'zip'   => 'application/zip',
    );
    my $mime_type = $mime_types{$compression} || $mime_types{$format} || 'text/plain';
    my $compress = $compression ? 1 : 0;

    my $tmp_dir = $hub->species_defs->ENSEMBL_TMP_DIR.'/'.$prefix.'/';
    my %params = (filename => $file, prefix => $prefix);
    if ($compress) {
      $params{'compress'} = $compress;
      $params{'get_compressed'} = 1;
    }
    my $tmpfile = new EnsEMBL::Web::TmpFile::Text(%params);

    if ($tmpfile->exists) {
      my $content = $tmpfile->retrieve;

      $r->headers_out->add('Content-Type'         => $mime_type);
      $r->headers_out->add('Content-Length'       => length $content);
      $r->headers_out->add('Content-Disposition'  => sprintf 'attachment; filename=%s', $name);

      print $content;
    }
  }
}

sub expand_slice {
  my ($self, $slice) = @_;
  my $hub = $self->hub;
  $slice ||= $hub->core_object('location')->slice;
  my $lrg = $hub->param('lrg');
  my $lrg_slice;

  if ($slice) {
     my ($flank5, $flank3) = map $self->param($_), qw(flank5_display flank3_display);
     $slice = $slice->invert if ($hub->param('strand') eq '-1');
     return $flank5 || $flank3 ? $slice->expand($flank5, $flank3) : $slice;
   }

  if ($lrg) {
    eval { $lrg_slice = $hub->get_adaptor('get_SliceAdaptor')->fetch_by_region('LRG', $lrg); };
  }
  return $lrg_slice;
}



1;
