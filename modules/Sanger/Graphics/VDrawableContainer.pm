package Sanger::Graphics::VDrawableContainer;
use strict;
use base qw(Sanger::Graphics::Root);

sub new {
  my ($class, $Container, $Config, $highlights, $strandedness, $spacing) = @_;

  if(!defined $Container) {
    warn qq(Sanger::Graphics::DrawableContainer::new No container defined);
    return;
  }

  if(!defined $Config) {
    warn qq(Sanger::Graphics::DrawableContainer::new No Config object defined);
    return;
  }

  my $self = {
    'vc'        => $Container,
    'glyphsets' => [],
    'config'    => $Config,
    'spacing'   => $spacing || $Config->{'_spacing'} || 20,
  };
  bless($self, $class);

  ########## loop over all the glyphsets the user wants:
  my $tmp = {};
  my @chromosomes = $Container->{'sa'}->chromosomes();
  my $pos = 100000;
  my $row = '';
  my @subsections =
    map { $_->[1] }
    sort { $a->[0] <=> $b->[0] }
    map {
      $Config->get($_, 'on') eq "on" ? [$Config->get($_,'pos')||$pos++,$_] : () ;
    } $Config->subsections;

  foreach my $chr ( @chromosomes ) {
    for my $row (@subsections) {
      ########## create a new glyphset for this row
      my $classname = qq(Bio::EnsEMBL::GlyphSet::).( $Config->get($row, 'manager')||$row );

      next unless $self->dynamic_use( $classname );

      my $GlyphSet;
      eval {
        $GlyphSet = new $classname($Container, $Config, $highlights, 0, { 'chr' => $chr, 'row' => $row } );
      };

      if($@ || !$GlyphSet) {
        my $reason = $@ || "No reason given just returns undef";
        warn "GLYPHSET: glyphset $classname failed : $reason";
      } else {
         $GlyphSet->_init();
         push @{$self->{'glyphsets'}},  $GlyphSet;
      }
    }
  }

  ########## sort out the resulting mess
  my $scalex = $Config->{'_image_height'} / $Config->container_width();
  $Config->{'transform'}->{'scalex'} = $scalex;
  $Config->{'transform'}->{'absolutescalex'} = 1; # $Config->{'_image_height'} / $Config->image_width();
  $Config->{'transform'}->{'translatex'} += $Config->{'_top_margin'};

  ########## go ahead and do all the database work
  my $yoffset = 0;
  my $glyphsets = @{$self->{'glyphsets'}};

## Firstly lets work how many entries to draw per row!
## Then work out the minimum start for each of these rows
## We then shift up all these points up by that many base 
## pairs to close up any gaps
  my $GS = $Config->{'_group_size'} || 1; 
#  warn $GS;
  my $entries_per_row = $Config->{'_columns'} || ( int( ($glyphsets/$GS - 1) / ($Config->{'_rows'} || 1) + 1 ) * $GS ); 
  my $entry_no = 0;
  $Config->{'_max_height'} =  0;
  $Config->{'_max_width'}  =  0;

  my @min   = ();
  my @max   = ();
  my $row_count = 0;
  my $row_index = 0;
  for my $glyphset (@{$self->{'glyphsets'}}) {
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

  for my $glyphset (@{$self->{'glyphsets'}}) {
    $Config->{'_max_width'} = $xoffset + $Config->image_width();
    ########## set up the label for this strip 
    ########## first we get the max width of label in characters
    my $gw = 0;
    $gw = length($glyphset->label->text()) if(defined $glyphset->label());
    if(defined $glyphset->label2()) {
      my $gw2 = length($glyphset->label2->text());        
      $gw = $gw2 if $gw2>$gw;
    }
    if($gw>0) {
      ########## and convert it to pels
      $gw *= $Config->texthelper->width($glyphset->label->font());
      ########## If the '_label' position is not 'above' move the labels below the image
      my $label_x = $Config->{'_label'} eq 'above' ? 0 : $Config->{'_image_height'};
      $label_x   += 4 - $Config->{'_top_margin'};
      my $label_y = ($glyphset->maxy() + $glyphset->miny() - $gw ) / 2;
      if(defined $glyphset->label()) {
        $glyphset->label->y( $label_y );
        $glyphset->label->x( $label_x / $scalex);            
        $glyphset->label->height($gw);
        $glyphset->push($glyphset->label());
      }
      if(defined $glyphset->label2()) {
        $glyphset->label2->y( $label_y );
        $glyphset->label2->x( ( $label_x + 2 +
                    $Config->texthelper->height($glyphset->label->font()) ) / $scalex);
        $glyphset->label2->height($gw);
        $glyphset->push($glyphset->label2());
      }        
    }
    ########## remove any whitespace at the top of this row
    $Config->{'transform'}->{'translatey'} = -$glyphset->miny() + $spacing/2 + $yoffset;
    $glyphset->transform();
    ########## translate the top of the next row to the bottom of this one
    $yoffset += $glyphset->height() + $spacing;
    $Config->{'_max_height'} = $yoffset + $spacing if( $yoffset + $spacing > $Config->{'_max_height'} );
    unless( ++$entry_no < $entries_per_row ) {
      $entry_no = 0;
      $yoffset = 0;
      my $translateX = shift @min;
      $translateX  ||= 0;
      $xoffset += $Config->image_width() - $translateX * $scalex;
      ## Shift down - and then close up gap!
        $Config->{'transform'}->{'translatex'} += $Config->image_width() - $translateX * $scalex; #$xoffset;
    }
  }

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

#sub dynamic_use {
#  my( $self, $classname ) = @_;
#  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*?)$/;
#  no strict 'refs';
#  return 1 if $parent_namespace->{$module.'::'}; # return if already used
#  eval "require $classname";
#  if($@) {
#    warn "DrawableContainer: failed to use $classname\nDrawableContainer: $@";
#    return 0;
#  }
#  $classname->import();
#  return 1;
#}

1;

=head1 RELATED MODULES

See also: Sanger::Graphics::GlyphSet Sanger::Graphics::Glyph WebUserConfig

=head1 AUTHOR - Roger Pettett

Email - rmp@sanger.ac.uk

=cut
