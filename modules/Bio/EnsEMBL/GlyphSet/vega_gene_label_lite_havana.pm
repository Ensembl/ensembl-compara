package Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_havana;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_label_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_label_vega);


sub my_label {
    return  'Havana trans.';
}

sub logic_name {
return 'havana';

}

sub zmenu_caption {
return  'Havana gene';
}





1;
