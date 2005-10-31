package Bio::EnsEMBL::GlyphSet::info;
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
    my ($w,$h)   = $self->{'config'}->texthelper()->real_px2bp($self->{'config'}->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'});
    my ($w2,$h2) = $self->{'config'}->texthelper()->real_px2bp('Small');
    $self->push( new Sanger::Graphics::Glyph::Text({
        'x'         => 1, 
        'y'         => int( ($h2-$h)/2 ),
        'height'    => $h2,
        'font'      => $self->{'config'}->species_defs->ENSEMBL_STYLE->{'LABEL_FONT'},
        'colour'    => 'black',
        'text'      => sprintf( "Ensembl %s    %s:%d-%d    %s",
           @{[$self->{container}{_config_file_name_}]}, $self->{'container'}->seq_region_name,
           $self->{'container'}->start(), $self->{'container'}->end,
           scalar( gmtime() )
        ),
        'absolutey' => 1,
    }) );
}

1;
        
