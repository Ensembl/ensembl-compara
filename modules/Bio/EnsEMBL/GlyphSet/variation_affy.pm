package Bio::EnsEMBL::GlyphSet::variation_affy;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation;
use Data::Dumper;
@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);
#use Bio::EnsEMBL::Variation::VariationFeature;


sub my_label { 
  my ($self) = @_;
  my $key = $self->_key();
  return "Affy $key SNP"; 
}

sub _key { return $_[0]->my_config('key') || 'r2'; }

sub features {
  my ($self) = @_;
  my $snps = $self->fetch_features;
  my $key = $self->_key();
  my $source_name = "Affy GeneChip $key Mapping Array";

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
