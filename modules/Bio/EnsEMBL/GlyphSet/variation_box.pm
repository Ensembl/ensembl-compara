package Bio::EnsEMBL::GlyphSet::variation_box;
use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::EnsEMBL::GlyphSet::variation;
@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);

sub tag {
  my ($self, $f) = @_; 
  my ($col, $labcol) =  $self->colour($f);
  #warn( "snp - $col - $labcol" );

  if($f->var_class eq 'snp' ) {
    return( { 'style' => 'box', 'letter' => $f->ambig_code, 
	      'colour' => $col, 'label_colour' => $labcol } );
  }

  if($f->start > $f->end ) {
    return( { 'style' => 'left-snp', 'colour' => $col } );
  }

  if($f->var_class eq 'in-del' ) {
    return( { 'style' => 'delta', 'colour' => $col } );
  }
  return ( { 'style'  => 'box', 'colour' => $col, 'letter' => ' ' } );
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
  if(exists $highlights{$id}) {
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
