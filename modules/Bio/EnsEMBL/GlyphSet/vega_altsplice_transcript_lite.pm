package Bio::EnsEMBL::GlyphSet::vega_altsplice_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript_vega;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_vega);


sub my_label {
    return 'Vega trans.';
}

sub logic_name {
return ('genoscope', 'havana', 'sanger', 'zfish');
}

sub zmenu_caption {
return 'Vega Gene';
}




1;
