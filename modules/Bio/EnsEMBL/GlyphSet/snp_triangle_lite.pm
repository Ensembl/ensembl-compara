package Bio::EnsEMBL::GlyphSet::snp_triangle_lite;
use strict;
use vars qw(@ISA);
use Data::Dumper;
use Bio::EnsEMBL::GlyphSet::snp_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_lite);

sub tag {
    my ($self, $f) = @_; 
    my ($col,$labcol) =  $self->colour($f);
    #warn( "snp - $col - $labcol" );
    if($f->snpclass eq 'snp' ) {
	return( { 'style' => 'box', 'letter' => $f->{'_ambiguity_code'}, 'colour' => $col, 'label_colour' => $labcol } );
    }
    if($f->{'_range_type'} eq 'between' ) {
	return( { 'style' => 'left-snp', 'colour' => $col } );
    }
    if($f->snpclass eq 'in-del' ) {
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

  ## Are we going to highlight this item...
  if( ($f->can('display_name') && exists $highlights{ $f->display_name() } ) or (exists $highlights{ $f->snpid() } )  ) {

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
