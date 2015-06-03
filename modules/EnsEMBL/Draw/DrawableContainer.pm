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

# These colours from www.ColorBrewer.org -- 12 colour divergent
# by Cynthia A. Brewer, Geography, Pennsylvania State University.
# Copyright (c) 2002 Cynthia Brewer, Mark Harrower, and The Pennsylvania
# State University.
# Apache 2 license
my @section_colours = qw(#a6cee3 #1f78b4 #b2df8a #33a02c #fb9a99 #e31a1c
                         #fdbf6f #ff7f00 #cab2d6 #6a3d9a #ffff99 #b15928);

sub new {
  my $class           = shift;
  my $self            = $class->_init(@_); 
  my $primary_config  = $self->{'config'};
  my $sortable_tracks = $primary_config->get_parameter('sortable_tracks') eq 'drag';
  my $show_labels     = $primary_config->get_parameter('show_labels')    || 'yes';
  my $label_width     = $primary_config->get_parameter('label_width')    || 100;
  my $margin          = $primary_config->get_parameter('margin')         || 5;
  my $padding         = $primary_config->get_parameter('padding')        || 0;
  my $trackspacing    = $primary_config->get_parameter('spacing')        || 2;
  my $image_width     = $primary_config->get_parameter('image_width')    || 700;
  my $colours         = $primary_config->species_defs->colour('classes') || {};
  my $label_start     = $margin;
  my $panel_start     = $label_start + ($show_labels  eq 'yes' ? $label_width  + $margin : 0) + ($sortable_tracks ? 10 : 0);
  my $panel_width     = $image_width - $panel_start - $margin;
  my $yoffset         = $margin;
  my $iteration       = 0;
  my $legend          = {};
  my $inter_space     = $primary_config->get_parameter('intercontainer');
     $inter_space     = 2 * $margin unless defined $inter_space;
  
  $self->{'__extra_block_spacing__'} -= $inter_space;
  
  ## Loop through each pair of "container / config"s
  foreach my $CC (@{$self->{'contents'}}) {
    my ($container, $config) = @$CC;
    
    ## If either Container or Config not present skip
    if (!defined $container) {
      warn ref($self) . ' No container defined';
      next;
    }
    
    if (!defined $config) {
      warn ref($self) . ' No config object defined';
      next;
    }
    
    my $w = $config->container_width;
       $w = $container->length if !$w && $container->can('length');
       
    my $x_scale = $w ? $panel_width /$w : 1; 
    
    $config->{'transform'}->{'scalex'}         = $x_scale; ## set scaling factor for base-pairs -> pixels
    $config->{'transform'}->{'absolutescalex'} = 1;
    $config->{'transform'}->{'translatex'}     = $panel_start; ## because our label starts are < 0, translate everything back onto canvas
    
    $config->set_parameters({
      panel_width        => $panel_width,
      image_end          => ($panel_width + $margin + $padding) / $x_scale, # the right edge of the image, used to find labels which would be drawn too far to the right, and bring them back inside
      __left_hand_margin => $panel_start - $label_start
    });
    
    ## Initiailize list of glyphsets for this configuration
    my @glyphsets;
    
    $container->{'web_species'} ||= $ENV{'ENSEMBL_SPECIES'};
    
    if (($container->{'__type__'} || '') eq 'fake') {
      my $classname = "$self->{'prefix'}::GlyphSet::comparafake";
      
      next unless $self->dynamic_use($classname);
      
      my $glyphset;
      
      eval { $glyphset = $classname->new($container, $config, $self->{'highlights'}, 1); };
      
      $config->container_width(1);
      
      push @glyphsets, $glyphset unless $@;
    } else {
      my %glyphset_ids;
      
      if ($config->get_parameter('text_export')) {
        $glyphset_ids{$_->id}++ for @{$config->glyphset_configs};
      }
      
      ## This is much simplified as we just get a row of configurations
      foreach my $row_config (@{$config->glyphset_configs}) {
        next if $row_config->get('matrix') eq 'column';
        
        my $display = $row_config->get('display') || ($row_config->get('on') eq 'on' ? 'normal' : 'off');
        
        if ($display eq 'default') {
          my $column_key = $row_config->get('column_key');
          
          if ($column_key) {
            my $column  = $config->get_node($column_key);
               $display = $column->get('display') || ($column->get('on') eq 'on' ? 'normal' : 'off') if $column;
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
          });
        };
        
        if ($@ || !$glyphset) {
          my $reason = $@ || 'No reason given just returns undef';
          warn "GLYPHSET: glyphset $classname failed at ", gmtime, "\n", "GLYPHSET: $reason";
        } else {
          push @glyphsets, $glyphset;
        }
      }
    }
   
    ## Factoring out export - no need to do any drawing-related munging for that, surely?
    ## TODO - replace text rendering with fetching features and passing to EnsEMBL::IO
    if ($config->get_parameter('text_export')) {
      my $export_cache;
    
      foreach my $glyphset (@glyphsets) {
        my $name         = $glyphset->{'my_config'}->id;
        eval {
          $glyphset->{'export_cache'} = $export_cache;
        
          my $text_export = $glyphset->render;
        
          if ($text_export) {
            # Add a header showing the region being exported
            if (!$self->{'export'}) {
              my $container = $glyphset->{'container'};
              my $config    = $self->{'config'};
            
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
        
          $self->timer_push('track finished', 3);
          $self->timer_push(sprintf("INIT: [ ] $name '%s'", $glyphset->{'my_config'}->get('name')), 2);
          next;
        }
      }
    }
    else {
      ## set the X-locations for each of the bump labels

      my $section = '';
      my (%section_label_data,%section_label_dedup,$section_title_pending);
      my (%section_colour);
      foreach my $glyphset (@glyphsets) {
        next unless defined $glyphset->label;
        my $img = $glyphset->label_img;
        my $img_width = 0;
        my $img_pad = 4;
        $img_width = $img->width+$img_pad if $img;

        my $text = $glyphset->label_text;
        $glyphset->recast_label(
            $label_width-$img_width,$glyphset->max_label_rows,
            $text,$config->{'_font_face'} || 'arial',
            $config->{'_font_size'} || 100,
            $colours->{lc $glyphset->{'my_config'}->get('_class')}
                      {'default'} || 'black'
        );
        $glyphset->label->x(-$label_width - $margin + $img_width);
        $glyphset->label_img->x(-$label_width - $margin + $img_pad/2) if $img;
      }
    
      ## pull out alternating background colours for this script
      my $bgcolours = [
        $config->get_parameter('bgcolour1') || 'background1',
        $config->get_parameter('bgcolour2') || 'background2'
      ];
    
      $bgcolours->[1] = $bgcolours->[0] if $sortable_tracks;
    
      my $bgcolour_flag = $bgcolours->[0] ne $bgcolours->[1];

      my %gang_data;
      foreach my $glyphset (@glyphsets) {
        my $gang = $glyphset->my_config('gang');
        next unless $gang;
        $gang_data{$gang} ||= {};
        $glyphset->gang_prepare($gang_data{$gang});
        $glyphset->gang($gang_data{$gang});
      }

      ## go ahead and do all the database work
      $self->timer_push('GlyphSet list prepared for config ' . ref($config), 1);

      my $next_section_col = 0;
      foreach my $glyphset (@glyphsets) {
        ## load everything from the database
        my $name         = $glyphset->{'my_config'}->id;
        my $ref_glyphset = ref $glyphset;
        # NB: we guarantee render will always be called before the
        #       subititle_* methods.
        $glyphset->render;
        next if scalar @{$glyphset->{'glyphs'}} == 0;
        my $new_section = $glyphset->section;
        my $section_zmenu = $glyphset->section_zmenu;
        if($new_section and $section_zmenu) {
          my $id = $section_zmenu->{'_id'};
          unless($id and $section_label_dedup{$id}) {
            $section_label_data{$new_section} ||= [];
            push @{$section_label_data{$new_section}},$section_zmenu;
            $section_label_dedup{$id} = 1 if $id;
          }
        }
        if($section ne $new_section) {
          $section = $new_section;
          $section_title_pending = $section;
        }
        if($section_title_pending and not $glyphset->section_no_text) {
          $glyphset->section_text($section_title_pending,$label_width);
          $section_title_pending = undef;
        }
      
        ## remove any whitespace at the top of this row
        my $gminy = $glyphset->miny;
      
        $config->{'transform'}->{'translatey'} = -$gminy + $yoffset + $glyphset->section_height + $glyphset->subtitle_height;

        if ($bgcolour_flag && $glyphset->_colour_background) {
          ## colour the area behind this strip
          my $background = EnsEMBL::Draw::Glyph::Rect->new({
            x             => -$label_width - $padding - $margin * 3/2,
            y             => $gminy - $padding,
            z             => -100,
            width         => $panel_width + $label_width + $margin * 2 + (2 * $padding),
            height        => $glyphset->maxy - $gminy + (2 * $padding),
            colour        => $bgcolours->[$iteration % 2],
            absolutewidth => 1,
            absolutex     => 1,
          });
        
          # this accidentally gets stuffed in twice (for gif & imagemap) so with
          # rounding errors and such we shouldn't track this for maxy & miny values
          unshift @{$glyphset->{'glyphs'}}, $background;
        
          $iteration++;
        }
      
        my $sh = $glyphset->subtitle_height();
        if($glyphset->use_subtitles) {
          $glyphset->push($glyphset->Text({
            font => 'Arial',
            text => $glyphset->subtitle_text(),
            ptsize => 8,
            height => 8,
            colour    => $glyphset->subtitle_colour(),
            x => 2,
            y => $glyphset->miny - $sh + 6,
            halign => 'left',
            absolutex => 1,
          }));
          $glyphset->miny($glyphset->miny-$sh+6);
          $gminy = $glyphset->miny;
        }
        my $sx = -$label_width - $margin;
        my $sy = -$glyphset->section_height + 2;
        if($glyphset->section_text) {
          my $section = $glyphset->section_text;
          my $zmdata = $section_label_data{$section};
          my $url;
          if($zmdata) {
            $url = $self->{'config'}->hub->url({
              type => 'ZMenu',
              action => 'Label',
              section => $section,
              zmdata => to_json($zmdata),
              zmcontext => to_json({
                image_config => $self->{'config'}->type,
              }),
            });
          }

          my $sec_colour = $section_colour{$section};
          unless($sec_colour) {
            $sec_colour = $section_colours[$next_section_col];
            $section_colour{$section} = $sec_colour;
            $next_section_col = ($next_section_col+1) % @section_colours;
          }
          my $sec_off = -4;
          my @texts = @{$glyphset->section_lines};
          unshift @texts,''; # top blank
          my $leading = 12;
          my $sec_off = $glyphset->miny - $glyphset->section_height;
          foreach my $i (0..min(scalar(@texts)-1,2)) {
            $glyphset->push($glyphset->Text({
              font => 'Arial',
              ptsize => 8,
              height => 8,
              text => $texts[$i],
              colour    => 'black',
              x => -$label_width - $margin,
              y => $sec_off,
              width => $label_width,
              halign => 'left',
              absolutex => 1,
              absolutewidth => 1,
              href => $url,
              hover => 1,
              alt => $texts[$i],
              class => "hoverzmenu",
            }));
            $sec_off += $leading;
          }
          $glyphset->push($glyphset->Rect({
            x => $sx -4,
            y => $sec_off - 2,
            width => $label_width - 4,
            height => 2,
            absolutex => 1,
            absolutey => 1,
            absolutewidth => 1,
            colour => $sec_colour,
          }));
        }

        ## set up the "bumping button" label for this strip
        if ($glyphset->label && $show_labels eq 'yes') {
          my $gh = $glyphset->label->height || $config->texthelper->height($glyphset->label->font);

          my ($miny,$maxy) = ($glyphset->miny,$glyphset->maxy);
          my $liney;
          $glyphset->label->y($gminy + ($glyphset->{'label_y_offset'}||0));
          $liney = $gminy+$gh+1+($glyphset->{'label_y_offset'}||0);
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
              absolutex     => 1,
              absolutey     => 1,
              absolutewidth => 1,
              width         => $glyphset->label->width,
              x             => $glyphset->label->x,
              y             => $liney,
              colour        => '#336699',
              dotted        => 'small'
            }));
          }
        }
        if($glyphset->section) {
          my $sec_colour = $section_colour{$glyphset->section};
          my $band_min = $glyphset->miny + $glyphset->section_height;
          my $band_max = $glyphset->maxy;
          my $fashionable_gap = 4;
          $glyphset->push($glyphset->Rect({
            x => -122,
            y => $band_min + $fashionable_gap,
            width => 2,
            height => $band_max-$band_min - 2 * $fashionable_gap,
            absolutex => 1,
            absolutewidth => 1,
            absolutey => 1,
            colour => $sec_colour,
          }));
        }

        $glyphset->transform;
      
        ## translate the top of the next row to the bottom of this one
        $yoffset += $glyphset->height + $trackspacing;
        $self->timer_push('track finished', 3);
        $self->timer_push(sprintf("INIT: [X] $name '%s'", $glyphset->{'my_config'}->get('name')), 2);
      }
    
      $self->timer_push('End of creating glyphs for ' . ref($config), 1);
    
      push @{$self->{'glyphsets'}}, @glyphsets;
    
      $yoffset += $inter_space;
      $self->{'__extra_block_spacing__'} += $inter_space;
      $config->{'panel_width'} = undef;
    }
  }

  $self->timer_push('DrawableContainer->new: End GlyphSets');

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
    'timer'         => $Contents->[0][1]->species_defs->timer
  };
  
  bless( $self, $class );
  return $self;
}

sub timer_push {
  my( $self, $tag, $dep ) = @_;
  $self->{'timer'}->push( $tag, $dep, 'draw' );
}

## render does clever drawing things

sub render {
  my ($self, $type, $boxes) = @_;
  
  ## build the name/type of render object we want
  my $renderer_type = qq(EnsEMBL::Draw::Renderer::$type);
  $self->dynamic_use( $renderer_type );
  ## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'__extra_block_spacing__'},
    $self->{'glyphsets'},
    $boxes
  );
  my $canvas = $renderer->canvas();
  $self->timer_push("DrawableContainer->render ending $type",1);
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

