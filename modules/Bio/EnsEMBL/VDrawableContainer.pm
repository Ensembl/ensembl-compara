package Bio::EnsEMBL::VDrawableContainer;

use strict;
use Bio::EnsEMBL::GlyphSet::Videogram;

sub new {
  my ($class, $Container, $Config, $highlights, $strandedness, $spacing) = @_;

  if(!defined $Container) {
    warn qq(Bio::EnsEMBL::DrawableContainer::new No container defined);
    return;
  }

  if(!defined $Config) {
    warn qq(Bio::EnsEMBL::DrawableContainer::new No Config object defined);
    return;
  }

  my $self = {
    'vc'     => $Container,
    'glyphsets' => [],
    'config'    => $Config,
    'timer'     => $Config->{'species_defs'}->timer,
    'prefix'    => 'Bio::EnsEMBL',
    'spacing'   => $spacing || $Config->get_parameter('spacing') || 20,
  };
  bless($self, $class);

  ########## loop over all the glyphsets the user wants:
  my $tmp = {};
  $Container->{'web_species'} ||= $ENV{'ENSEMBL_SPECIES'};
  my @chromosomes = ($Container->{'chr'});
  my $flag        = 0;
  if( $Config->get_parameter('all_chromosomes') eq 'yes' ) { 
    @chromosomes =  @{$Config->{species_defs}->other_species($Container->{'web_species'}, 'ENSEMBL_CHROMOSOMES')||[] };
    $flag = 1;
  }
  my $pos = 100000;
  my $row = '';

  my $scalex = $Config->get_parameter('image_height') / $Config->get_parameter('container_width');
  $Config->{'transform'}->{'scalex'}         = $scalex;
  $Config->texthelper->{'_scalex'}           = $scalex;
  $Config->{'transform'}->{'absolutescalex'} = 1; # $Config->{'_image_height'} / $Config->image_width();
  $Config->{'transform'}->{'translatex'}    += $Config->get_parameter('top_margin');

  my @glyphsets;
  my @configs = $Config->glyphset_configs;
  foreach my $chr ( @chromosomes ) {
    $Container->{'chr'} = $chr;
    for my $row_config (@configs) {
      ########## create a new glyphset for this row
      my $glyphset  = $row_config->get('glyphset')||$row_config->code;
      my $classname = qq($self->{'prefix'}::GlyphSet::$glyphset);
      next unless $self->dynamic_use( $classname );
      my $EW_Glyphset;
      eval { # Generic glyphsets need to have the type passed as a fifth parameter...
        $EW_Glyphset = new $classname({
	  'container'  => $Container,
	  'chr'        => $chr,
	  'config'     => $Config,
	  'my_config'  => $row_config,
	  'strand'     => 0,
	  'extra'      => {},
	  'highlights' => $highlights,
	  'row'        => $row,
        });
	$EW_Glyphset->{'chr'} = $chr;
      };
      if($@ || !$EW_Glyphset) {
        my $reason = $@ || "No reason given just returns undef";
        warn "GLYPHSET: glyphset $classname failed (@{[$self->{container}{web_species}]}/$ENV{'ENSEMBL_SCRIPT'} at ".gmtime()."\nGLYPHSET:  $reason";
	next;
      }
      $EW_Glyphset->_init();
      push @glyphsets,  $EW_Glyphset;
    }
  }

  ########## sort out the resulting mess
  $spacing = $self->{'spacing'};

  ########## go ahead and do all the database work
  my $yoffset = 0;

## Firstly lets work how many entries to draw per row!
## Then work out the minimum start for each of these rows
## We then shift up all these points up by that many base 
## pairs to close up any gaps

  my $glyphsets = @glyphsets;
  my $GS = $Config->get_parameter( 'group_size' ) || 1;
  my $entries_per_row = $Config->get_parameter( 'columns' ) || ( int( ($glyphsets/$GS - 1) / ($Config->get_parameter('rows') || 1) + 1 ) * $GS );

  my $entry_no = 0;
  $Config->set_parameter('max_height', 0);
  $Config->set_parameter('max_width', 0);

  my @min   = ();
  my @max   = ();
  my $row_count = 0;
  my $row_index = 0;
  for my $glyphset (@glyphsets) {
    $min[$row_index] = $glyphset->minx() if(!defined $min[$row_index] || $min[$row_index] > $glyphset->minx() );
    unless(++$row_count < $entries_per_row) {
      $row_count = 0;
      $row_index++;
    }
  }
  ## Close up gap!
#  my $translateX = shift @row_min;
  my $translateX = shift @min;
  $Config->{'transform'}->{'translatex'} -= $translateX * $scalex; #$xoffset;
  my $xoffset = -$translateX * $scalex;

  for my $glyphset (@glyphsets) {
    $Config->set_parameter( 'max_width',  $xoffset + $Config->get_parameter('image_width') );
    ########## set up the label for this strip 
    ########## first we get the max width of label in characters
    my $feature_type_1 = $glyphset->my_config('feature_type') ||
                         ( $glyphset->my_config('keys') ? $glyphset->my_config('keys')->[0] : undef );
    my $feature_type_2 = $glyphset->my_config('feature_type_2') ||
                         ( $glyphset->my_config('keys') ? $glyphset->my_config('keys')->[1] : undef );
    my $label_1 = $glyphset->my_config('label') ||
                  ( $feature_type_1 ? $glyphset->my_colour( $feature_type_1, 'text' ) : undef );
    my $label_2 = $glyphset->my_config('label_2') ||
                  ( $feature_type_2 ? $glyphset->my_colour( $feature_type_2, 'text' ) : undef );
    if( $glyphset->{'my_config'}->key eq 'Videogram' && $flag ) {
      $label_1 = $glyphset->{'chr'};
    }
    warn "$glyphset          --> $label_1 / $label_2";
    my $gw  = length( length($label_2) > length($label_1) ? $label_2 : $label_1 );
    if($gw>0) {
      ########## and convert it to pels
      warn $gw;
      $gw = $Config->texthelper->width('Small');
      ########## If the '_label' position is not 'above' move the labels below the image
      my $label_x = $Config->get_parameter('label') eq 'above' ? 0 : $Config->get_parameter('image_height');
        $label_x   += 4 - $Config->get_parameter('top_margin');
      my $label_y = ($glyphset->maxy() + $glyphset->miny() - $gw ) / 2;
      warn $gw;
      my $colour_1 = $glyphset->my_config('colour') ||
                     ( $feature_type_1 ? $glyphset->my_colour( $feature_type_1, 'label' ) : undef );
      my $colour_2 = $glyphset->my_config('colour_2') ||
                     ( $feature_type_2 ? $glyphset->my_colour( $feature_type_2, 'label' ) : undef );
      $glyphset->push($glyphset->Text({
        'x'      => $label_x / $scalex,
	'y'      => ($glyphset->maxy() + $glyphset->miny() - length($label_1)*$gw ) / 2,
	'height' => $gw * length($label_1),
	'font'   => 'Small',
	'text'   => $label_1,
        'absolutey' => 1,
	'colour' => $colour_1
      })) if $label_1;
      $glyphset->push($glyphset->Text({
        'x'      => ( $label_x + 2 + $Config->texthelper->height('Tiny') )/ $scalex,
	'y'      => ($glyphset->maxy() + $glyphset->miny() - length($label_2)*$gw ) / 2,
	'height' => $gw * length($label_2),
	'font'   => 'Small',
	'text'   => $label_2,
        'absolutey' => 1,
	'colour' => $colour_2
      })) if $label_2;
    }
    ########## remove any whitespace at the top of this row
    $Config->{'transform'}->{'translatey'} = -$glyphset->miny() + $spacing/2 + $yoffset;
    $glyphset->transform();
    ########## translate the top of the next row to the bottom of this one
    $yoffset += $glyphset->height() + $spacing;
    $Config->set_parameter('max_height',  $yoffset + $spacing ) if( $yoffset + $spacing > $Config->get_parameter('max_height') );
    unless( ++$entry_no < $entries_per_row ) {
      $entry_no = 0;
      $yoffset = 0;
      my $translateX = shift @min;
      $xoffset += $Config->image_width() - $translateX * $scalex;
      ## Shift down - and then close up gap!
        $Config->{'transform'}->{'translatex'} += $Config->image_width() - $translateX * $scalex; #$xoffset;
    }
  }
  $self->{'glyphsets'} = \@glyphsets;
  ########## Store the maximum "width of the image"
  return $self;
}

########## render does clever drawing things
sub render {
  my ($self, $type) = @_;
  
  ########## build the name/type of render object we want
  my $renderer_type = qq(Bio::EnsEMBL::VRenderer::$type);
  ########## dynamic require of the right type of renderer
  return unless $self->dynamic_use( $renderer_type );

  ########## big, shiny, rendering 'GO' button
  my $renderer = $renderer_type->new(
    $self->{'config'},
    $self->{'vc'},
    $self->{'glyphsets'}
  );
  return $renderer->canvas();
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

sub dynamic_use {
  my( $self, $classname ) = @_;
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*?)$/;
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'}; # return if already used
  eval "require $classname";
  if($@) {
    warn "VVDrawableContainer: failed to use $classname\nVVDrawableContainer: $@";
    return 0;
  }
  $classname->import();
  return 1;
}

1;

=head1 RELATED MODULES

See also: Bio::EnsEMBL::GlyphSet Bio::EnsEMBL::Glyph WebUserConfig

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
