package Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_zfish;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_label_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_label_vega);

sub my_label {
    return  'Zfish trans.';
}

sub logic_name {
    return 'zfish';
}

sub zmenu_caption {
    return  'ZFish gene';
}

1;
