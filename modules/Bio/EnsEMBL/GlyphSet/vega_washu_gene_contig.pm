=head1 NAME

Bio::EnsEMBL::GlyphSet::vega_washu_gene_contig -
Glyphset for Vega genes with gene type 'washu' in contigviewtop

=cut

package Bio::EnsEMBL::GlyphSet::vega_washu_gene_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::gene_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::gene_lite);

sub my_label {
    return 'WashU. Genes';
}

sub logic_name {
    return 'washu';
}

1;
        
