package Bio::EnsEMBL::GlyphSet::vega_gene_label_lite_genoscope;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::gene_label_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::gene_label_lite);

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
