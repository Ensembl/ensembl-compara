=head1 NAME

Bio::EnsEMBL::GlyphSet::vega_zfish_gene_contig -
Glyphset for Vega genes with gene type 'zfish' in contigviewtop

=cut

package Bio::EnsEMBL::GlyphSet::vega_zfish_gene_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::gene_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::gene_lite);

sub my_label {
    return 'Zfish Genes';
}

sub logic_name {
    return 'zfish';
}

1;
        
