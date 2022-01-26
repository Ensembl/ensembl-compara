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


package EnsEMBL::Draw::DrawableContainer;

### Base class for Ensembl genomic images in "horizontal" configuration
### i.e. with sequence and features running horizontally across the image
### Collects the individual glyphsets required for the image (e.g. tracks)
### and manages the overall image settings

use strict;

use EnsEMBL::Draw::Glyph::Rect;

use base qw(EnsEMBL::Root);

use JSON qw(to_json);
use List::Util qw(min);
use Time::HiRes qw(time);

# These colours from www.ColorBrewer.org -- 12 colour divergent
# by Cynthia A. Brewer, Geography, Pennsylvania State University.
# Copyright (c) 2002 Cynthia Brewer, Mark Harrower, and The Pennsylvania
# State University.
# Apache 2 license
our @section_colours = qw(#a6cee3 #1f78b4 #b2df8a #33a02c #fb9a99 #e31a1c
                         #fdbf6f #ff7f00 #cab2d6 #6a3d9a #ffff99 #b15928);

sub new {
  my $class           = shift;
  my $self            = $class->_init(@_); 
  my $primary_config  = $self->{'config'};
  return unless $primary_config;
  my $legend          = {};

  ## Enable caching between glyphsets - useful for campara views
  $self->{'feature_cache'} = {};
  
  ## Parameters used by private methods - easier to pass this way
  my $options = {
                  'image_width'     => $primary_config->get_parameter('image_width')    || 700,
                  'label_width'     => $primary_config->get_parameter('label_width')    || 100, 
                  'no_labels'       => $primary_config->get_parameter('no_labels'),
                  'colours'         => $primary_config->species_defs->colour('classes') || {},
                  'padding'         => $primary_config->get_parameter('padding')        || 0,
                  'margin'          => $primary_config->get_parameter('margin')         || 5,
                  'sortable_tracks' => $primary_config->get_parameter('sortable_tracks') eq 'drag',
                  'iteration'       => 0,
                  };
  
  ## Set some general spacing parameters 
  my $yoffset         = $options->{'margin'};
  my $inter_space     = $primary_config->get_parameter('intercontainer');
  $inter_space        = 2 * $options->{'margin'} unless defined $inter_space;
  $self->{'__extra_block_spacing__'} -= $inter_space;
  my $trackspacing    = $primary_config->get_parameter('spacing')        || 2;

  ## Loop through each pair of "container / config"s
  ## (comparative views, e.g. Location/Alignment, can have more than one slice in an image)
  foreach my $CC (@{$self->{'contents'}}) {
    my ($container, $config) = @$CC;
    
    if (!defined $container) {
      warn ref($self) . ' No container defined';
      next;
    }
    
    if (!defined $config) {
      warn ref($self) . ' No config object defined';
      next;
    }
   
    my $transform_obj = $self->_set_scaling($config, $container, $options); 
    
    ## Initiailize list of glyphsets for this configuration
    my $glyphsets = [];
    $container->{'web_species'} ||= $ENV{'ENSEMBL_SPECIES'};
    
    if ($config->get_parameter('text_export')) {
      $self->_create_glyphsets($glyphsets, $config, $container, $legend);
      $self->_do_export($glyphsets, $container);
    }
    else {

      ## pull out alternating background colours for this script
      my $bgcolours = [
        $config->get_parameter('bgcolour1') || 'background1',
        $config->get_parameter('bgcolour2') || 'background2'
      ];
    
      $bgcolours->[1]         = $bgcolours->[0] if $options->{'sortable_tracks'};
      my $bgcolour_flag       = $bgcolours->[0] ne $bgcolours->[1];
      $options->{'bgcolours'} = $bgcolours;
  
      ## Deal with comparative views with no alignment
      if (($container->{'__type__'} || '') eq 'fake') {
        $self->_create_fake_glyphset($glyphsets, $config, $container, $legend);
      } else {
        $self->_create_glyphsets($glyphsets, $config, $container, $legend);
      }
   
      $self->_prepare_glyphsets($glyphsets, $config, $options);

      ### The "section" is an optional multi-track label 
      ### with a coloured strip to group related tracks
      my $section = {
                          'colour'            => {},
                          'next_colour'       => 0,
                          'label_dedup'       => {},
                          'label_data'        => {},
                          'title_pending'     => 0,
                          };

      ## now draw the tracks!
      foreach my $glyphset (@$glyphsets) {

        ## Build the section first, as it may require more space than the track data
        $self->_build_section($glyphset, $section, $options);
        $section->{'height'} = $glyphset->section_height;

        ## load everything from the database and render the glyphset
        my $name         = $glyphset->{'my_config'}->id;
        my $ref_glyphset = ref $glyphset;
        #my $A = time();
        $glyphset->render;
        #my $B = time();
        #warn "$glyphset: ".($B-$A)."\n" if $B-$A>0.1;
        next if scalar @{$glyphset->{'glyphs'}} == 0; ## Glyphset is empty, e.g. no features
      
        ## remove any whitespace at the top of this row
        my $gminy = $glyphset->miny;
        $options->{'gminy'} = $gminy;
        $transform_obj->translatey(-$gminy + $yoffset + $section->{'height'} + $glyphset->subtitle_height);

        if ($bgcolour_flag && $glyphset->_colour_background) {
          $self->_colour_bg($glyphset, $options);
        }

        if($glyphset->use_subtitles) {
          ## Vertical position will need adjusting, so amend gminy
          $gminy = $self->_draw_subtitle($glyphset);
  
        }

        ## Now that we have both track height and section height, draw the top part of the section
        if($glyphset->section_text) {
          $self->_draw_section_top($glyphset, $section, $options);
        }

        if ($glyphset->label && !$options->{'no_labels'}) {
          $self->_draw_zmenu_link($glyphset, $config, $options);
        }

        if($glyphset->section) {
          $self->_draw_section_bottom($glyphset, $section, $options);
        }

        $glyphset->transform;
      
        ## translate the top of the next row to the bottom of this one
        $yoffset += $glyphset->height + $trackspacing;
      }
    
      push @{$self->{'glyphsets'}}, @$glyphsets;
    
      $yoffset += $inter_space;
      $self->{'__extra_block_spacing__'} += $inter_space;
      $config->{'panel_width'} = undef;
    }
  }

  return $self;
}

sub species_defs { return $_[0]->{'config'}->species_defs; }

sub _init {
  my $class = shift;
  my $Contents = shift;
  unless(ref($Contents) eq 'ARRAY') {
    $Contents = [[ $Contents, shift ]];
  } else {
    my $T = [];
    while( @$Contents ) {
      push @$T, [splice(@$Contents,0,2)] ;
    }
    $Contents = $T;
  }
  
  my( $highlights, $strandedness, $Storage) = @_;
  
  my $self = {
    'glyphsets'     => [],
    'config'        => $Contents->[0][1],
    'storage'       => $Storage,
    'prefix'        => 'EnsEMBL::Draw',
    'contents'      => $Contents,
    'highlights'    => $highlights || [],
    'strandedness'  => $strandedness || 0,
    '__extra_block_spacing__'    => 0,
  };
  
  bless( $self, $class );
  return $self;
}

sub _set_scaling {
  my ($self, $config, $container, $opts) = @_;

  my $w = $config->container_width;
  $w    = $container->length if !$w && $container->can('length');
      
  my $label_start     = $opts->{'margin'}; 
  my $panel_start     = $label_start + ($opts->{'no_labels'} ? 0 : $opts->{'label_width'} + $opts->{'margin'}) 
                                     + ($opts->{'sortable_tracks'} ? 10 : 0);
  my $panel_width     = $opts->{'image_width'} - $panel_start - $opts->{'margin'};
  my $x_scale         = $w ? $panel_width / $w : 1; 
                 
  ## Save this for later 
  $opts->{'panel_width'} = $panel_width;

  my $transform_obj = $config->transform_object;

  $transform_obj->scalex($x_scale); ## set scaling factor for base-pairs -> pixels
  $transform_obj->absolutescalex(1);
  $transform_obj->translatex($panel_start); ## because our label starts are < 0, translate everything back onto canvas

  $config->set_parameters({
                            panel_width        => $panel_width,
                            image_end          => ($panel_width + $opts->{'margin'} + $opts->{'padding'}) / $x_scale, # the right edge of the image, used to find labels which would be drawn too far to the right, and bring them back inside
                            __left_hand_margin => $panel_start - $label_start
  });
  return $transform_obj;
}

sub _create_fake_glyphset {
  my ($self, $glyphsets, $config, $container) = @_;

  my $classname = "$self->{'prefix'}::GlyphSet::comparafake";
  return unless $self->dynamic_use($classname);
      
  my $glyphset;
  eval { $glyphset = $classname->new($container, $config, $self->{'highlights'}, 1); };
  $config->container_width(1);
  push @$glyphsets, $glyphset unless $@;
}

sub _create_glyphsets {
  my ($self, $glyphsets, $config, $container, $legend) = @_;
 
  my %glyphset_ids;
  if ($config->get_parameter('text_export')) {
    $glyphset_ids{$_->id}++ for @{$config->glyphset_configs};
  }

  foreach my $row_config (@{$config->glyphset_configs}) {
    next if $row_config->get('matrix') eq 'column';
        
    my $display = $row_config->get('display') || ($row_config->get('on') eq 'on' ? 'normal' : 'off');
      
    if ($display eq 'default') {
      my $column_key = $row_config->get('column_key');
          
      if ($column_key) {
        my $column  = $config->get_node($column_key);
        $display    = $column->get('display') || ($column->get('on') eq 'on' ? 'normal' : 'off') if $column;
      }
    }

    next if $display eq 'off';
        
    my $option_key = $row_config->get('option_key');
        
    next if $option_key && $config->get_node($option_key)->get('display') ne 'on';
        
    my $strand = $row_config->get('drawing_strand') || $row_config->get('strand');
        
    next if ($self->{'strandedness'} || $glyphset_ids{$row_config->id} > 1) && $strand eq 'f';
        
    my $classname = "$self->{'prefix'}::GlyphSet::" . $row_config->get('glyphset');
    #warn ">>> GLYPHSET ".$row_config->get('glyphset');       
 
    next unless $self->dynamic_use($classname);
        
    my $glyphset;
        

    ## create a new glyphset for this row
    eval {
      $glyphset = $classname->new({
                      container   => $container,
                      config      => $config,
                      my_config   => $row_config,
                      strand      => $strand eq 'f' ? 1 : -1,
                      extra       => {},
                      highlights  => $self->{'highlights'},
                      display     => $display,
                      legend      => $legend,
                      feature_cache => $self->{'feature_cache'},
                  });
    };
        
    if ($@ || !$glyphset) {
      my $reason = $@ || 'No reason given just returns undef';
      warn "GLYPHSET: glyphset $classname failed at ", gmtime, "\n", "GLYPHSET: $reason";
    } else {
      push @$glyphsets, $glyphset;
    }
  }
}

sub _do_export {
### Render data as text rather than image
## TODO - replace text rendering with fetching features and passing to EnsEMBL::IO
  my ($self, $glyphsets, $container) = @_;

  my $config = $self->{'config'};
  my $export_cache;
    
  foreach my $glyphset (@$glyphsets) {
    my $name = $glyphset->{'my_config'}->id;
    eval {
          $glyphset->{'export_cache'} = $export_cache;
        
          my $text_export = $glyphset->render;
        
          if ($text_export) {
            # Add a header showing the region being exported
            if (!$self->{'export'}) {
            
              $self->{'export'} .= sprintf("Region:     %s\r\n", $container->name)                    if $container->can('name');
              $self->{'export'} .= sprintf("Gene:       %s\r\n", $config->core_object('gene')->long_caption)       if $ENV{'ENSEMBL_TYPE'} eq 'Gene';
              $self->{'export'} .= sprintf("Transcript: %s\r\n", $config->core_object('transcript')->long_caption) if $ENV{'ENSEMBL_TYPE'} eq 'Transcript';
              $self->{'export'} .= sprintf("Protein:    %s\r\n", $container->stable_id)               if $container->isa('Bio::EnsEMBL::Translation');
              $self->{'export'} .= "\r\n";
            }
          
            $self->{'export'} .= $text_export;
          }
        
          $export_cache = $glyphset->{'export_cache'};
    };
      
    ## don't waste any more time on this row if there's nothing in it
    if ($@ || scalar @{$glyphset->{'glyphs'}} == 0) {
      warn $@ if $@;
      next;
    }
  }
}

sub _prepare_glyphsets {
  my ($self, $glyphsets, $config, $opts) = @_;

  my %gang_data;

  foreach my $glyphset (@$glyphsets) {
   
    ## set the X-locations for each of the bump labels
    next unless defined $glyphset->label;
    my $img = $glyphset->label_img;
    my $img_width = 0;
    my $img_pad = 4;
    $img_width = $img->width + $img_pad if $img;

    my $text = $glyphset->label_text;
    $glyphset->recast_label(
                              $opts->{'label_width'} - $img_width, 
                              $glyphset->max_label_rows,
                              $text, 
                              $config->font_face || 'arial',
                              $config->font_size || 100,
                              $opts->{'colours'}{lc $glyphset->{'my_config'}->get('_class')}{'default'} || 'black'
                            );
    $glyphset->label->x(-$opts->{'label_width'} - $opts->{'margin'} + $img_width);
    $glyphset->label_img->x(-$opts->{'label_width'} - $opts->{'margin'} + $img_pad/2) if $img;
 
    ## Optionally, 'gang' the data, i.e. combine it between glyphsets for efficiency 
    my $gang = $glyphset->my_config('gang');
    next unless $gang;
    $gang_data{$gang} ||= {};
    $glyphset->gang_prepare($gang_data{$gang});
    $glyphset->gang($gang_data{$gang});
  }

}

sub _build_section {
  my ($self, $glyphset, $section, $opts) = @_;

  my $current_section = $section->{'current'};
  my $new_section     = $glyphset->section;
  my $section_zmenu   = $glyphset->section_zmenu;

  if ($new_section and $section_zmenu) {
    my $id = $section_zmenu->{'_id'};
    unless ($id and $section->{'label_dedup'}{$id}) {
      $section->{'label_data'}{$new_section} ||= [];
      push @{$section->{'label_data'}{$new_section}}, $section_zmenu;
      $section->{'label_dedup'}{$id} = 1 if $id;
    }
  }

  if($new_section ne $current_section) {
    $section->{'current'}        = $new_section;
    $section->{'title_pending'}  = $new_section;
  }
  if ($section->{'title_pending'} and not $glyphset->section_no_text) {
    $glyphset->section_text($section->{'title_pending'}, $opts->{'label_width'});
    $section->{'title_pending'} = undef;
  }

}

sub _draw_section_top {
  my ($self, $glyphset, $section, $opts) = @_;

  my $section_text = $glyphset->section_text;
  my $sx = -$opts->{'label_width'} - $opts->{'margin'};

  ## Prepare zmenu
  my $zmdata = $section->{'label_data'}{$section_text};
  my $url;
  if ($zmdata) {
    $url = $self->{'config'}->hub->url({
                                        type => 'ZMenu',
                                        action => 'Label',
                                        section => $section_text,
                                        zmdata => to_json($zmdata),
                                        zmcontext => to_json({
                                                        image_config => $self->{'config'}->type,
                                                      }),
                                        });
  }

  my $sec_colour = $section->{'colour'}{$section_text};
  unless($sec_colour) {
    $sec_colour = $section_colours[$section->{'next_colour'}];
    $section->{'colour'}{$section_text} = $sec_colour;
    $section->{'next_colour'}      = ($section->{'next_colour'} + 1) % @section_colours;
  }

  my $sec_off = -4;
  my @texts = @{$glyphset->section_lines};
  unshift @texts, ''; # top blank
  my $leading = 12;
  my $sec_off = $glyphset->miny - $section->{'height'};

  ## Main text of label
  foreach my $i (0..min(scalar(@texts)-1,2)) {
    $glyphset->push($glyphset->Text({
                                      font          => 'Arial',
                                      ptsize        => 8,
                                      height        => 8,
                                      text          => $texts[$i],
                                      colour        => 'black',
                                      x             => $sx,
                                      y             => $sec_off,
                                      width         => $opts->{'label_width'},
                                      halign        => 'left',
                                      absolutex     => 1,
                                      absolutewidth => 1,
                                      href          => $url,
                                      hover         => 1,
                                      alt           => $texts[$i],
                                      class         => "hoverzmenu",
                                      })
                    );
    $sec_off += $leading;
  }

  ## Horizontal coloured strip below main label
  $glyphset->push($glyphset->Rect({
                                    x             => $sx -4,
                                    y             => $sec_off - 2,
                                    width         => $opts->{'label_width'} - 4,
                                    height        => 2,
                                    absolutex     => 1,
                                    absolutey     => 1,
                                    absolutewidth => 1,
                                    colour        => $sec_colour,
                                    })
                  );
}

sub _draw_section_bottom {
  my ($self, $glyphset, $section, $opts) = @_;

  my $sec_colour      = $section->{'colour'}{$glyphset->section};
  my $band_min        = $glyphset->miny + $section->{'height'};
  ## For compatibility with new drawing code:
  my $total_height    = $glyphset->{'my_config'}->get('total_height') || 0;
  my $band_max        = ($glyphset->maxy && $glyphset->maxy > $glyphset->{'my_config'}->get('total_height')) 
                          ? $glyphset->maxy : $glyphset->{'my_config'}->get('total_height');
  my $diff            = $band_max - $band_min;
  my $fashionable_gap = 4;
  my $height          = $diff - 2 * $fashionable_gap;

  $glyphset->push($glyphset->Rect({
                                    x             => - ($opts->{'label_width'} + 9),
                                    y             => $band_min + $fashionable_gap, 
                                    width         => 2,
                                    height        => $height,
                                    absolutex     => 1,
                                    absolutewidth => 1,
                                    absolutey     => 1,
                                    colour        => $sec_colour,
                                    })
                    );

  if ($diff > $total_height) {
    $glyphset->{'my_config'}->set('total_height', $diff);
  }
}

sub _draw_zmenu_link {
  my ($self, $glyphset, $config, $opts) = @_;

  my $gh = $glyphset->label->height || $config->texthelper->height($glyphset->label->font);

  my ($miny,$maxy) = ($glyphset->miny,$glyphset->maxy);
  my $liney;
  $glyphset->label->y($opts->{'gminy'} + ($glyphset->{'label_y_offset'}||0));
  $liney = $opts->{'gminy'} + $gh + 1 + ($glyphset->{'label_y_offset'}||0);
  $glyphset->label->height($gh);
  $glyphset->push($glyphset->label);

  if($glyphset->label_img) {
    my ($miny,$maxy) = ($glyphset->miny,$glyphset->maxy);
    $glyphset->push($glyphset->label_img);
    $glyphset->miny($miny);
    $glyphset->maxy($maxy);
  }

  if ($glyphset->label->{'hover'}) {
    $glyphset->push($glyphset->Line({
                                      width         => $glyphset->label->width,
                                      x             => $glyphset->label->x,
                                      y             => $liney,
                                      colour        => '#336699',
                                      dotted        => 'small',
                                      absolutex     => 1,
                                      absolutey     => 1,
                                      absolutewidth => 1,
                                    })
                    );
  }
}

sub _colour_bg {
  my ($self, $glyphset, $opts) = @_;

  ## colour the area behind this strip
  my $background = EnsEMBL::Draw::Glyph::Rect->new({
            x             => -$opts->{'label_width'} - $opts->{'padding'} - $opts->{'margin'} * 3/2,
            y             => $opts->{'gminy'} - $opts->{'padding'},
            z             => -100,
            width         => $opts->{'panel_width'} + $opts->{'label_width'} 
                              + $opts->{'margin'} * 2 + (2 * $opts->{'padding'}),
            height        => $glyphset->maxy - $opts->{'gminy'} + (2 * $opts->{'padding'}),
            colour        => $opts->{'bgcolours'}[$opts->{'iteration'} % 2],
            absolutewidth => 1,
            absolutex     => 1,
  });
        
  # this accidentally gets stuffed in twice (for gif & imagemap) so with
  # rounding errors and such we shouldn't track this for maxy & miny values
  unshift @{$glyphset->{'glyphs'}}, $background;
        
  $opts->{'iteration'}++;
}

sub _draw_subtitle {
  my ($self, $glyphset) = @_;

  my $sh = $glyphset->subtitle_height();

   $glyphset->push($glyphset->Text({
                                      font      => 'Arial',
                                      text      => $glyphset->subtitle_text(),
                                      ptsize    => 8,
                                      height    => 8,
                                      colour    => $glyphset->subtitle_colour(),
                                      x         => 2,
                                      y         => $glyphset->miny - $sh + 6,
                                      halign    => 'left',
                                      absolutex => 1,
                                    })
                    );
  $glyphset->miny($glyphset->miny - $sh + 6);
  return $glyphset->miny;
}

## render does clever drawing things

sub render {
  my ($self, $type, $extra) = @_;
  
  ## build the name/type of render object we want
  my $renderer_type = qq(EnsEMBL::Draw::Renderer::$type);
  $self->dynamic_use( $renderer_type );
  ## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'__extra_block_spacing__'},
    $self->{'glyphsets'},
    $extra
  );
  my $canvas = $renderer->canvas();
  return $canvas;
}

sub config {
  my ($self, $Config) = @_;
  $self->{'config'} = $Config if(defined $Config);
  return $self->{'config'};
}

sub glyphsets {
  my ($self) = @_;
  return @{$self->{'glyphsets'}};
}

sub storage {
  my ($self, $Storage) = @_;
  $self->{'storage'} = $Storage if(defined $Storage);
  return $self->{'storage'};
}
1;

