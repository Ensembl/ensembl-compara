package Bio::EnsEMBL::GlyphSet::vega_zfish_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_vega);

sub my_label {
    return 'Zfish trans.';
}

sub logic_name {
    return 'zfish';
}

sub zmenu_caption {
    return 'Zfish Gene';
}

1;
