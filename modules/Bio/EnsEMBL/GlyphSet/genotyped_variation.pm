package Bio::EnsEMBL::GlyphSet::genotyped_variation;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::variation_box;

@ISA = qw(Bio::EnsEMBL::GlyphSet::variation_box);

sub my_label { return "Genotyped variations"; }

sub features {
  my ($self) = @_;
  my @genotyped_vari =
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ substr($_->consequence_type,0,2) * 1e9 + $_->start, $_ ] }
             grep { $_->map_weight < 4 } 
	       @{$self->{'container'}->get_all_genotyped_VariationFeatures()};

   return \@genotyped_vari;
}
1;
