package Bio::EnsEMBL::GlyphSet::vega_zfish_gene_contig;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_gene;
@ISA = qw(Bio::EnsEMBL::GlyphSet_gene);

sub my_label {
  return 'Zfish Genes';
}

sub logic_name {
  return 'zfish';
}

sub my_depth {
  my ($self) = @_;
  my $Config  = $self->{'config'};
  return $Config->get('vega_havana_gene_contig', 'dep') ;
}

1;
        
