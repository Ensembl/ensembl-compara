package Bio::EnsEMBL::GlyphSet::vega_washu_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_vega);

sub my_label {
    return 'WashU. trans.';
}

sub logic_name {
return 'washu';

}

sub zmenu_caption {
return 'WashU. Gene';
}





1;
