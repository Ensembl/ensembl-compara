package Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_washu;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::gene_label_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::gene_label_lite);

sub my_label {
    return  'Havana trans.';
}

sub logic_name {
    return 'washu';
}

sub zmenu_caption {
    return  'WashU. gene';
}

1;
