=head1 NAME

Bio::EnsEMBL::GlyphSet::vega_sanger_gene_contig -
Glyphset for Vega genes with gene type 'sanger' in contigviewtop

=cut

package Bio::EnsEMBL::GlyphSet::vega_sanger_gene_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::gene_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::gene_lite);

sub my_label {
    return 'Collins et al Genes';
}

sub logic_name {
    return 'sanger';
}

1;
        
