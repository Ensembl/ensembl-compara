#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#

package Sanger::Graphics::DrawableContainer;
use strict;
no warnings "uninitialized";
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Circle;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Renderer::png;
use Sanger::Graphics::Renderer::imagemap;
use Sanger::Graphics::Root;

our @ISA = qw(Sanger::Graphics::Root);

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
    'prefix'        => 'Sanger::Graphics',
    'contents'      => $Contents,
    'highlights'    => $highlights || [],
    'strandedness'  => $strandedness || 0,
    '__extra_block_spacing__'    => 0,
  };
  bless( $self, $class );
  return $self;
}


sub new {
  my $class = shift;
  my $self = $class->_init( @_ ); 
  my $T = $self->{'config'};
  my $button_width = $T->get_parameter('button_width')   || 7;
  my $show_buttons = $T->get_parameter('show_buttons')   || 'no' ;
  my $show_labels  = $T->get_parameter('show_labels')    || 'yes';
  my $label_width  = $T->get_parameter('label_width')    || 100;
  my $margin       = $T->get_parameter('margin')         || 5;
  my $trackspacing = $T->get_parameter('spacing')        || 2;
  my $inter_space  = defined($T->get_parameter('intercontainer')) ? $T->get_parameter('intercontainer') : $margin * 2;
  my $image_width  = $T->get_parameter('width')          || 700;
  my $label_start  = $margin      +
                     ( $show_buttons eq 'yes' ? $button_width + $margin : 0 );
  my $panel_start  = $label_start + 
                     ( $show_labels  eq 'yes' ? $label_width  + $margin : 0 );
  my $panel_width  = $image_width - $panel_start - $margin;
  
  my $timer = $self->can('species_defs') ? $self->species_defs->timer : undef;

  $self->{'__extra_block_spacing__'} -= $inter_space;
  ## loop over all turned on & tuned in glyphsets
  my @strands_to_show = $self->{'strandedness'} == 1 ? (1) : (1, -1);
  my $yoffset = $margin;
  my $iteration = 0;

  foreach my $CC ( @{$self->{'contents'}} ) {
    my( $Container,$Config) = @$CC;
    my %manager_cache = ();
    if( defined( $Config->{'_managers'} ) )  {
      %manager_cache = map { $_ => 0 } keys %{$Config->{'_managers'}};
    }
    # warn ref($Container)," - ",ref($Config);
    $self->debug( 'start', ref($Config) ) if( $self->can('debug') );
    $Config->{'panel_width'} = $panel_width;
    unless(defined $Container) {
      warn ref($self).qq( No container defined);
      next;
    }
    unless(defined $Config) {
      warn ref($self).qq( No Config object defined);
      next;
    }
    my @glyphsets = ();
    $Container->{'_config_file_name_'} ||= $ENV{'ENSEMBL_SPECIES'};

    if( ($Container->{'__type__'}||"") eq 'fake' ) {
      my $classname = qq($self->{'prefix'}::GlyphSet::comparafake);
      next unless $self->dynamic_use( $classname );
      my $GlyphSet;
      
      eval {
        $GlyphSet = new $classname( $Container, $Config, $self->{'highlights'}, 1 );
      };
      $Config->container_width(1);
      push @glyphsets, $GlyphSet unless $@;
    } 
    
    else {
      for my $strand (@strands_to_show) {
	my $tmp_gs_store = {};
	for my $row ($Config->subsections( 1 )) {
	  next unless (($Config->get($row, 'on')||"") eq "on");  ## Skip if this is turned off
          next unless $Config->is_available_artefact($row);      ## Skip if not available for this species!
	  my $str_tmp = $Config->get($row, 'str');
	  next if (defined $str_tmp && $str_tmp eq "r" && $strand != -1);
	  next if (defined $str_tmp && $str_tmp eq "f" && $strand != 1);
	  if( defined $Config->get($row,'manager')) { 
	    $manager_cache{ $Config->get($row,'manager') } = 1; 
	    next;
	  }

	  ## create a new glyphset for this row
	  my $GlyphSet;
	  my $classname;
	  if( my $glyphset = $Config->get($row,'glyphset') ) {
	    $classname = qq($self->{'prefix'}::GlyphSet::$glyphset);
	    next unless $self->dynamic_use( $classname );
	    eval { # Generic glyphsets need to have the type passed as a fifth parameter...
	      $GlyphSet = new $classname( $Container, $Config, $self->{'highlights'}, $strand, { 'config_key' => $row } );
	    };
	  } else {
	    $classname = qq($self->{'prefix'}::GlyphSet::$row);
	    next unless $self->dynamic_use( $classname );
	    ## generate a set for both strands
	    eval {
	      $GlyphSet = $classname->new( $Container, $Config, $self->{'highlights'}, $strand );
	    };
	  }
	  if($@ || !$GlyphSet) {
	    my $reason = $@ || "No reason given just returns undef";
	    warn "GLYPHSET: glyphset $classname failed at ",gmtime(),"\n",
	      "GLYPHSET: $reason";
	  } 
	  else {
	    $tmp_gs_store->{$Config->get($row, 'pos')} = $GlyphSet;
	  }
	}
	my $managed_offset = $Config->{'_das_offset'} || 5500;
	## install the glyphset managers, we've just cached the ones we need...

	foreach my $manager ( reverse sort keys %manager_cache ) {
	  next unless $self->dynamic_use( $self->{'prefix'}.qq(::GlyphSet::$manager) );
	  my $classname = $self->{'prefix'}.qq(::GlyphSetManager::$manager);
	  next unless $self->dynamic_use( $classname );
	  my $gsm = new $classname( $Container, $Config, $self->{'highlights'}, $strand );

	  for my $glyphset (sort { $a->managed_name cmp $b->managed_name } $gsm->glyphsets()) {
	    my $row = $glyphset->managed_name();
	    next if     $Config->get($row, 'on')     eq "off";
	    next if     $Config->get($manager, 'on') eq 'off';
	    my $str_tmp = $Config->get($row, 'str');
	    next if (defined $str_tmp && $str_tmp eq "r" && $strand != -1);
	    next if (defined $str_tmp && $str_tmp eq "f" && $strand != 1);
	    $tmp_gs_store->{ $Config->get($row, 'pos') || $managed_offset++ } = $glyphset;
	  }
	}
	## sort out the resulting mess
	my @tmp = map { $tmp_gs_store->{$_} } 
	  sort { $a <=> $b }
	    keys %{ $tmp_gs_store };
	push @glyphsets, ($strand == 1 ? reverse @tmp : @tmp);
      }
}

   my $x_scale = $panel_width /( ($Config->container_width()|| $Container->length() || $panel_width));
  
  if($show_buttons eq 'yes' && $Config->get_parameter('URL') ) {
  for my $glyphset (@glyphsets) {
    next unless defined $glyphset->bumped();
    my $NAME = $glyphset->check();
      my $box_glyph = new Sanger::Graphics::Glyph::Rect({
        'x' => -$panel_start + $margin,
        'y'             => 0,
        'width'         => $button_width,
        'height'        => $button_width,
        'bordercolour'  => 'red',
        'absolutey' => 1,
        'absolutex' => 1,
        'absolutewidth' =>1, 'pixperbp' => $x_scale,
        'href'      => $Config->get( '_settings', 'URL')."$NAME%3A".
                       ($glyphset->bumped() eq 'yes' ? 'off' : 'on'),
        'id'        => $glyphset->bumped() eq 'yes' ? 'collapse' : 'expand',
      });
      my $horiz_glyph = new Sanger::Graphics::Glyph::Text({
        'text'      => $glyphset->bumped() eq 'yes' ? '-' : '+',
        'font'      => 'Small',
        'absolutey' => 1,
        'x'         => -$panel_start + $margin + 2,
        'y'         => -2,
        'width'     => 6,
        'textwidth'     => 6,
        'height'    => 6,
        'colour'    => 'red',
        'absolutex' => 1, 'absolutewidth' => 1, 'pixperbp' => $x_scale
      });
      $glyphset->bumpbutton([$horiz_glyph, $box_glyph]);
    }
    }
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
    my $white  = $Config->bgcolour() || 'white';
    my $bgcolours = [ $Config->get_parameter( 'bgcolour1') || $white,
                      $Config->get_parameter( 'bgcolour2') || $white ];

    my $bgcolour_flag;
    $bgcolour_flag = 1 if($bgcolours->[0] ne $bgcolours->[1]);

    ## go ahead and do all the database work
    $timer->push("DrawableContainer->new: Start GlyphSets") if $timer;
    for my $glyphset (@glyphsets) {
      ## load everything from the database
      my $NAME = $glyphset->check();
      my $ref_glyphset = ref($glyphset);
      eval {
        $glyphset->__init();
      };
      ## don't waste any more time on this row if there's nothing in it
      if( $@ || scalar @{$glyphset->{'glyphs'} } ==0 ) {
	if( $@ ){ warn( $@ ) }
        $glyphset->_dump('rendered' => 'no');
        $timer->push("INIT: $NAME (not rendered)",1) if $timer;
        next;
      };
      ## remove any whitespace at the top of this row
      my $gminy = $glyphset->miny();
      $Config->{'transform'}->{'translatey'} = -$gminy + $yoffset;

      if(defined $bgcolour_flag) {
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
      if(defined $glyphset->label() && $show_labels eq 'yes' ) {
        my $gh = $glyphset->label->height || $Config->texthelper->height($glyphset->label->font());
        $glyphset->label->y( ( ($glyphset->maxy() - $glyphset->miny() - $gh) / 2) + $gminy );
        $glyphset->label->height($gh);
        $glyphset->label()->pixelwidth( $label_width );
        $glyphset->push( $glyphset->label() );
        $glyphset->_dump('rendered' => $glyphset->label()->text());
      } else {
        $glyphset->_dump('rendered' => 'No label' );
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
      $timer->push("INIT: $NAME",1) if $timer;
    }
    push @{$self->{'glyphsets'}}, @glyphsets;
    $yoffset += $inter_space;
    $self->{'__extra_block_spacing__'}+= $inter_space;
    $Config->{'panel_width'} = undef;
    $self->debug( 'end', ref($Config) ) if( $self->can('debug') );
  }
  $timer->push("DrawableContainer->new: End GlyphSets") if $timer;

  return $self;
}

## render does clever drawing things

sub render {
  my ($self, $type) = @_;
  
 my $timer = $self->can('species_defs') ? $self->species_defs->timer : undef;
  $timer->push("DrawableContainer->render starting $type",1) if $timer;
  ## build the name/type of render object we want
  my $renderer_type = qq(Sanger::Graphics::Renderer::$type);
  $self->dynamic_use( $renderer_type );
  #$timer->push("imported $type",2) if $timer;
  ## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'__extra_block_spacing__'},
    $self->{'glyphsets'}
  );
  #$timer->push("created $type",2) if $timer;
  my $canvas = $renderer->canvas();
  #$timer->push("canvased $type",2) if $timer;
  $timer->push("DrawableContainer->render ending $type",1) if $timer;
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
