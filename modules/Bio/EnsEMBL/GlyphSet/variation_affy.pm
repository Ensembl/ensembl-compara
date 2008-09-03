package Bio::EnsEMBL::GlyphSet::variation_affy;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation;
use Data::Dumper;
@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);
#use Bio::EnsEMBL::Variation::VariationFeature;

sub features {
  my ($self) = @_;
  my $snps = $self->fetch_features;
  my $key = $self->_key();

  my @affy_snps;
  foreach my $vf (@$snps) {
    foreach  ( @{ $vf->get_all_sources || []}) {
      next unless $_ eq $source_name;
      push @affy_snps, $vf;
    }
  }
  return \@affy_snps;
}

1;
