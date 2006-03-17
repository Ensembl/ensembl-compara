package Bio::EnsEMBL::GlyphSet::text;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    return;
}

sub _init {
    my ($self) = @_;
    return unless ($self->strand() == -1);

    my $text = $self->{'config'}->{'text'};
    my ($w,$h)   = $self->{'config'}->texthelper()->real_px2bp($self->{'config'}->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});
    my ($w2,$h2) = $self->{'config'}->texthelper()->real_px2bp('Small');
    $self->push( new Sanger::Graphics::Glyph::Text({
        'x'         => 1, 
        'y'         => int( ($h2-$h)/2 ),
        'height'    => $h2,
        'font'      => 'MediumBold',
        'colour'    => 'black',
        'text'      => $text,
        'absolutey' => 1,
    }) );
}

1;
