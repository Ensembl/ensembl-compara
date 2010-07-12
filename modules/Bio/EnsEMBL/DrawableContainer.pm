#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#

package Bio::EnsEMBL::DrawableContainer;

use strict;
no warnings "uninitialized";
use Sanger::Graphics::Glyph::Rect;
use Time::HiRes qw(time);

use base qw(Sanger::Graphics::Root);

sub new {
  my $class          = shift;
  my $self           = $class->_init(@_); 
  my $primary_config = $self->{'config'};
  my $show_labels    = $primary_config->get_parameter('show_labels')    || 'yes';
  my $label_width    = $primary_config->get_parameter('label_width')    || 100;
  my $margin         = $primary_config->get_parameter('margin')         || 5;
  my $trackspacing   = $primary_config->get_parameter('spacing')        || 2;
  my $image_width    = $primary_config->get_parameter('image_width')    || 700;
  my $colours        = $primary_config->species_defs->colour('classes') || {};  
  my $label_start    = $margin;
  my $panel_start    = $label_start + ($show_labels  eq 'yes' ? $label_width  + $margin : 0);
  my $panel_width    = $image_width - $panel_start - $margin;
  my $inter_space    = $primary_config->get_parameter('intercontainer');
     $inter_space    = 2 * $margin unless defined $inter_space;
  

  $self->{'__extra_block_spacing__'} -= $inter_space;
  ## loop over all turned on & tuned in glyphsets

  ## If strandedness -show always on the same strand - o/w show forward/reverse
  my @strands_to_show = $self->{'strandedness'} == 1 ? (-1) : (1, -1);
  my $yoffset         = $margin;
  my $iteration       = 0;

  ## Loop through each pair of "container / config"s
  foreach my $CC (@{$self->{'contents'}}) {
    my ($container, $config) = @$CC;
    $config->set_parameters({
      panel_width        => $panel_width,
      __left_hand_margin => $panel_start - $label_start
    });

    ## If either Container or Config not present skip
    if (!defined $container) {
      warn ref($self) . ' No container defined';
      next;
    }
    
    if (!defined $config) {
      warn ref($self) . ' No config object defined';
      next;
    }

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
      my @configs = $config->glyphset_configs;
      
      for my $strand (@strands_to_show) {
        ## This is much simplified as we just get a row of configurations
        for my $row_config ($strand == 1 ? reverse @configs : @configs) {
          my $display = $row_config->get('display') || ($row_config->get('on') eq 'on' ? 'normal' : 'off');
          
          next if $display eq 'off';
          
          if (!$self->{'strandedness'}) { ## Don't skip if strandedness is set to 1 as we don't want to miss any tracks out
            my $str_tmp = $row_config->get('strand');
            
            if (defined $str_tmp) {                     ## Is this to be shown on a particular strand?
              next if $str_tmp eq 'r' && $strand == 1;  ## Show on reverse strand only
              next if $str_tmp eq 'f' && $strand == -1; ## Show on forward strand only
            }
          }
          
          ## create a new glyphset for this row
          my $glyphset  = $row_config->get('glyphset') || $row_config->code;
          my $classname = "$self->{'prefix'}::GlyphSet::$glyphset";
          
          next unless $self->dynamic_use($classname);
          
          my $ew_glyphset;
          
          eval { # Generic glyphsets need to have the type passed as a fifth parameter
            $ew_glyphset = $classname->new({
              container   => $container,
              config      => $config,
              my_config   => $row_config,
              strand      => $strand,
              extra       => {},
              highlights  => $self->{'highlights'},
              display     => $display
            });
          };
          
          if ($@ || !$ew_glyphset) {
            my $reason = $@ || 'No reason given just returns undef';
            warn "GLYPHSET: glyphset $classname failed at ", gmtime, "\n", "GLYPHSET: $reason";
          } else {
            push @glyphsets, $ew_glyphset;
          }
        }
      }
    }
    
    my $w = $config->container_width;
       $w = $container->length if !$w && $container->can('length');
       
    my $x_scale = $w ? $panel_width /$w : 1; 

    
    $config->{'transform'}->{'scalex'}         = $x_scale; ## set scaling factor for base-pairs -> pixels
    $config->{'transform'}->{'absolutescalex'} = 1;
    $config->{'transform'}->{'translatex'}     = $panel_start; ## because our label starts are < 0, translate everything back onto canvas

    ## set the X-locations for each of the bump buttons/labels
    for my $glyphset (@glyphsets) {
      next unless defined $glyphset->label;
      $glyphset->label->{'font'}        ||= $config->{'_font_face'} || 'arial';
      $glyphset->label->{'ptsize'}      ||= $config->{'_font_size'} || 100;
      $glyphset->label->{'halign'}      ||= 'left';
      $glyphset->label->{'absolutex'}     = 1;
      $glyphset->label->{'absolutewidth'} = 1;
      $glyphset->label->{'pixperbp'}      = $x_scale;
      $glyphset->label->{'colour'}        = $colours->{lc $glyphset->{'my_config'}->get('_class')}{'default'} || 'black';
      
      $glyphset->label->x(-$label_width - $margin) if defined $glyphset->label;
      $glyphset->label->width($label_width);
      $glyphset->label->{'ellipsis'}      = 1;
      
      my @res = $glyphset->get_text_width($label_width, $glyphset->label->{'text'}, '', 'ellipsis' => 1, 'font' => $glyphset->label->{'font'}, 'ptsize' => $glyphset->label->{'ptsize'});
      
      $glyphset->label->{'text'} = $res[0];
    }

    ## pull out alternating background colours for this script
    my $bgcolours = [
      $config->get_parameter( 'bgcolour1') || 'background1',
      $config->get_parameter( 'bgcolour2') || 'background2'
    ];

    my $bgcolour_flag = $bgcolours->[0] ne $bgcolours->[1];

    ## go ahead and do all the database work
    $self->timer_push('GlyphSet list prepared for config ' . ref($config), 1);
    
    my $export_cache;
    
    for my $glyphset (@glyphsets) {
      ## load everything from the database
      my $name         = $glyphset->{'my_config'}->key;
      my $ref_glyphset = ref $glyphset;
      
      eval {
        $glyphset->{'export_cache'} = $export_cache;
        
        my $text_export = $glyphset->render;
        
        if ($text_export) {
          # Add a header showing the region being exported
          if (!$self->{'export'}) {
            my $container = $glyphset->{'container'};
            my $core      = $self->{'config'}->core_objects;
            
            $self->{'export'} .= sprintf("Region:     %s\r\n", $container->name)                    if $container->can('name');
            $self->{'export'} .= sprintf("Gene:       %s\r\n", $core->{'gene'}->long_caption)       if $ENV{'ENSEMBL_TYPE'} eq 'Gene';
            $self->{'export'} .= sprintf("Transcript: %s\r\n", $core->{'transcript'}->long_caption) if $ENV{'ENSEMBL_TYPE'} eq 'Transcript';
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
      };
      
      ## remove any whitespace at the top of this row
      my $gminy = $glyphset->miny;
      
      $config->{'transform'}->{'translatey'} = -$gminy + $yoffset;

      if ($bgcolour_flag && $glyphset->_colour_background) {
        ## colour the area behind this strip
        my $background = new Sanger::Graphics::Glyph::Rect({
          x             => -$label_width - $margin * 3/2,
          y             => $gminy,
          z             => -100,
          width         => $panel_width + $label_width + $margin * 2,
          height        => $glyphset->maxy - $gminy,
          colour        => $bgcolours->[$iteration % 2],
          absolutewidth => 1,
          absolutex     => 1,
        });
        
        # this accidentally gets stuffed in twice (for gif & imagemap) so with
        # rounding errors and such we shouldn't track this for maxy & miny values
        unshift @{$glyphset->{'glyphs'}}, $background;
        
        $iteration++;
      }
      
      ## set up the "bumping button" label for this strip
      if ($glyphset->label && $show_labels eq 'yes') {
        my $gh = $glyphset->label->height || $config->texthelper->height($glyphset->label->font);
        
        $glyphset->label->y($gminy);
        $glyphset->label->height($gh);
        $glyphset->label->pixelwidth($label_width);
        $glyphset->push($glyphset->label);
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
  
  $self->timer_push('DrawableContainer->new: End GlyphSets');

  return $self;
}

sub species_defs { return $_[0]->{'config'}->{'species_defs'}; }

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
    'prefix'        => 'Bio::EnsEMBL',
    'contents'      => $Contents,
    'highlights'    => $highlights || [],
    'strandedness'  => $strandedness || 0,
    '__extra_block_spacing__'    => 0,
    'timer'         => $Contents->[0][1]{'species_defs'}->timer
  };
  
  $self->{'strandedness'} = 1 if $self->{'config'}->get_parameter('text_export');
   
  bless( $self, $class );
  return $self;
}

sub timer_push {
  my( $self, $tag, $dep ) = @_;
  $self->{'timer'}->push( $tag, $dep, 'draw' );
}

## render does clever drawing things

sub render {
  my ($self, $type) = @_;
  
  ## build the name/type of render object we want
  my $renderer_type = qq(Sanger::Graphics::Renderer::$type);
  $self->dynamic_use( $renderer_type );
  ## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'__extra_block_spacing__'},
    $self->{'glyphsets'}
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

=head1 RELATED MODULES

See also: Sanger::Graphics::GlyphSet Sanger::Graphics::Glyph WebUserConfig

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
