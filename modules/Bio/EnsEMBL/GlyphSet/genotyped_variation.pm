package Bio::EnsEMBL::GlyphSet::genotyped_variation;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation_box;

@ISA = qw(Bio::EnsEMBL::GlyphSet::variation_box);

sub my_label { return "Genotyped SNPs"; }

sub features {
  my ($self) = @_;
  my $snps =  $self->{'config'}->{'snpview'}->{'genotyped_snps'} || [];
  return $snps;
}
1;
