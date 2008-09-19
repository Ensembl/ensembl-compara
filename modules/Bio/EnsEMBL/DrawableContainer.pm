#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#

package Bio::EnsEMBL::DrawableContainer;

use strict;
no warnings "uninitialized";
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Time::HiRes qw(time);

use base qw(Sanger::Graphics::Root);

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
  bless( $self, $class );
  return $self;
}

sub timer_push {
  my( $self, $tag, $dep ) = @_;
  $self->{'timer'}->push( $tag, $dep, 'draw' );
}

sub new {
  my $class        = shift;
  my $self         = $class->_init( @_ ); 

## Get configuration details off the image configuration...

  my $primary_config = $self->{'config'};
  my $button_width   = $primary_config->get_parameter( 'button_width')   || 7;
  my $show_buttons   = $primary_config->get_parameter( 'show_buttons')   || 'no' ;
  my $show_labels    = $primary_config->get_parameter( 'show_labels')    || 'yes';
  my $label_width    = $primary_config->get_parameter( 'label_width')    || 100;
  my $margin         = $primary_config->get_parameter( 'margin')         || 5;
  my $trackspacing   = $primary_config->get_parameter( 'spacing')        || 2;
  my $inter_space    = $primary_config->get_parameter( 'intercontainer');
     $inter_space    = 2 * $margin unless defined( $inter_space );
  my $image_width    = $primary_config->get_parameter( 'image_width')    || 700;
  my $label_start    = $margin      + ( $show_buttons eq 'yes' ? $button_width + $margin : 0 );
  my $panel_start    = $label_start + ( $show_labels  eq 'yes' ? $label_width  + $margin : 0 );
  my $panel_width    = $image_width - $panel_start - $margin;
  

  $self->{'__extra_block_spacing__'} -= $inter_space;
  ## loop over all turned on & tuned in glyphsets

## If strandedness -show always on the same strand - o/w show forward/revers...

  my @strands_to_show = $self->{'strandedness'} == 1 ? (1) : (1, -1);
  my $yoffset         = $margin;
  my $iteration       = 0;

## Loop through each pair of "container / config"s
#
  foreach my $CC ( @{$self->{'contents'}} ) {
    my( $Container,$Config) = @$CC;
    $Config->set_parameter('panel_width', $panel_width );

## If either Container or Config not present skip!!
    unless(defined $Container) {
      warn ref($self).qq( No container defined);
      next;
    }
    unless(defined $Config) {
      warn ref($self).qq( No Config object defined);
      next;
    }

## Initiailize list of glyphsets for this configuration...
#
    my @glyphsets = ();

    $Container->{'web_species'} ||= $ENV{'ENSEMBL_SPECIES'};

    if( ($Container->{'__type__'}||"") eq 'fake' ) {
      my $classname = qq($self->{'prefix'}::GlyphSet::comparafake);
      next unless $self->dynamic_use( $classname );
      my $GlyphSet;
      eval {
        $GlyphSet = new $classname( $Container, $Config, $self->{'highlights'}, 1 );
      };
      $Config->container_width(1);
      push @glyphsets, $GlyphSet unless $@;
    } else {
      my @configs = $Config->glyphset_configs;
      for my $strand (@strands_to_show) {
## This is much simplified as we just get a row of configurations...
	for my $row_config ($strand == 1 ? reverse @configs : @configs) {
	  my $display = $row_config->get('display')||($row_config->get('on')eq'on'?'normal':'off');
          warn ".... ",$row_config->get('caption'),"............................... $display ....";
	  next if $display eq 'off';
	  my $str_tmp = $row_config->get('strand');

	  next if  defined $str_tmp && ( $str_tmp eq "r" && $strand != -1 || $str_tmp eq "f" && $strand !=  1 );
	  
## create a new glyphset for this row
	  my $glyphset  = $row_config->get('glyphset')||$row_config->code;
	  my $classname = qq($self->{'prefix'}::GlyphSet::$glyphset);
	  next unless $self->dynamic_use( $classname );
	  my $EW_Glyphset;
	  eval { # Generic glyphsets need to have the type passed as a fifth parameter...
	    $EW_Glyphset = new $classname({
	      'container'  => $Container,
	      'config'     => $Config,
	      'my_config'  => $row_config,
	      'strand'     => $strand,
	      'extra'      => {},
	      'highlights' => $self->{'highlights'},
	      'display'    => $display
	    });
	  };
	  if($@ || !$EW_Glyphset) {
	    my $reason = $@ || "No reason given just returns undef";
	    warn "GLYPHSET: glyphset $classname failed at ",gmtime(),"\n",
	      "GLYPHSET: $reason";
	  } else {
	    push @glyphsets, $EW_Glyphset;
	  }
	}
      }
    }
    
    my $w = $Config->container_width;
    $w = $Container->length if !$w && $Container->can('length');
    my $x_scale = $w ? $panel_width /$w : 1; 

    ## set scaling factor for base-pairs -> pixels
    $Config->{'transform'}->{'scalex'} = $x_scale;
    $Config->{'transform'}->{'absolutescalex'} = 1;

    ## because our label starts are < 0, translate everything back onto canvas
    $Config->{'transform'}->{'translatex'} = $panel_start;

    ## set the X-locations for each of the bump buttons/labels
    for my $glyphset (@glyphsets) {
      next unless defined $glyphset->label();
      $glyphset->label->{'font'}        ||= $Config->{'_font_face'} || 'arial';
      $glyphset->label->{'ptsize'}      ||= $Config->{'_font_size'} || 100;
      $glyphset->label->{'halign'}      ||= 'left';
      $glyphset->label->{'absolutex'}    = 1;
      $glyphset->label->{'absolutewidth'}= 1;
      $glyphset->label->{'pixperbp'}     = $x_scale;
      $glyphset->label->x(-$label_width-$margin) if defined $glyphset->label;
    }

    ## pull out alternating background colours for this script
    my $bgcolours = [ $Config->get_parameter( 'bgcolour1') || 'background1',
                      $Config->get_parameter( 'bgcolour2') || 'background2' ];

    my $bgcolour_flag = $bgcolours->[0] ne $bgcolours->[1];

    ## go ahead and do all the database work
    $self->timer_push( 'GlyphSet list prepared for config '.ref($Config), 1 );
    for my $glyphset (@glyphsets) {
      ## load everything from the database
      my $NAME = $glyphset->{'my_config'}->key;
      my $ref_glyphset = ref($glyphset);
      eval {
        $glyphset->render();
      };
      ## don't waste any more time on this row if there's nothing in it
      if( $@ || scalar @{$glyphset->{'glyphs'} } ==0 ) {
	if( $@ ){ warn( $@ ) }
#        $glyphset->_dump('rendered' => 'no');
	$self->timer_push("track finished",3);
        $self->timer_push("INIT: [ ] $NAME",2);
        next;
      };
      ## remove any whitespace at the top of this row
      my $gminy = $glyphset->miny();
      $Config->{'transform'}->{'translatey'} = -$gminy + $yoffset;

      if($bgcolour_flag) {
        ## colour the area behind this strip
        my $background = new Sanger::Graphics::Glyph::Rect({
          'x'         => 0,
          'y'         => $gminy,
          'z'         => -100,
          'width'     => $panel_width,
          'height'    => $glyphset->maxy() - $gminy,
          'colour'    => $bgcolours->[$iteration % 2],
          'absolutewidth' =>1,
          'absolutex' => 1,
        });
      # this accidentally gets stuffed in twice (for gif & imagemap) so with
      # rounding errors and such we shouldn't track this for maxy & miny values
        unshift @{$glyphset->{'glyphs'}}, $background;
      }
      ## set up the "bumping button" label for this strip
      if( $glyphset->label() && $show_labels eq 'yes' ) {
        my $gh = $glyphset->label->height || $Config->texthelper->height($glyphset->label->font());
        $glyphset->label->y( ( ($glyphset->maxy() - $glyphset->miny() - $gh) / 2) + $gminy );
        $glyphset->label->height($gh);
        $glyphset->label()->pixelwidth( $label_width );
        $glyphset->push( $glyphset->label() );
#        $glyphset->_dump('rendered' => $glyphset->label()->text());
      } else {
#        $glyphset->_dump('rendered' => 'No label' );
      }
      if( $show_buttons eq 'yes' && defined $glyphset->bumpbutton()) {
        my $T = int(($glyphset->maxy() - $glyphset->miny() - 8) / 2 + $gminy );
        $glyphset->bumpbutton->[0]->y( $T     );
        $glyphset->bumpbutton->[1]->y( $T + 2 );
        $glyphset->push(@{$glyphset->bumpbutton()});
      }

      $glyphset->transform();
      ## translate the top of the next row to the bottom of this one
      $yoffset += $glyphset->height() + $trackspacing;
      $iteration ++;
      $self->timer_push("track finished",3);
      $self->timer_push("INIT: [X] $NAME",2);
    }
    $self->timer_push( 'End of creating glyphs for '.ref($Config), 1);
    push @{$self->{'glyphsets'}}, @glyphsets;
    $yoffset += $inter_space;
    $self->{'__extra_block_spacing__'}+= $inter_space;
    $Config->{'panel_width'} = undef;
  }
  $self->timer_push("DrawableContainer->new: End GlyphSets");

  return $self;
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
