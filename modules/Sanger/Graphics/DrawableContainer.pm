#########
# Author: rmp@sanger.ac.uk
# Maintainer: webmaster@sanger.ac.uk
# Created: 2001
#
package Sanger::Graphics::DrawableContainer;
use strict;
use Sanger::Graphics::Glyph::Line;
use Sanger::Graphics::Glyph::Rect;
use Sanger::Graphics::Glyph::Text;
use Sanger::Graphics::Glyph::Circle;
use Sanger::Graphics::Glyph::Poly;
use Sanger::Graphics::Glyph::Intron;
use Sanger::Graphics::Glyph::Composite;
use Sanger::Graphics::Renderer::png;
use Sanger::Graphics::Renderer::imagemap;

sub new {
  my ($class, $Container, $Config, $highlights, $strandedness, $Storage) = @_;
  
  my @strands_to_show = (defined $strandedness && $strandedness == 1) ? (1) : (1, -1);
  
  unless(defined $Container) {
    print STDERR qq(Sanger::Graphics::DrawableContainer::new No container defined\n);
    return;
  }
  
  unless(defined $Config) {
    print STDERR qq(Sanger::Graphics::DrawableContainer::new No Config object defined\n);
    return;
  }
  
  my $self = {
	      'vc'            => $Container,
	      'glyphsets'     => [],
	      'config'        => $Config,
	      'spacing'       => 5,
	      'button_width'  => 16,
	      'storage'       => $Storage
	     };
  bless($self, $class);
  
  my $black = "red"; # arf.
  
  #########
  # loop over all turned on & tuned in glyphsets
  #
  for my $strand (@strands_to_show) {

    my $tmp_glyphset_store = {};

    for my $row ($Config->subsections()) {
      next unless ($Config->get($row, 'on') eq "on");
      my $str_tmp = $Config->get($row, 'str');
      next if (defined $str_tmp && $str_tmp eq "r" && $strand != -1);
      next if (defined $str_tmp && $str_tmp eq "f" && $strand != 1);
      
      #########
      # create a new glyphset for this row
      #
      my $classname = qq(Sanger::Graphics::GlyphSet::$row);

      #########
      # generate a set for both strands
      #
      my $GlyphSet;
      eval {
	$GlyphSet = new $classname($Container, $Config, $highlights, $strand);
      };
      if($@) {
	print STDERR "GLYPHSET $classname failed\n";
      } else {
	$tmp_glyphset_store->{$Config->get($row, 'pos')} = $GlyphSet;
      }
    }

    #########
    # sort out the resulting mess
    #
    my @tmp = map { $tmp_glyphset_store->{$_} } sort { $a <=> $b } keys %{ $tmp_glyphset_store };
    push @{$self->{'glyphsets'}}, ($strand == 1 ? reverse @tmp : @tmp);
  }
    
  #########
  # calculate real scaling here
  #
  my $spacing      = $self->{'spacing'};
  my $button_width = $self->{'button_width'};
  
  #########
  # calculate the maximum label width (plus margin)
  #
  my $label_length_px = 0;
  
  for my $glyphset (@{$self->{'glyphsets'}}) {
    my $composite;
    next unless defined $glyphset->label();
    
    my $pixels = length($glyphset->label->text()) * $Config->texthelper->width($glyphset->label->font());
    
    $label_length_px = $pixels if($pixels > $label_length_px);
    
    #########
    # just for good measure:
    #
    $glyphset->label->width($label_length_px);
    next unless defined $glyphset->bumped();
    $composite = Sanger::Graphics::Glyph::Composite->new({
							  'y'         => 0,
							  'x'         => 0,
							  'absolutey' => 1,
							  'width'     => 10
							 });
    
    my $NAME = ref($glyphset);
    $NAME =~ s/^.*:://;
    my $box_glyph = Sanger::Graphics::Glyph::Rect->new({
							'x'            => 2,
							'y'            => 0,
							'width'        => 10,
							'height'       => 8,
							'bordercolour' => $black,
							'absolutey'    => 1,
							'absolutex'    => 1,
							'href'         => $Config->get( '_settings', 'URL')."$NAME%3A".($glyphset->bumped() eq 'yes' ? 'off' : 'on'),
							'id'           => $glyphset->bumped() eq 'yes' ? 'collapse' : 'expand',
						       });
    my $horiz_glyph = Sanger::Graphics::Glyph::Text->new({
							  'text'      => $glyphset->bumped() eq 'yes' ? '-' : '+',
							  'font'      => 'Small',
							  'absolutey' => 1,
							  'x'         => 4,
							  'y'         => $glyphset->bumped() eq 'yes' ? -1.5 : -1,
							  'width'     => 10,
							  'height'    => 8,
							  'colour'    => $black,
							  'absolutex' => 1
							 });
    
    $composite->push($box_glyph);
    $composite->push($horiz_glyph);
  }
  
  #########
  # add spacing before and after labels
  #
  $label_length_px += $spacing * 2;
  
  #########
  # calculate scaling factors
  #
  my $pseudo_im_width = $Config->image_width() - $label_length_px - $spacing - $button_width;
  my $scalex = $pseudo_im_width / $Config->container_width();
  
  #########
  # set scaling factor for base-pairs -> pixels
  #
  $Config->{'transform'}->{'scalex'} = $scalex;
    
  #########
  # set scaling factor for 'absolutex' coordinates -> real pixel coords
  #
  $Config->{'transform'}->{'absolutescalex'} = $pseudo_im_width / $Config->image_width();
  
  #########
  # because our text label starts are < 0, translate everything back onto the canvas
  #
  my $extra_translation = $label_length_px + $button_width;
  $Config->{'transform'}->{'translatex'} += $extra_translation;
  
  #########
  # set the X-locations for each of the bump buttons/labels
  #
  for my $glyphset (@{$self->{'glyphsets'}}) {
    next unless defined $glyphset->label();
    
    $glyphset->label->x(-($extra_translation - $spacing) /  $scalex);
  }
  
  #########
  # pull out alternating background colours for this script
  #
  my $white  = $Config->bgcolour() || "white";
  my $bgcolours = [ $Config->get('_settings', 'bgcolour1') || $white,
		    $Config->get('_settings', 'bgcolour2') || $white ];
  
  my $bgcolour_flag;
  $bgcolour_flag = 1 if($bgcolours->[0] ne $bgcolours->[1]);
  
  #########
  # go ahead and do all the database work
  #
  my $yoffset = $spacing;
  my $iteration = 0;
  for my $glyphset (@{$self->{'glyphsets'}}) {
    #########
    # load everything from the database
    #
    my $ref_glyphset = ref($glyphset);
    $glyphset->_init();

    #########
    # don't waste any more time on this row if there's nothing in it
    #
    next if(scalar @{$glyphset->{'glyphs'}} == 0);

    #########
    # remove any whitespace at the top of this row
    my $gminy = $glyphset->miny();
    $Config->{'transform'}->{'translatey'} = -$gminy + $yoffset + ($iteration * $spacing);
    
    if(defined $bgcolour_flag) {
      #########
      # colour the area behind this strip
      #
      my $background = new Sanger::Graphics::Glyph::Rect({
							  'x'         => 0,
							  'y'         => $gminy,
							  'width'     => $Config->image_width(),
							  'height'    => $glyphset->maxy() - $gminy,
							  'colour'    => $bgcolours->[$iteration % 2],
							  'absolutex' => 1,
							 });
      #########
      # this accidentally gets stuffed in twice (for gif & imagemap)
      # so with rounding errors and such we shouldn't track this for maxy & miny values
      #
      unshift @{$glyphset->{'glyphs'}}, $background;
    }
    
    #########
    # set up the "bumping button" label for this strip
    #
    if(defined $glyphset->label()) {
      my $gh = $Config->texthelper->height($glyphset->label->font());
      $glyphset->label->y((($glyphset->maxy() - $glyphset->miny() - $gh) / 2) + $gminy);
      $glyphset->label->height($gh);
      $glyphset->push($glyphset->label());
    }

    $glyphset->transform();
    
    #########
    # translate the top of the next row to the bottom of this one
    #
    $yoffset += $glyphset->height();
    $iteration ++;
  }
  return $self;
}

#########
# render does clever drawing things
#
sub render {
  my ($self, $type) = @_;
  
  #########
  # build the name/type of render object we want
  #
  my $renderer_type = qq(Sanger::Graphics::Renderer::$type);
  
  #########
  # big, shiny, rendering 'GO' button
  #
  my $renderer = $renderer_type->new($self->{'config'}, $self->{'vc'}, $self->{'glyphsets'});
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
