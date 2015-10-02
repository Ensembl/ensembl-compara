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

package EnsEMBL::Web::Component::ImageExport::SelectFormat;

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

  my $form = $self->new_form({'id' => 'image_export', 'action' => $hub->url({'action' => 'Output',  'function' => '', '__clear' => 1}), 'method' => 'post', 'class' => 'freeform'});

  my $fieldset = $form->add_fieldset({'legend' => 'Select Format'});

  my $filename = $hub->param('filename') || $self->default_file_name;
  $filename =~ s/\.[\w|\.]+//;

  my @radio       = qw(text journal poster web projector custom);
  my $radio_info  = {
                    'text'      => {'label' => 'Text file',
                                    'desc'  => 'Output features as BED, GFF or other data format',
                                    },
                    'journal'   => {'label' => 'Journal/report',
                                    'desc'  => 'High resolution, suitable for printing at A4/letter size',
                                    'info'  => '<ul><li>PNG</li><li>2000px wide</li><li>Darker colours</li></ul>',
                                    },
                    'poster'    => {'label' => 'Poster',
                                    'desc'  => 'Higher resolution, suitable for posters and other large print uses',
                                    'info'  => '<ul><li>PNG</li><li>5000px wide</li><li>Darker colours</li></ul>',
                                    },
                    'web'       => {'label' => 'Web image',
                                    'desc'  => 'Standard resolution, suitable for web pages, blog posts, etc.',
                                    'info'  => '<ul><li>PNG</li><li>Same size and colours as original image</li></ul>',
                                    },
                    'projector' => {'label' => 'Projector/presentation',
                                    'desc'  => 'Saturated image, better suited to projectors',
                                    'info'  => '<ul><li>PNG</li><li>1200px wide</li><li>Darker colours</li></ul>',
                                    },
                    'custom'    => {'label' => 'Custom image',
                                    'desc'  => 'Select from a range of formats and sizes', 
                                    },
                    };
  my $formats = [];
  foreach (@radio) {
    my $label   = $self->helptip($radio_info->{$_}{'label'}, $radio_info->{$_}{'info'});
    my $caption = sprintf('<b>%s</b> - %s', $label, $radio_info->{$_}{'desc'});
    push @$formats, {'value' => $_, 'caption' => {'inner_HTML' => $caption}};
  }

  ## Radio buttons for different formats
  my %params = (
                'type'    => 'Radiolist',
                'name'    => 'format',
                'class'   => '_stt_format',
                'values'  => $formats,
                'value'   => 'journal',
                );
  $fieldset->add_field(\%params);

  #$form->add_button(type => 'Submit', name => 'preview', value => 'Preview');
  #$form->add_button(type => 'Submit', name => 'download', value => 'Download');

  return $form->render;
}

sub default_file_name {
  my $self = shift;
  my $name = $self->hub->species;
  my $data_object = $self->hub->param('g') ? $self->hub->core_object('gene') : undef;
  if ($data_object) {
    $name .= '_';
    my $stable_id = $data_object->stable_id;
    my ($disp_id) = $data_object->display_xref;
    $name .= $disp_id || $stable_id;
  }
  $name .= '_download';
  return $name;
}

1;
