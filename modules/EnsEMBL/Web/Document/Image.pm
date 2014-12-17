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

package EnsEMBL::Web::Document::Image;

use strict;

use POSIX qw(ceil);
use JSON;
use HTML::Entities qw(encode_entities);

use EnsEMBL::Draw::VDrawableContainer;

use EnsEMBL::Web::File::Dynamic::Image;

sub new {
  my ($class, $hub, $component, $image_configs) = @_;

  my $self = {
    hub                => $hub,
    component          => $component,
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
  };

  if ($image_configs) {
    $self->{'toolbars'}{$_} = $image_configs->[0]->toolbars->{$_} for qw(top bottom);
  }

  bless $self, $class;
  return $self;
}

sub hub                :lvalue { $_[0]->{'hub'};                }
sub component          :lvalue { $_[0]->{'component'};          }
sub drawable_container :lvalue { $_[0]->{'drawable_container'}; }
sub centred            :lvalue { $_[0]->{'centred'};            }
sub imagemap           :lvalue { $_[0]->{'imagemap'};           }
sub button             :lvalue { $_[0]->{'button'};             }
sub button_id          :lvalue { $_[0]->{'button_id'};          }
sub button_name        :lvalue { $_[0]->{'button_name'};        }
sub button_title       :lvalue { $_[0]->{'button_title'};       }
sub image_type         :lvalue { $_[0]->{'image_type'};         }
sub image_name         :lvalue { $_[0]->{'image_name'};         }
sub introduction       :lvalue { $_[0]->{'introduction'};       }
sub tailnote           :lvalue { $_[0]->{'tailnote'};           }
sub caption            :lvalue { $_[0]->{'caption'};            }
sub format             :lvalue { $_[0]->{'format'};             }
sub toolbars           :lvalue { $_[0]->{'toolbars'};           }

sub image_width         { return $_[0]->{'image_configs'}[0]->get_parameter('image_width'); }
sub has_toolbars        { return 1 if ($_[0]->{'toolbars'}{'top'} || $_[0]->{'toolbars'}{'bottom'}); }
sub has_moveable_tracks { return $_[0]->drawable_container->{'config'}->get_parameter('sortable_tracks') eq 'drag'; }

sub render_toolbar {
  my ($self, $height) = @_;
  my $icon_mapping = EnsEMBL::Web::Constants::ICON_MAPPINGS('image');

  return unless $icon_mapping;

  my ($toolbar, $export, $top, $bottom, $image_resize, $image_sizes);
  my $hub         = $self->hub;
  my $component   = $self->component;
  my $viewconfig  = $hub->get_viewconfig($component);
  
  ## Config panel link
  if ($viewconfig) {
    my $config_url = $hub->url('Config', { action => $component, function => undef });
    my $data_url   = $hub->url({ type => 'UserData', action => 'ManageData', function => undef });
    my $share_url  = $hub->url('Share', { action => $component, function => undef, __clear => 1, create => 1, share_type => 'image', time => time });
    
    $toolbar .= sprintf '<a href="%s" class="config modal_link force" title="%s" rel="modal_config_%s"></a>', $config_url, $icon_mapping->{'config'}{'title'}, lc $component;
    $toolbar .= qq(<a href="$data_url" class="data modal_link" title="$icon_mapping->{'userdata'}{'title'}" rel="modal_user_data"></a>) if $self->{'image_configs'}[0]->get_node('user_data');
    $toolbar .= qq(<a href="$share_url" class="share popup" title="$icon_mapping->{'share'}{'title'}"></a>);
  }
  ## Increase/decrease image size icon  
  if (grep $_->image_resize, @{$self->{'image_configs'}}) {
    my $resize_url = $hub->url;
    
    # add best fit option
    $image_sizes .= qq(<div><a href="$resize_url" class="image_resize"><div>Best Fit</div></a></div>);
    
    # get current image_width and provide size of +- 100 three times    
    for (my $counter = ($self->image_width-300);$counter <= ($self->image_width+300); $counter+=100) {      
      my $selected_size = 'class="current"' if($counter eq $self->image_width);
      my $hidden_width = ($counter < 500) ? "style='display:none'" : '';      
      $image_sizes .= qq(<div $hidden_width><a href="$resize_url" class="image_resize"><div $selected_size>$counter px</div></a></div>);
    }
    
    $image_resize = qq(
       <div class="toggle image_resize_menu">
          <div class="header">Resize image to:</div>
          $image_sizes    
       </div>    
    );
    $toolbar   .= qq(<a href="$resize_url" class="resize popup" title="Resize this image"></a>);    
  }  
  ## Image export popup menu
  if ($self->{'export'}) {
    my @formats = (
      { f => 'pdf',     label => 'PDF'},
      { f => 'svg',     label => 'SVG' },
      { f => 'eps',     label => 'PostScript' },
      { f => 'png-5',   label => 'PNG (x5)' },
      { f => 'png-2',   label => 'PNG (x2)' },
      { f => 'png',     label => 'PNG' },
      { f => 'png-0.5', label => 'PNG (x0.5)' },
      { f => 'gff',     label => 'Text (GFF)', text => 1 }
    );
   
    splice @formats, 3, 0, { f => 'png-10',  label => 'PNG (x10)' } unless $height > 32000; ## PNG renderer will crash if image too tall!

    my $url  = $ENV{'REQUEST_URI'};
       $url  =~ s/;$//;
       $url .= ($url =~ /\?/ ? ';' : '?') . 'export=';

    foreach (@formats) {
      my $href = $url . $_->{'f'};

      if ($_->{'text'}) {
        next if $self->{'export'} =~ /no_text/;

        $export .= qq(<div><div>$_->{'label'}</div><a href="$href;download=1"><img src="/i/16/download.png" alt="download" title="Download" /></a></div>);
        
      } elsif ($_->{'f'} eq 'pdf') {
        # option not to include pdf export
        next if $self->{'export'} =~ /no_pdf/;
                
        $export .= qq(
          <div>
            <div>$_->{'label'}</div>
            <a class="view" href="$href" rel="external"><img src="/i/16/eye.png" alt="view" title="View image" /></a>
            <a href="$href;download=1"><img src="/i/16/download.png" alt="download" title="Download" /></a>
          </div>
        );
        
      } else {
        $export .= qq(
          <div>
            <div>$_->{'label'}</div>
            <a class="view" href="$href" rel="external"><img src="/i/16/eye.png" alt="view" title="View image" /></a>
            <a href="$href;download=1"><img src="/i/16/download.png" alt="download" title="Download" /></a>
          </div>
        );
      }
    }
    
    $export = qq(
      <div class="toggle iexport_menu">
        <div class="header">Export as:</div>
        $export
      </div>
    );
   
    $toolbar .= sprintf '<a href="%spdf" class="export popup %s" title="%s"></a>', $url, $self->{'export'}, $icon_mapping->{'image'}{'title'};
  }

  if ($self->{'data_export'}) {
    my $params = {
                   'type'      => 'DataExport', 
                   'action'    => $self->{'data_export'},
                   'data_type' => $hub->type,
                   'component' => $component,
                };
    foreach (@{$self->{'export_params'}||[]}) {
      if (ref($_) eq 'ARRAY') {
        $params->{$_->[0]} = $_->[1];
      }
      else {
        $params->{$_} = $hub->param($_);
      }
    }
    $toolbar .= sprintf '<a href="%s" class="download modal_link" title="%s"></a>', $hub->url($params), $icon_mapping->{'download'}{'title'};
  }

  if ($viewconfig) {
    $toolbar .= sprintf '<a href="%s" class="config-reset _reset" title="%s"></a>', $hub->url({qw(type Ajax action config_reset __clear 1)}), $icon_mapping->{'config_order'}{'title'};
  }

  if ($self->has_moveable_tracks) {
    $toolbar .= sprintf '<a href="%s" class="order-reset _reset" title="%s"></a>', $hub->url({qw(type Ajax action order_reset __clear 1)}), $icon_mapping->{'reset_order'}{'title'};
  }

  if ($toolbar) {
    $top    = $self->toolbars->{'top'} ? qq(<div class="image_toolbar top print_hide">$toolbar</div>$export$image_resize) : '';
    $bottom = ($self->toolbars->{'bottom'} || $height > 999) ? sprintf '<div class="image_toolbar bottom print_hide">%s</div>%s', $toolbar, $top ? '' : "$export$image_resize" : '';
  }

  return ($top, $bottom);
}


#----------------------------------------------------------------------------
# FUNCTIONS FOR CONFIGURING AND CREATING KARYOTYPE IMAGES
#----------------------------------------------------------------------------

sub karyotype {
  my ($self, $hub, $object, $highs, $config_name) = @_;
  my @highlights = ref($highs) eq 'ARRAY' ? @$highs : ($highs);

  $config_name ||= 'Vkaryotype';
  my $chr_name;

  my $image_config = $hub->get_imageconfig($config_name);
  
  # set some dimensions based on number and size of chromosomes
  if ($image_config->get_parameter('all_chromosomes') eq 'yes') {
    my $total_chrs = @{$hub->species_defs->ENSEMBL_CHROMOSOMES};
    my $rows       = $hub->param('rows') || ceil($total_chrs / 18);
    my $chr_length = $hub->param('chr_length') || 200;
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
  my @data        = @{$extra->{'features'}};
  my $species     = $hub->species;
  my $color       = lc($extra->{'color'} || $hub->param('col'))   || 'red';     # set sensible defaults
  my $style       = lc($extra->{'style'} || $hub->param('style')) || 'rharrow'; # set style before doing chromosome layout, as layout may need tweaking for some pointer styles
  my $high        = { style => $style };
  my ($p_value_sorted, $def_colour, $max);
  my $i = 1;
  
  # colour gradient 
  my @gradient = @{$extra->{'gradient'} || []};
  if ($color eq 'gradient' && scalar @gradient) {
    my @colour_scale = $hub->colourmap->build_linear_gradient(@gradient); # making an array of the colour scale

    foreach my $colour (@colour_scale) {
      $p_value_sorted->{$i} = $colour;
      $max = $i;
      $i = sprintf("%.1f", $i + 0.1);
    }
    
    $def_colour = 'black';
  }

  foreach my $row (@data) {
    my $chr         = $row->{'chr'} || $row->{'region'};
    my $grad_colour = $row->{'p_value'} > 10 
                    ? $p_value_sorted->{$max}
                    : $p_value_sorted->{sprintf("%.1f", $row->{'p_value'})};
    my $point = {
      start     => $row->{'start'},
      end       => $row->{'end'},
      id        => $row->{'label'},
      col       => $grad_colour || $def_colour || $color,
      href      => $row->{'href'},
      html_id   => $row->{'html_id'} || '',
    };

    push @{$high->{$chr}}, $point;
  }
  
  return $high;
}

sub set_button {
  my ($self, $type, %pars) = @_;
 
  $self->button           = $type;
  $self->{'button_id'}    = $pars{'id'}     if exists $pars{'id'};
  $self->{'button_name'}  = $pars{'id'}     if exists $pars{'id'};
  $self->{'button_name'}  = $pars{'name'}   if exists $pars{'name'};
  $self->{'URL'}          = $pars{'URL'}    if exists $pars{'URL'};
  $self->{'hidden'}       = $pars{'hidden'} if exists $pars{'hidden'};
  $self->{'button_title'} = $pars{'title'}  if exists $pars{'title'};
  $self->{'hidden_extra'} = $pars{'extra'}  if exists $pars{'extra'};
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
  
  my $url    = $image->url;
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
  my $self    = shift;
  my $hub     = $self->hub;
  my $sd      = $hub->species_defs;
  my $img_url = $sd->img_url;

  my ($html, %done);
  
  foreach my $label (map values %{$_->{'hover_labels'} || {}}, @{$self->{'image_configs'}}) {
    next if $done{$label->{'class'}};
    
    my $desc   = join '', map "<p>$_</p>", split /; /, $label->{'desc'};
    my $subset = $label->{'subset'};
    my $renderers;
    
    foreach (@{$label->{'renderers'}}) {
      my $text = $_->{'text'};
      
      if ($_->{'current'}) {
        $renderers .= qq(<li class="current"><img src="${img_url}render/$_->{'val'}.gif" alt="$text" title="$text" /><img src="${img_url}tick.png" class="tick" alt="Selected" title="Selected" /> $text</li>);
      } else {
        $renderers .= qq(<li><a href="$_->{'url'}" class="config" rel="$label->{'component'}"><img src="${img_url}render/$_->{'val'}.gif" alt="$text" title="$text" /> $text</a></li>);
      }
    }

    $label->{'conf_url'} = $sd->ENSEMBL_BASE_URL.$label->{'conf_url'} if $label->{'conf_url'};
    
    $renderers .= qq(<li class="subset subset_$subset->[0]"><a class="modal_link force" href="$subset->[1]#$subset->[0]" rel="$subset->[2]"><img src="${img_url}16/setting.png" /> Configure track options</a></li>) if $subset;
    $html      .= sprintf(qq(
      <div class="hover_label floating_popup %s">
        <p class="header">%s</p>
        <div class="hl-buttons">
          %s
          %s
          %s
          %s
          %s
        </div>
        <div class="hl-content">
          %s
          %s
          %s
          %s
          %s
        </div>
        <div class="spinner"></div>
      </div>),
      $label->{'class'},
      $label->{'header'},
      $label->{'desc'}     ? qq(<div class="_hl_icon hl-icon hl-icon-info active"></div>) : '',
      $renderers           ? qq(<div class="_hl_icon hl-icon hl-icon-setting"></div>) : '',
      $label->{'conf_url'} ? qq(<div class="_hl_icon hl-icon hl-icon-link"></div>) : '',
      $label->{'fav'}      ? sprintf(qq(<div class="_hl_icon hl-icon"><a href="$label->{'fav'}[1]" class="config favourite %s" rel="$label->{'component'}"></a></div>), $label->{'fav'}[0] ? 'selected' : '') : '',
      $label->{'off'}      ? qq(<div class="_hl_icon hl-icon"><a href="$label->{'off'}" class="config closetrack" rel="$label->{'component'}"></a></div>) : '',
      $label->{'desc'}     ? qq(<div class="_hl_tab hl-tab active">$desc</div>) : '',
      $renderers           ? qq(<div class="_hl_tab hl-tab config"><p>Change track style:</p><ul>$renderers</ul></div>) : '',
      $label->{'conf_url'} ? qq(<div class="_hl_tab hl-tab"><p>URL to turn this track on</p><p><input class="_copy_url" type="text" value="$label->{'conf_url'}" /></p><p>Copy the above url to force this track to be turned on</p></div>) : '',
      $label->{'fav'}      ? qq(<div class="_hl_tab hl-tab"><p>Click on the star to add/remove this track from your favourites</p></div>) : '',
      $label->{'off'}      ? qq(<div class="_hl_tab hl-tab"><p>Click on the cross to turn the track off</p></div>) : '',
    );
  }
  
  return $html;
}

sub track_boundaries {
  my $self            = shift;
  my $container       = $self->drawable_container;
  my $config          = $container->{'config'};
  my $spacing         = $config->get_parameter('spacing');
  my $top             = $config->get_parameter('margin') * 2 - $spacing;
  my @sortable_tracks = grep { $_->get('display') ne 'off' } $config->get_sortable_tracks;
  my %track_ids       = map  { $_->id => 1 } @sortable_tracks;
  my %strand_map      = ( f => 1, r => -1 );
  my @boundaries;
 
  my $prev_section; 
  foreach my $glyphset (@{$container->{'glyphsets'}}) {
    next unless scalar @{$glyphset->{'glyphs'}};

    my $height = $glyphset->height + $spacing + $glyphset->section_height;
    my $type   = $glyphset->type;
    my $node;  
    
    my $collapse = 0;
    my $this_section = $glyphset->section;
      
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
      if(!$this_section or !$prev_section or $this_section ne $prev_section) {
        push @boundaries, [ $top, $height, $type, $node->get('drawing_strand'), $node->get('order') ];
      } else {
        $boundaries[-1]->[1] += $height;
      }
    }
    
    $top += $height;
    $prev_section = $this_section;
  }

  return [ sort { ($a->[4] || 0) <=> ($b->[4] || 0) } @boundaries ];
}

sub moveable_tracks {
  my ($self, $image) = @_;
  my $config = $self->drawable_container->{'config'};
  
  return unless $self->has_moveable_tracks;
  
  my $species = $config->species;
  my $url     = $image->url;
  my ($top, $html);
  
  foreach (@{$self->track_boundaries}) {
    my ($t, $h, $type, $strand) = @$_;

    $html .= sprintf(
      '<li class="%s%s" style="height:%spx;background:url(%s) 0 %spx%s">
        <div class="handle" style="height:%spx"%s><p></p></div>
      </li>',
      $type, $strand ? " $strand" : '',
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
  my ($self, $format) = @_;

  return unless $self->drawable_container;

  if ($format) {
    print $self->drawable_container->render($format);
    return;
  }

  my $html    = $self->introduction;
  my $image   = EnsEMBL::Web::File::Dynamic::Image->new(
                                                        'hub'             => $self->hub,
                                                        'name_timestamp'  => 1,
                                                        'extension'       => 'png',
                                                        );
  my $content = $self->drawable_container->render('png');
  my $caption_style  = 'image-caption';

  $image->write($content);

  my ($top_toolbar, $bottom_toolbar) = $self->has_toolbars ? $self->render_toolbar($image->height) : ();
  
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
    $html .= qq(<input type="hidden" class="image_config" value="$self->{'image_configs'}[0]{'type'}" />);
    $html .= '<span class="hidden drop_upload"></span>' if $self->{'image_configs'}[0]->get_node('user_data');
  }
  
  $self->{'width'} = $image->width;
  $self->hub->species_defs->timer_push('Image->render ending', undef, 'draw');
  
  return $html;
}

1;
