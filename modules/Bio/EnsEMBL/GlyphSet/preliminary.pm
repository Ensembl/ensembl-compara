package Bio::EnsEMBL::GlyphSet::preliminary;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet;
@ISA = qw(Bio::EnsEMBL::GlyphSet);

sub init_label {
    return;
}

sub _init {
    my ($self) = @_;
    return unless ($self->strand() == 1);
    return unless my $mod = EnsWeb::species_defs->ENSEMBL_PRELIM;

    my $FONT = 'MediumBold';
    my ($w,$h) = $self->{'config'}->texthelper()->real_px2bp($FONT);
    my $top = 0;
    foreach my $line (split /\|/, $mod) { 
    $self->push( new Sanger::Graphics::Glyph::Text({
        'x'         => int( ($self->{'container'}->length()+1-$w * length($line))/2 ), 
        'y'         => $top,
        'height'    => $h,
        'font'      => $FONT,
        'colour'    => 'red3',
        'text'      => $line,
        'absolutey' => 1,
    }) );
    $top += $h + 4;
    }
}

1;
        
