package Bio::EnsEMBL::GlyphSet::vega_havana_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_vega);

sub my_label {
    return 'Havana trans.';
}

sub logic_name {
return 'havana';

}

sub zmenu_caption {
return 'Havana Gene';
}





1;
