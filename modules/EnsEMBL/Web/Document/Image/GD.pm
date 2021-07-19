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

package EnsEMBL::Web::Document::Image::GD;

### Wrapper around EnsEMBL::Web::Draw modules that create a raster image
### using Perl GD.

use strict;

use POSIX qw(ceil);
use JSON;
use HTML::Entities qw(encode_entities);

use EnsEMBL::Draw::VDrawableContainer;

use EnsEMBL::Web::File::Dynamic::Image;

use EnsEMBL::Web::Exceptions;

use parent qw(EnsEMBL::Web::Document::Image);

sub new {
  my ($class, $hub, $component, $image_configs, $args) = @_;

  $args = {
    image_configs      => $image_configs || [],
    drawable_container => undef,
    centred            => 0,
    imagemap           => 'no',
    image_type         => 'image',
    image_name         => undef,
    introduction       => undef,
    tailnote           => undef,
    caption            => undef,
    button_title       => undef,
    button_name        => undef,
    button_id          => undef,
    format             => 'png',
    %{$args || {}}
  };

  if ($image_configs) {
    $args->{'toolbars'}{$_} = $image_configs->[0]->get_parameter($_.'_toolbar') for qw(top bottom);
  }

  return $class->SUPER::new($hub, $component, $args);
}

sub drawable_container :lvalue { $_[0]->{'drawable_container'}; }

sub has_moveable_tracks { return $_[0]->drawable_container->{'config'}->get_parameter('sortable_tracks') eq 'drag'; }


#----------------------------------------------------------------------------
# FUNCTIONS FOR CONFIGURING AND CREATING KARYOTYPE IMAGES
#----------------------------------------------------------------------------

sub karyotype {
  my ($self, $hub, $object, $highs, $config_name) = @_;
  my @highlights = ref($highs) eq 'ARRAY' ? @$highs : ($highs);

  $config_name ||= 'Vkaryotype';
  my $chr_name;

  my $image_config = $hub->get_imageconfig($config_name);
  my $component = $self->component;
  
  # set some dimensions based on number and size of chromosomes
  if ($image_config->get_parameter('all_chromosomes') eq 'yes') {
    my $total_chrs = @{$hub->species_defs->ENSEMBL_CHROMOSOMES};
    my $rows       = $component->param('rows') || ceil($total_chrs / 18);
    my $chr_length = $component->param('chr_length') || 200;
       $chr_name   = 'ALL';

    if ($chr_length) {
      $image_config->set_parameters({
        image_height => $chr_length,
        image_width  => $chr_length + 25,
      });
    }
    
    $image_config->set_parameters({ 
      container_width => $hub->species_defs->MAX_CHR_LENGTH,
      rows            => $rows,
      slice_number    => '0|1',
    });
  } else {
    $chr_name = $object->seq_region_name if $object;
    
    my $seq_region_length = $object ? $object->seq_region_length : '';
    
    $image_config->set_parameters({
      container_width => $seq_region_length,
      slice_number    => '0|1'
    });
    
    $image_config->{'_rows'} = 1;
  }

  $image_config->{'_aggregate_colour'} = $hub->param('aggregate_colour') if $hub->param('aggregate_colour');

  # get some adaptors for chromosome data
  my ($sa, $ka, $da);
  my $species = $hub->param('species') || $hub->species;
  
  return unless $species;

  my $db = $hub->databases->get_DBAdaptor('core', $species);
  
  eval {
    $sa = $db->get_SliceAdaptor,
    $ka = $db->get_KaryotypeBandAdaptor,
    $da = $db->get_DensityFeatureAdaptor
  };
  
  return $@ if $@;

  # create the container object and add it to the image
  $self->drawable_container = EnsEMBL::Draw::VDrawableContainer->new({
    web_species => $species,
    sa          => $sa,
    ka          => $ka,
    da          => $da,
    chr         => $chr_name,
    format      => $hub->param('export')
  }, $image_config, \@highlights) if($hub->param('_format') ne 'Excel');

  return undef; # successful
}

sub add_pointers {
  my ($self, $hub, $extra) = @_;

  my $config_name = $extra->{'config_name'};
  my @data        = @{$extra->{'features'}||[]};
  my $species     = $hub->species;
  my $style       = lc($extra->{'style'} || $hub->param('style')) || 'rharrow'; # set style before doing chromosome layout, as layout may need tweaking for some pointer styles
  my $high        = { style => $style };
  my $default_colour = lc($extra->{'color'} || $hub->param('col'))   || 'red';     # set sensible defaults
  my ($p_value_sorted, $max);
  my $i = 1;
  
  # colour gradient 
  my @gradient = @{$extra->{'gradient'} || []};
  if ($default_colour eq 'gradient' && scalar @gradient) {
    $default_colour = 'black';

    my @colour_scale = $hub->colourmap->build_linear_gradient(@gradient); # making an array of the colour scale

    foreach my $colour (@colour_scale) {
      $p_value_sorted->{$i} = $colour;
      $max = $i;
      $i = sprintf("%.1f", $i + 0.1);
    }
    
  }

  foreach my $row (@data) {
    my $chr         = $row->{'chr'} || $row->{'seq_region'} || $row->{'region'};
    ## Stringify any RGB colour arrays
    my $item_colour = $row->{'colour'};
    unless ($item_colour) {
      $item_colour = ref($row->{'item_colour'}) eq 'ARRAY' 
                        ? join(',', @{$row->{'item_colour'}}) : $row->{'item_colour'};
    }
    my $grad_colour;
    if (defined($row->{'p_value'})) {
      $grad_colour = $row->{'p_value'} > 10 
                      ? $p_value_sorted->{$max}
                      : $p_value_sorted->{sprintf("%.1f", $row->{'p_value'})};
    }
    my $href = $row->{'href'};
    if (!$href && $extra->{'zmenu'}) {
      $href = {'type' => 'ZMenu', 'action' => $extra->{'zmenu'},
                        'config' => $extra->{'config_name'}, 'track' => $extra->{'track'},
                        'fake_click_chr' => $chr, 'fake_click_start' => $row->{'start'}, 
                        'fake_click_end' => $row->{'end'},
                        };
    }
    if (ref($href) eq 'HASH') {
      $href = $hub->url({$config_name ? ('config' => $config_name) : (), %$href});
    }
    else {
      ## Hack to get correct zmenu
      $href =~ s/\/UserData/\/VUserData/;
      if ($config_name && $href =~ /$config_name/) {
        $href .= ';config='.$config_name;
      }
    }
    my $point = {
      start     => $row->{'start'},
      end       => $row->{'end'},
      id        => $row->{'label'},
      col       => $item_colour || $grad_colour || $default_colour,
      href      => $href || '', 
      html_id   => $row->{'html_id'} || '',
    };

    push @{$high->{$chr}}, $point;
  }
  
  return $high;
}


####################################################################################################
#
# Renderers
#
####################################################################################################

# Having a usemap causes drag selecting to become a real pain, so disabled
sub extra_html {
  my $self  = shift;
  my $class =  'imagemap' . ($self->drawable_container->isa('EnsEMBL::Draw::VDrawableContainer') ? ' vertical' : '');
  my $extra = qq(class="$class");

#  if ($self->imagemap eq 'yes') {
#    my $map_name = $self->{'token'};
#    $extra .= qq(usemap="#$map_name" );
#  }
  
  return $extra;
}

sub extra_style {
  my $self = shift;
  return $self->{'border'} ? sprintf('border: %s %dpx %s;', $self->{'border_colour'} || '#000', $self->{'border'}, $self->{'border_style'} || 'solid') : '';
}

sub render_image_tag {
  my ($self, $image) = @_;
  
  my $url    = $image->read_url;
  my $width  = $image->width;
  my $height = $image->height;
  my $html;

  if ($width > 5000) {
    $html = qq{
       <p style="text-align:left">
         The image produced was $width pixels wide,
         which may be too large for some web browsers to display.
         If you would like to see the image, please right-click (MAC: Ctrl-click)
         on the link below and choose the 'Save Image' option from the pop-up menu.</p>
       <p><a href="$url">Image download</a></p>
    };
  } else {
    $html = sprintf(
      '<img src="%s" alt="" style="width: %dpx; height: %dpx; %s display: block" %s />',
      $url,
      $width,
      $height,
      $self->extra_style,
      $self->extra_html
    );

    $self->{'width'}  = $width;
    $self->{'height'} = $height;
  }

  return $html;
} 

sub render_image_button {
  my ($self, $image) = @_;

  return sprintf(
    '<input style="width: %dpx; height: %dpx; %s display: block" type="image" name="%s" src="%s" alt="%s" title="%s" %s />',
    $image->width,
    $image->height,
    $self->extra_style,
    $self->{'button_name'},
    $image->URL,
    $self->{'button_title'},
    $self->{'button_title'}
  );
} 

sub render_image_map {
  my ($self, $image) = @_;

  my $imagemap = encode_entities(encode_json($self->drawable_container->render('imagemap')));
  my $map_name;

  my $map = qq(
    <div class="json_$map_name json_imagemap" style="display: none">
      $imagemap
    </div>
  );
  
  $map .= '<input type="hidden" class="panel_type" value="ImageMap" />';
  
  return $map;
}

sub hover_labels {
  my $self = shift;
  my $html = '';

  foreach my $label (map values %{$_->{'hover_labels'} || {}}, @{$self->{'image_configs'}}) {
    my ($buttons, $contents) = $self->hover_label_tabs($label);
    $html .= sprintf(qq(
      <div class="hover_label floating_popup %s %s">
        <p class="header _hl_pin"><span class="hl-pin"></span><span class="_track_menu_header">%s</span><span class="_hl_extend hl-extend"></span></p>
        <div class="hl-buttons">%s</div>
        <div class="hl-content">%s</div>
        <div class="spinner"></div>
        <span class="close"></span>
      </div>),
      $label->{'class'},
      $label->{track_highlight}[1] ? '_hl_on' : '',
      $label->{'header'},
      join('', @$buttons),
      join('', @$contents)
    );
  }

  return $html;
}

sub hover_label_tabs {
  my ($self, $label) = @_;

  my $sd      = $self->hub->species_defs;
  my $img_url = $sd->img_url;
  my $desc    = join '', map "<p>$_</p>", split /; /, $label->{'desc'};
     $desc   .= $label->{'extra_desc'};
  my $subset  = $label->{'subset'};
  my $renderers;
  my $highlight = ($self->hub->type =~m/Location|Gene/ && $self->hub->action =~/Multi|Variation_Gene/) ? 0 : 1;

  foreach (@{$label->{'renderers'}}) {

    $renderers .= sprintf q(<li class="%s%s"><a href="%s" class="config" rel="%s"><img src="%srender/%2$s.gif" alt="%s" title="%6$s" />%s %6$s</a></li>),
      $_->{'current'} ? 'current ' : '',
      $_->{'val'},
      $_->{'url'},
      $label->{'component'},
      $img_url,
      $_->{'text'},
      $_->{'current'} ? qq(<img src="${img_url}tick.png" class="tick" alt="Selected" title="Selected" />) : '';
  }

  ## Horrible hack to fix file attachment
  if ($label->{'conf_url'}) {
    if ($label->{'conf_url'} =~ /contigviewbottom=url_/) {
      $label->{'conf_url'} =~ /(url_[\w]+)/;
      my $track_id = $1;
      (my $code = $track_id) =~ s/^url_//;
      my $record = $self->hub->session->get_record_data({'type' => 'url', 'code' => $code});
      my $url = $record->{'url'};
      (my $new_link = $label->{'conf_url'}) =~ s/$track_id/url:$url/;
      $label->{'conf_url'} = $new_link;
    }
    elsif ($label->{'conf_url'} =~ /contigviewbottom=trackhub_/) {
      $label->{'conf_url'} = undef;
    }
  }

  $label->{'conf_url'} = $sd->ENSEMBL_BASE_URL.$label->{'conf_url'} if $label->{'conf_url'};

  $renderers .= qq(<li class="subset subset_$subset->[0]"><a class="modal_link force" href="$subset->[1]#$subset->[0]" rel="$subset->[2]"><img src="${img_url}16/setting.png" /> Configure track options</a></li>) if $subset;

  my (@buttons, @contents);

  if ($label->{'desc'}) {
    push @buttons, qq(<div class="_hl_icon hl-icon hl-icon-info active"></div>);
    push @contents, qq(<div class="_hl_tab hl-tab active">$desc</div>);
  }

  if ($renderers) {
    push @buttons, qq(<div class="_hl_icon hl-icon hl-icon-setting"></div>);
    push @contents, qq(<div class="_hl_tab hl-tab config"><p>Change track style:</p><ul>$renderers</ul></div>);
  }

  if ($label->{'scaleable'}) {
    my $url     = $label->{'scaleable'};
    my $y_min   = $label->{'y_min'};
    my $y_max   = $label->{'y_max'};
    my $config  = $label->{'component'};
    my $track   = $label->{'track'};
    my $axis_form = qq(<form action="$url" method="POST" class="freeform graph_config">
<p><label for="y_min">Minimum: <input name="y_min" type="text" value="$y_min" class="small" /></p>
<p><label for="y_max">Maximum: <input name="y_max" type="text" value="$y_max" class="small" /></p>
<p>(Tip: set both fields to blank to use the full range of values)</p>
<input type="hidden" name="config" value="$config">
<input type="hidden" name="track" value="$track">
<input type="submit" value="Update" class="small button" />
</form>);

    push @buttons, qq(<div class="_hl_icon hl-icon hl-icon-scale"></div>);
    push @contents, qq(<div class="_hl_tab hl-tab"><p>Change Y axis limits:</p>$axis_form</div>);
  }

  if ($label->{'conf_url'}) {
    push @buttons, qq(<div class="_hl_icon hl-icon hl-icon-link"></div>);
    push @contents, qq(<div class="_hl_tab hl-tab"><p>URL to turn this track on</p><p><input class="_copy_url" type="text" value="$label->{'conf_url'}" /></p><p>Copy the above url to force this track to be turned on</p></div>);
  }

  if ($label->{'fav'}) {
    push @buttons, sprintf(qq(<div class="_hl_icon hl-icon"><a href="$label->{'fav'}[1]" class="config favourite %s" rel="$label->{'component'}"></a></div>), $label->{'fav'}[0] ? 'selected' : '');
    push @contents, qq(<div class="_hl_tab hl-tab"><p>Click on the star to add/remove this track from your favourites</p></div>);
  }

  if ($label->{'off'}) {
    my $classes = 'config closetrack';
    $classes .= ' matrix-cell' if $label->{'matrix_cell'};
    push @buttons, qq(<div class="_hl_icon hl-icon"><a href="$label->{'off'}" class="$classes" rel="$label->{'component'}"></a></div>);
    push @contents, qq(<div class="_hl_tab hl-tab"><p>Click on the cross to turn the track off</p></div>);
  }

  if ($highlight) {
    push @buttons, sprintf(qq(<div class="_hl_icon hl-icon"><a class="config hl-icon-highlight %s" href="$label->{'track_highlight'}[2]" rel="$label->{'component'}" data-highlight-track="$label->{'track_highlight'}[0]"></a></div>), $label->{'track_highlight'}[1] ? 'selected' : '');
    push @contents, qq(<div class="_hl_tab hl-tab"><p>Click to highlight/unhighlight this track</p></div>);
  }

  return (\@buttons, \@contents);
}

sub track_boundaries {
  my $self            = shift;
  my $container       = $self->drawable_container;
  my $config          = $container->{'config'};
  my $spacing         = $config->get_parameter('spacing');
  my $top             = $config->get_parameter('margin') * 2 - $spacing;
  my @sortable_tracks = $config->get_sortable_tracks(1);
  my %track_ids       = map  { $_->id => 1 } @sortable_tracks;
  my %strand_map      = ( f => 1, r => -1 );
  my @boundaries;
  my $prev_section; 
  foreach my $glyphset (@{$container->{'glyphsets'}}) {
    next unless scalar @{$glyphset->{'glyphs'}};
    my $height = $glyphset->height + $spacing;
    my $type   = $glyphset->type;
    my $track_highlight = $config->is_track_highlighted($type);
    my $node;  
    my $collapse = 0;
      
    if ($track_ids{$type}) {
      while (scalar @sortable_tracks) {
        my $track  = $sortable_tracks[0];
        my $strand = $track->get('drawing_strand');
        
        last if $type eq $track->id && (($strand && $strand_map{$strand} == $glyphset->strand) || !$strand);
        shift @sortable_tracks;
      }
      
      $node = shift @sortable_tracks;
    }
    
    if($node && $node->get('sortable') && !scalar keys %{$glyphset->{'tags'}}) {
      push @boundaries, [ $top, $height, $type, $node->get('drawing_strand'), $track_highlight, $node->get('order') ];
    }
    
    $top += $height;
  }

  return [ sort { ($a->[5] || 0) <=> ($b->[5] || 0) } @boundaries ];
}

sub moveable_tracks {
  my ($self, $image) = @_;
  my $config = $self->drawable_container->{'config'};
  
  return unless $self->has_moveable_tracks;
  
  my $species = $config->species;
  my $url     = $image->read_url;
  my ($top, $html);
  
  # Get latest uploaded user data to add highlight class
  my $last_uploaded_user_data_code = {};
  my $userdata_session_records = $self->hub->session->records({'type' => 'userdata_upload_code'});

  for (@{$userdata_session_records}) {
    # Create a map of all upload_codes
    $last_uploaded_user_data_code->{$_->data->{'upload_code'}} = 1;
  }

  # Purge this data so that it doesn't highlight second time.
  $self->hub->session->delete_records($userdata_session_records);

  foreach (@{$self->track_boundaries}) {
    my ($t, $h, $type, $strand, $track_hl) = @$_;
    # For highlight, upload_ and url_ prefixes are not there in the session data.
    # So split remove and then compare
    my ($record_type, $code) = split(/_/,$type, 2);
    my $highlight = $last_uploaded_user_data_code->{$code} || 0;

    $html .= sprintf(
      '<li class="%s %s %s %s" style="height:%spx;background:url(%s) 0 %spx%s">
        <div class="handle" style="height:%spx"%s><p></p></div>
      </li>',
      $type, $strand ? "$strand" : '',
      $highlight ? '_new_userdata usertrack_highlight' : '',
      $track_hl ? 'track_highlight' : '',
      $h, $url, 3 - $t,
      $h == 0 ? ';display:none' : '',
      $h - 1,
      $strand ? sprintf(' title="%s strand"', $strand eq 'f' ? 'Forward' : 'Reverse') : ''
    );

    $top ||= $t - 3 if $h;
  }

  return qq(<div class="boundaries_wrapper" style="top:${top}px"><ul class="$species boundaries">$html</ul></div>) if $html;
}

sub render {
  my ($self, $format, $drivers) = @_;
  $format ||= 'png';

  return unless $self->drawable_container;

  my $hub = $self->hub;
  my $image;
  my $filename = $hub->param('filename');

  if ($filename) {
    $image = EnsEMBL::Web::File::Dynamic::Image->new(
                                                      'hub'             => $hub,
                                                      'name'            => $hub->param('filename'),
                                                      'output_drivers'  => $drivers,
                                                      );
  }
  else {
    $image = EnsEMBL::Web::File::Dynamic::Image->new(
                                                      'hub'             => $hub,
                                                      'name_timestamp'  => 1,
                                                      'extension'       => 'png',
                                                      'output_drivers'  => $drivers,
                                                      );
  }
  my $content = $self->drawable_container->render($format, from_json($self->hub->param('extra') || "{}"));

  my $result = $image->write($content);

  if (!$result || !$result->{'success'}) {
    throw exception('WebException', $result && $result->{'error'} && $result->{'error'}[0] || 'Unable to write image file');
  }

  if ($filename || ($hub->param('submit') && $hub->param('submit') eq 'Download' && !$filename)) {
    ## User export, so we need to know where the file was written to
    return $image->write_location;
  }

  ## Not user export, so render image wrapped in HTML
  my $html            = $self->introduction;
  my $caption_style   = 'image-caption';
  $self->height = $image->height;

  my ($top_toolbar, $bottom_toolbar) = $self->has_toolbars ? $self->render_toolbar : ();
  
  if ($self->button eq 'form') {
    my $image_html = $self->render_image_button($image);
    my $inputs;
    
    $self->{'hidden'}{'total_height'} = $image->height;
    
    $image_html .= sprintf '<div class="%s">%s</div>', $caption_style, $self->caption if $self->caption;
    
    foreach (keys %{$self->{'hidden'}}) {
      $inputs .= sprintf(
        '<input type="hidden" name="%s" id="%s%s" value="%s" />', 
        $_, 
        $_, 
        $self->{'hidden_extra'} || $self->{'counter'}, 
        $self->{'hidden'}{$_}
      );
    }
    
    $html .= sprintf(
      $self->centred ? 
        '<div class="autocenter_wrapper"><form style="width:%spx" class="autocenter" action="%s" method="get"><div>%s</div><div class="autocenter">%s</div></form></div>' : 
        '<form style="width:%spx" action="%s" method="get"><div>%s</div>%s%s%s</form>',
      $image->width,
      $self->{'URL'},
      $inputs,
      $top_toolbar,
      $image_html,
      $bottom_toolbar,
    );

    $self->{'counter'}++;
  } elsif ($self->button eq 'yes') {
    $html .= $self->render_image_button($image);
    $html .= sprintf '<div class="%s">%s</div>', $caption_style, $self->caption if $self->caption;
  } elsif ($self->button eq 'drag') {
    my $img = $self->render_image_tag($image);

    # continue with tag html
    # This has to have a vertical padding of 0px as it is used in a number of places
    # butted up to another container - if you need a vertical padding of 10px add it
    # outside this module
    
    my $wrapper = sprintf('
      %s
      <div class="drag_select" style="margin:%s;">
        %s
        %s
        %s
        %s
      </div>
      %s',
      $top_toolbar,
      $self->centred ? '0px auto' : '0px',
      $img,
      $self->imagemap eq 'yes' ? $self->render_image_map($image) : '',
      $self->moveable_tracks($image),
      $self->hover_labels,
      $bottom_toolbar,
    );

    my $template = $self->centred ? '
      <div class="image_container" style="width:%spx;text-align:center">
        <div style="text-align:center;margin:auto">
          %s
          %s
        </div>
      </div>
    ' : '
      <div class="image_container" style="width:%spx">
        %s
        %s
      </div>
        %s
    ';
 
    $html .= sprintf $template, $image->width, $wrapper, $self->caption ? sprintf '<div class="%s">%s</div>', $caption_style, $self->caption : '';
  
  } else {
    $html .= join('',
      $self->render_image_tag($image),
      $self->imagemap eq 'yes' ? $self->render_image_map($image) : '',
      $self->moveable_tracks($image),
      $self->hover_labels,
      $self->caption ? sprintf('<div class="%s">%s</div>', $caption_style, $self->caption) : ''
    );
  }

  $html .= $self->tailnote;
  
  if ($self->{'image_configs'}[0]) {
    if (my $component = $self->component) {
      if (my $view_config = $component->viewconfig) {
        $html .= sprintf q(<input type="hidden" class="view_config" value="%s" />), $view_config->code;
      }
    }

    $html .= qq(<input type="hidden" class="image_config" value="$self->{'image_configs'}[0]{'type'}" />);
    $html .= '<span class="hidden drop_upload"></span>' if $self->{'image_configs'}[0]->get_node('user_data');
  }
  
  $self->{'width'} = $image->width;
  
  return $html;
}

1;
