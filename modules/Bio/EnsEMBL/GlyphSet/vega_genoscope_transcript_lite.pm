package Bio::EnsEMBL::GlyphSet::vega_genoscope_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_vega);

sub my_label {
    return 'Genoscope trans.';
}

sub logic_name {
return 'genoscope';

}

sub zmenu_caption {
return 'Genoscope Gene';
}


1;
