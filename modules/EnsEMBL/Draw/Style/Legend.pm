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

package EnsEMBL::Draw::Style::Legend;

=pod
Renders a dataset as a legend, i.e. one or more columns of icons with labels

This module expects data in the following format:

  $data = {
            'entry_order' => [qw(item1 item2 item2)],
            'entries'     => {
                              'item1' => {
                                          'colour'  => 'red',
                                          'label'   => 'Item 1',
                                          },
                              'item2' => {
                                          'colour'  => 'green',
                                          'label'   => 'Item 1',
                                          'shape'   => 'triangle',
                                          'outline' => 1,
                                          'filled'  => 0,
                                          },
  };

Note that only colour and label are mandatory - optional extra parameters are used for icons 
that are a different shape or pattern to the usual solid rectangle

=cut

use strict;
use warnings;
no warnings 'uninitialized';

use POSIX qw(ceil floor);

use parent qw(EnsEMBL::Draw::Style);

sub create_glyphs {
### Create all the glyphs required by this style
### @return ArrayRef of EnsEMBL::Web::Glyph objects
  my $self = shift;

  my $data            = $self->data;
  my $image_config    = $self->image_config;
  my $track_config    = $self->track_config;

  my $box_width       = $track_config->get('box_width');
  my $icon_height     = $track_config->get('icon_height');

  my $y                   = 0;
  my $entry_count         = 1;
  my $column_count        = 1; # TODO - calculate this from number of entries
  my $column_width        = floor($image_config->image_width / $column_count);
  my $entries_per_column  = ceil(scalar(@{$data->{'entry_order'}}) / 2);

  foreach (@{$data->{'entry_order'}}) {
    my $entry   = $data->{'entries'}{$_};
    my $method  = 'draw_';

    my $x = ($entry_count % $column_count) * $column_width;
    my $position = {'x' => $x, 'y' => $y};

    if ($entry->{'shape'}) {
      $method .= $entry->{'shape'};
    }
    else {
      $method .= 'box';
      $position->{'height'} = $icon_height;
      $position->{'width'}  = $box_width;
    }

    $self->$method($entry, $position);
    ## Shift sideways to draw label
    $position->{'x'}    += $position->{'width'} + 2;
    $position->{'width'} = length($entry->{'text'});
    $self->draw_label($entry, $position);

    $y .= $icon_height + 2;
    $entry_count++;
  }
}

sub draw_label {
### Label for a legend entry
  my ($self, $entry, $position) = @_;

  my $params = {
                'colour' => 'black',
                'text'   => $entry->{'label'},
                %$position, 
                };

  push @{$self->glyphs}, $self->Text($params);
}

sub draw_box {
### Draw a basic legend entry - rectangular box
  my ($self, $entry, $position) = @_;

  my $params = {
                'colour' => $entry->{'colour'},
                %$position, 
                };

  push @{$self->glyphs}, $self->Rect($params);
}



1;
