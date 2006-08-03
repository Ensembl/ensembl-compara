package Bio::EnsEMBL::GlyphSet::variation_affy;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation;
use Data::Dumper;
@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);
#use Bio::EnsEMBL::Variation::VariationFeature;


sub my_label { 
  my ($self) = @_;
  my $key = 2*($self->_key());
  return "Affy $key SNP"; 
}

sub _key { return $_[0]->my_config('key') || 'r2'; }

sub features {
  my ($self) = @_;
  my @vari_features;
  if( exists( $self->{'config'}->{'snps'} ) ) {
    my $snps = $self->{'config'}->{'snps'} || [];
    if(@$snps && !$self->{'config'}->{'variation_legend_features'} ) {
      $self->{'config'}->{'variation_legend_features'}->{'variations'} = { 'priority' => 1000, 'legend' => [] };
    }
    @vari_features = @$snps;
  }
  else {
    my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
    my $vf_ref = $self->{'container'}->get_all_VariationFeatures();
    @vari_features =
      map  { $_->[1] }
      sort { $a->[0] <=> $b->[0] }
      map  { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
      grep { $_->map_weight < 4 } @$vf_ref;
    if(@vari_features) {
      $self->{'config'}->{'variation_legend_features'}->{'variations'} = { 'priority' => 1000, 'legend' => [] };
    }
  }

  my $source_name = "affy GeneChip Mapping Array";
  my $key = $self->_key();
  my @affy_snps;

  foreach my $vf (@vari_features) {
    # from release 41, Daniel says check vf->source eq affy$key

    # These have no rs ids -> zmenu will break => skip
    #if ($vf->variation_name =~ /Mapping$key/) {
    #  push @affy_snps, $vf;
    #  next;
    #}
    my $v = $vf->variation;
    #print STDERR $vf->variation_name,"\n" unless $v;
    next unless $v;

    # get v->synonym names if any match Mapping$key, push into @affy_snps;
    foreach ( @{ $v->get_all_synonyms() ||[] }   ) {
      next unless  $_ =~ /Mapping$key/;
      push @affy_snps, $vf;
      last;
    }
  }
  return \@affy_snps;
}

1;
