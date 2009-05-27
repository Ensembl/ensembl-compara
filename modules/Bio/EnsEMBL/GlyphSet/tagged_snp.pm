package Bio::EnsEMBL::GlyphSet::tagged_snp;

use strict;


use base qw(Bio::EnsEMBL::GlyphSet::_variation);

sub my_label { return "Tagged SNPs"; }

sub features {
  my ($self) = @_;
  my $Config   = $self->{'config'};
  my $genotyped_vari = $Config->{'snps'};
  return unless ref $genotyped_vari eq 'ARRAY';  

  my @return;
  my @pops     = @{ $Config->{'_ld_population'} || [] }; 
  
  foreach my $vari (@$genotyped_vari) { 
    foreach my $pop  (@{ $vari->is_tagged }) { 
      if ($pop->name eq $pops[0]) {
	push @return, $vari;
	last;
      }
    };
  }
  return \@return;
}



1;

