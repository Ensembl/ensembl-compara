=head1 NAME

Bio::EnsEMBL::GlyphSet::glovar_snp_triangle -
Glyphset to display Glovar SNP neighbourhood in snpview

=head1 DESCRIPTION

Displays SNP neighbourhood for Glovar SNP in snpview

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 AUTHOR

Patrick Meidl <pm2@sanger.ac.uk>

=head1 CONTACT

Post questions to the EnsEMBL development list ensembl-dev@ebi.ac.uk

=cut

package Bio::EnsEMBL::GlyphSet::glovar_snp_triangle;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::glovar_snp;
@ISA = qw(Bio::EnsEMBL::GlyphSet::glovar_snp);

=head2 tag

  Arg[1]      : a Bio::EnsEMBL::Variation::VariationFeature object
  Example     : my $tag = $self->tag($f);
  Description : retrieves the SNP tag (ambiguity code) in the right colour
  Return type : hashref
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub tag {
    my ($self, $f) = @_; 
    my ($col, $labcol) =  $self->colour($f);

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

=head2 highlight

  Arg[1]      : a Bio::EnsEMBL::Variation::VariationFeature object
  Arg[2]      : a Sanger::Graphics::Glyph::Composite object
  Arg[3]      : int $pix_per_bp - pixels per basepair
  Arg[4]      : int $h - height
  Arg[5]      : String $hi_colour - colour for highlight
  Description : hightlights the selected SNP
  Return type : none
  Exceptions  : none
  Caller      : $self->_init()

=cut

sub highlight {
    my $self = shift;
    my ($f, $composite, $pix_per_bp, $h, $hi_colour) = @_;
    ## Get highlights...
    my %highlights;
    @highlights{$self->highlights()} = ();

    # Are we going to highlight this item...
    my $id = $f->variation_name();
    if(exists $highlights{$id}) {
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

