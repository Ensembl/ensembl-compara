package Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_havana;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::gene_label_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::gene_label_lite);

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
