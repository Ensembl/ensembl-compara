package Bio::EnsEMBL::GlyphSet::variation_box;
use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::EnsEMBL::GlyphSet::variation;
@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);

sub tag {
  my ($self, $f) = @_; 
  my ($col, $label_colour) =  $self->colour($f);

  my $style;

  if($f->start > $f->end ) {
    $style = "left-snp";
  }

  elsif($f->var_class eq 'in-del' ) {
    $style = "delta";
  }
  else {
    $style = "box";
  }

  my $letter = $style eq 'box' ? $f->ambig_code : "";
  return ( { 'style'        => $style,
	     'colour'       => $col, 
	     'letter'       => $letter,
	     'label_colour' => $label_colour} );
}


sub highlight {
  my $self = shift;
  my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;
  ## Get highlights...
  my %highlights;
  @highlights{$self->highlights()} = ();

  # Are we going to highlight this item...
  my $id = $f->variation_name();
  $id =~ s/^rs//;
  if(exists $highlights{$id} or exists $highlights{"rs".$id} ) {
    # if ($f->can('display_name') && exists $highlights{ $f->display_name() } ) or (exists $highlights{$id} )  ) {

   # Line of white first
    my $high = new Sanger::Graphics::Glyph::Rect({
                'x'         => $composite->x() - 1/$pix_per_bp,
                'y'         => $composite->y(),  ## + makes it go down
                'width'     => $composite->width() + 2/$pix_per_bp,
                'height'    => $h + 2,
                'colour'    => "white",
                'absolutey' => 1,
						 });
    $self->unshift($high);
    # Line of black outermost
   my $low = new Sanger::Graphics::Glyph::Rect({
                'x'         => $composite->x() -2/$pix_per_bp,
                'y'         => $composite->y() -1,  ## + makes it go down
                'width'     => $composite->width() + 4/$pix_per_bp,
                'height'    => $h + 4,
                'colour'    => $hi_colour,
                'absolutey' => 1,
						 });

    $self->unshift($low);
  }
}

1;
