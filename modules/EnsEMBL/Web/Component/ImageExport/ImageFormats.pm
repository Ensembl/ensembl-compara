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

  my $form = $self->new_form({'id' => 'export', 'action' => $hub->url({'action' => 'Output',  '__clear' => 1}), 'method' => 'post', 'class' => 'freeform-stt'});

  my $fieldset = $form->add_fieldset({'legend' => 'Select Format'});

  ## Hidden fields needed for redirection to image output
  $fieldset->add_hidden({'name' => 'data_type', 'value' => $hub->param('data_type')});
  $fieldset->add_hidden({'name' => 'component', 'value' => $hub->param('component')});

  $fieldset->add_element({
                          'type'  => 'String',
                          'label' => 'File name (optional)',
                          'value' => $self->default_file_name,
                          });

  my @radio       = qw(journal poster web projector pdf custom);
  my $radio_info  = {
                    'journal'   => {'label' => 'Image for journal/report',
                                    'desc'  => 'High resolution, suitable for printing at A4/letter size',
                                    'info'  => '<ul><li>PNG</li><li>2000px wide</li><li>Darker colours</li></ul>',
                                    },
                    'poster'    => {'label' => 'Image for poster',
                                    'desc'  => 'Very high resolution, suitable for posters and other large print uses',
                                    'info'  => '<ul><li>PNG</li><li>5000px wide</li><li>Darker colours</li></ul>',
                                    },
                    'web'       => {'label' => 'Image for web',
                                    'desc'  => 'Standard image, suitable for web pages, blog posts, etc.',
                                    'info'  => '<ul><li>PNG</li><li>Same size and colours as original image</li></ul>',
                                    },
                    'projector' => {'label' => 'Image for presentation',
                                    'desc'  => 'Saturated image, better suited to projectors',
                                    'info'  => '<ul><li>PNG</li><li>1200px wide</li><li>Darker colours</li></ul>',
                                    },
                    'pdf'       => {'label' => 'PDF file',
                                    'desc'  => 'Standard image as PDF file',
                                    },
                    'custom'    => {'label' => 'Custom image',
                                    'desc'  => 'Select from a range of formats and sizes', 
                                    },
                    };
  my $formats = [];
  foreach (@radio) {
    my $info_icon = $radio_info->{$_}{'info'} 
                      ? sprintf '<img src="/i/16/info.png" class="alignright _ht" title="<p>%s</p>%s" />', 
                                    $radio_info->{$_}{'label'}, $radio_info->{$_}{'info'} 
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
                'value'   => 'journal',
                );
  $fieldset->add_field(\%params);

  $fieldset->add_button('type' => 'Submit', 'name' => 'submit', 'value' => 'Download', 'class' => 'download');

  my $format_options = $self->format_options;

  while (my($type, $fields) = each (%$format_options)) {
    next unless scalar @$fields;
    my $params = {'class' => '_stt_'.$type, 'legend' => 'Options'};
    my $opt_fieldset  = $form->add_fieldset($params);

    ## Add custom fields for this format
    foreach (@$fields) {
      $opt_fieldset->add_element($_);
    }

  }

  return '<h1>Image download</h1>'.$form->render;
}

sub format_options {
  my $self = shift;

  my $image_formats = [
                      {'value' => '',     'caption' => '-- Choose --'},
                      {'value' => 'png',  'caption' => 'PNG'},
                      {'value' => 'pdf',  'caption' => 'PDF'},
                      {'value' => 'svg',  'caption' => 'SVG'},
                      ];

  my $options = {
    'journal'   => [],
    'poster'    => [],
    'web'       => [],
    'projector' => [],
    'custom'    => [{'type' => 'Dropdown', 'name' => 'image_format', 'label' => 'format', 
                      'values' => $image_formats}],
  };

  return $options;
}

sub default_file_name {
  my $self  = shift;
  my $hub   = $self->hub;
  my $name  = $hub->species;

  my $type = $hub->type;

  if ($type eq 'Location') {
    $name .= '_region_'.$hub->param('r');
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
  return $name;
}

1;
