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

package EnsEMBL::Web::Component::ImageExport::ImageFormats;

use strict;
use warnings;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Constants;

use parent qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
  $self->configurable( 0 );
}

sub content {
  ### Options for gene sequence output
  my $self  = shift;
  my $hub   = $self->hub;
  my $default_selected = 'pdf'; # pdf/journal/poster/...
  my $html = '<h1>Image download</h1>';

  my $form = $self->new_form({'id' => 'export', 'action' => $hub->url({'action' => 'ImageOutput',  '__clear' => 1}), 'method' => 'post', 'class' => 'freeform-stt'});

  my $radio_info  = EnsEMBL::Web::Constants::IMAGE_EXPORT_PRESETS;

  my $intro_fieldset = $form->add_fieldset();
  $intro_fieldset->add_field({
                        'type'  => 'String',
                        'name'  => 'filename',
                        'label' => 'File name',
                        'value' => $self->default_file_name($radio_info->{$default_selected}->{format}),
                        });

  my $fieldset = $form->add_fieldset({'legend' => 'Select Format'});

  my $formats     = [];

  foreach (sort {$radio_info->{$a}{'order'} <=> $radio_info->{$b}{'order'}} keys %$radio_info) {
    my $info_icon = $radio_info->{$_}{'info'} 
                      ? sprintf '<img src="/i/16/info.png" class="alignright _ht" title="%s" />',
                                    encode_entities(qq(<p>$radio_info->{$_}{'label'}</p>$radio_info->{$_}{'info'}))
                      : '';
    my $caption = sprintf('<b>%s</b> - %s%s', 
                            $radio_info->{$_}{'label'}, $radio_info->{$_}{'desc'}, $info_icon);
    push @$formats, {'value' => $_, 'class' => '_stt', 'caption' => {'inner_HTML' => $caption}};
  }

  ## Radio buttons for different formats
  my %params = (
                'type'    => 'Radiolist',
                'name'    => 'format',
                'values'  => $formats,
                'value'   => $default_selected,
                );
  $fieldset->add_field(\%params);

  ## Options for custom format
  my $opt_fieldset  = $form->add_fieldset({'class' => '_stt_custom', 'legend' => 'Options'});

  my $image_formats = [{'value' => '', 'caption' => '-- Choose --', 'class' => '_stt'}];
  my %format_info   = EnsEMBL::Web::Constants::IMAGE_EXPORT_FORMATS;
  foreach (sort keys %format_info) {
    my $params = {'value' => $_, 'caption' => $format_info{$_}{'name'}, 'class' => ['_stt']};
    push @{$params->{'class'}}, '_stt__raster ' if $format_info{$_}{'type'} eq 'raster';
    push @$image_formats, $params;
  }
  $opt_fieldset->add_field({'type' => 'Dropdown', 'name' => 'image_format', 'class' => '_stt', 
                            'label' => 'Format', 'values' => $image_formats});

  $opt_fieldset->add_field({'type' => 'Checkbox', 'name' => 'contrast', 
                            'label' => 'Increase contrast', 'value' => '2'}); 

  ## Size and resolution are only relevant to raster formats like PNG
  my $image_sizes = [{'value' => '', 'caption' => 'Current size'}];
  my @sizes = qw(500 750 1000 1250 1500 1750 2000);
  foreach (@sizes) {
    push @$image_sizes, {'value' => $_, 'caption' => "$_ px"};
  }
  $opt_fieldset->add_field({'type' => 'Dropdown', 'name' => 'resize', 'field_class' => '_stt_raster', 
                            'label' => 'Image size', 'values' => $image_sizes});

  my $image_scales = [
                      {'value' => '', 'caption' => 'Standard'},
                      {'value' => '2', 'caption' => 'High (x2)'},
                      {'value' => '5', 'caption' => 'Very high (x5)'},
                      ];

  $opt_fieldset->add_field({'type' => 'Dropdown', 'name' => 'scale', 'field_class' => '_stt_raster',
                            'label' => 'Resolution', 'values' => $image_scales});

  ## Place submit button at end of form
  my $final_fieldset = $form->add_fieldset();

  ## Hidden fields needed for redirection to image output
  ## Just pass everything, on the assumption that the button only passes useful params
  foreach my $p ($hub->param) {
    $final_fieldset->add_hidden({'name' => $p, 'value' => $hub->param($p)});
  }
  
  $final_fieldset->add_button('type' => 'Submit', 'name' => 'submit', 'value' => 'Download', 'class' => 'download');

  my $wrapped_form = $self->dom->create_element('div', {
    'children'  => [ {'node_name' => 'input', 'class' => 'subpanel_type', 'value' => 'ImageExport', 'type' => 'hidden' }, $form ]
  });

  $html .= $wrapped_form->render;

  $html .= '<p>For more information about print options, see our <a href="/Help/Faq?id=502" class="popup">image export FAQ</a>';

  return $html;
}

sub default_file_name {
  my $self  = shift;
  my $ext = shift || '';
  my $hub   = $self->hub;
  (my $name  = $hub->species_defs->SPECIES_DISPLAY_NAME) =~ s/ /_/g;

  my $type = $hub->param('data_type');
  my $action = $hub->param('data_action');

  if ($type eq 'Location') {
    ## Replace hyphens and colons, because they aren't export-friendly
    my $suffix = $action eq 'Genome' ? 'genome' : ($hub->param('r') || '' =~ s/:|-/_/gr);
    $name .= "_$suffix";
  }
  elsif ($type eq 'Gene') {
    my $data_object = $hub->param('g') ? $hub->core_object('gene') : undef;
    if ($data_object) {
      $name .= '_';
      my $stable_id = $data_object->stable_id;
      my ($disp_id) = $data_object->display_xref;
      $name .= $disp_id || $stable_id;
    }
  }
  elsif ($type eq 'Variation' && $hub->param('v')) {
    $name .= '_'.$hub->param('v');
  }
  else {
    $name .= '_'.$type;
  }

  #sanity replace in case of special characters in the name
  $name =~ s/-/_/g;

  return $name . ($ext ? ".$ext" : '');
}

1;
