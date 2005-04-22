package Bio::EnsEMBL::GlyphSet::tagged_snp;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation_box;

@ISA = qw(Bio::EnsEMBL::GlyphSet::variation_box);

sub my_label { return "Tagged SNPs"; }

sub features {
  my ($self) = @_;
  my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;

  my @genotyped_vari =
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ $ct{$_->get_consequence_type} * 1e9 + $_->start, $_ ] }
             grep { $_->map_weight < 4 }
	       @{$self->{'container'}->get_all_genotyped_VariationFeatures()};

  my @return;
  my $Config   = $self->{'config'};
  my $only_pop = $Config->{'_ld_population'};
  foreach my $vari (@genotyped_vari) {
    foreach my $pop  (@{ $vari->is_tagged }) {
      if ($pop->dbID == $only_pop) {
	push @return, $vari;
	last;
      }
    };
  }
  return \@return;
}
1;

