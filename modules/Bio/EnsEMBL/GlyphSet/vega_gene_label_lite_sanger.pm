package Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_sanger;
use strict;
use vars qw(@ISA);


use Bio::EnsEMBL::GlyphSet_transcript_label_vega;

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript_label_vega);


sub my_label {
    return 'Sanger trans.';
}

sub logic_name {
return 'sanger';

}

sub zmenu_caption {
return 'Sanger Gene';
}





1;
