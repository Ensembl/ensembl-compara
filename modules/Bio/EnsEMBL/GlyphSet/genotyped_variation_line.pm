package Bio::EnsEMBL::GlyphSet::genotyped_variation_line;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation;

@ISA = qw(Bio::EnsEMBL::GlyphSet::variation);

sub my_label { return "Genotyped SNPs"; }

sub features {
  my ($self) = @_;
  my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;

  my @genotyped_vari =
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ $ct{$_->display_consequence} * 1e9 + $_->start, $_ ] }
             grep { $_->map_weight < 4 } 
	       @{$self->{'container'}->get_all_genotyped_VariationFeatures()};

   return \@genotyped_vari;
}
1;
