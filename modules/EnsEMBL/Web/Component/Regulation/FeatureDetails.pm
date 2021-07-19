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

package EnsEMBL::Web::Component::Regulation::FeatureDetails;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Draw::Utils::ColourMap;
use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(1);
  $self->has_image(1);
}

sub content {
  my $self = shift;
  my $object = $self->object || $self->hub->core_object('regulation'); 
  my ($html, $Configs);

  my $context      = $self->param( 'context' ) || 200; 
  my $object_slice = $object->get_bound_context_slice($context);
     $object_slice = $object_slice->invert if $object_slice->strand < 1;

  my $wuc = $object->get_imageconfig( 'reg_summary_page' );
  $wuc->set_parameters({
    'container_width'   => $object_slice->length,
    'image_width',      => $self->image_width || 800,
    'slice_number',     => '1|1',
    'opt_highlight'     => $self->param('opt_highlight') || 0,
  });

  my $image    = $self->new_image( $object_slice, $wuc,[$object->stable_id] );
      $image->imagemap           = 'yes';
      $image->{'panel_number'} = 'top';
      $image->set_button( 'drag', 'title' => 'Drag to select region' );
  return if $self->_export_image( $image );

  $html .= $image->render;

  my $reg_feat = $object->fetch_by_stable_id;
  my $active_epigenomes = $reg_feat->get_epigenomes_by_activity('ACTIVE');
  my $num_active = scalar( @{$active_epigenomes});

  my $epigenome_count = 0;
  if ( $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $epigenome_count = grep { $_ > 0 } values %{$self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  }

  ## Now that we have so many cell lines, it's quicker to show activity in a table
  $html .= '<h3>Summary of Regulatory Activity
              <a title="Click to show or hide the table" rel="celltype_regfeature_table" href="#" class="toggle_link toggle new_icon open _slide_toggle">Hide</a>
            </h3>';

  ## We want one column per activity type, so get the data first
  my $data  = {}; 
  my $total = 0; 
  my $colours   = $self->hub->species_defs->colour('fg_regulatory_features');
  my $colourmap = EnsEMBL::Draw::Utils::ColourMap->new;
  my $epigenomes = $object->regbuild_epigenomes;

  foreach my $key (sort {lc $epigenomes->{$a} cmp lc $epigenomes->{$b}} keys %$epigenomes) {
    my $name = $epigenomes->{$key};
    my $activity = $object->activity($name) || 'UNKNOWN';
    $activity = ucfirst(lc($activity));
    my $colour_key = $activity;
    if ($activity eq 'Active') {
      $colour_key = $object->feature_type->name;
      $colour_key = "Promoter" if $colour_key eq 'Promoter Flanking Region';
    }
    my $tooltip = '';
    if ($activity eq 'Na') {
      $activity = 'N/A';
      $tooltip = 'Insufficient data available to predict activity level';
    }
    my $bg_colour = lc $colours->{lc($colour_key)}{'default'};
    ## Note - hex_by_name includes the hash symbol at the beginning
    my $contrast  = $bg_colour ? $colourmap->hex_by_name($colourmap->contrast($bg_colour)) : '#000000';
    if ($data->{$activity}) {
      $data->{$activity}{'colour'}    = $contrast;
      $data->{$activity}{'bg_colour'} = $bg_colour;
      $data->{$activity}{'tooltip'}   = $tooltip;
      push @{$data->{$activity}{'entries'}}, $name;
    }
    else {
      $data->{$activity} = {'entries' => [$name], 'colour' => $contrast, 'bg_colour' => $bg_colour, 'tooltip' => $tooltip};
    }
    $total++;
  }

  my $col_width = int(100 / scalar keys %$data);
  my (@columns, $row);
  foreach my $activity (sort keys %$data) {
    my $info = $data->{$activity};
    my $title = sprintf '%s (%s/%s)', $activity, scalar @{$info->{'entries'}}, $total;
    push @columns, {'key' => $activity, 'label' => helptip($title, $info->{'tooltip'}), 'width' => $col_width, 
                    'style' => sprintf 'color:%s;background-color:#%s', $info->{'colour'}, $info->{'bg_colour'}};
    $row->{$activity} = join('<br/>', @{$info->{'entries'}});
  }

  if (scalar @columns) {
    my $table = $self->new_table;
    $table->add_columns(@columns);
    $table->add_row($row);
    $html .= '<div class="toggleable celltype_regfeature_table">'. $table->render . '</div>';
  }
  else {
    $html .= '<p>No epigenomic data available for this feature.</p>';
  }
  return $html;
}

1;
