package Bio::EnsEMBL::GlyphSet::snp_triangle_genotype;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::snp_triangle_lite;
@ISA = qw(Bio::EnsEMBL::GlyphSet::snp_triangle_lite);

sub my_label { return "Genotyped SNPs"; }

sub features {
  my ($self) = @_;

  # Get genotyped snps using snp database
  # Returns Bio::EnsEMBL::ExternalData::Variation
  my @genotyped_snps = 
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ substr($_->type,0,2) * 1e9 + $_->start, $_ ] }
             grep { $_->score < 4 } @{$self->{'container'}->get_all_genotyped_SNPs()};

  # Get all snps using lite: returns Bio::EnsEMBL::SNP obj
 my @snps = 
             map { $_->[1] } 
             sort { $a->[0] <=> $b->[0] }
             map { [ substr($_->type,0,2) * 1e9 + $_->start, $_ ] }
             grep { $_->score < 4 } @{$self->{'container'}->get_all_SNPs()};


  # Now need to link them up: make hash of genotyped snps, key = unique_id
  my %genotyped_snps;
  map { $genotyped_snps{ $_->unique_id } = $_;  } @genotyped_snps;

  foreach my $snp  (@snps) {
    my $genotyped_snp = $genotyped_snps{$snp->unique_id};
    next unless $genotyped_snp;

    # Nasty nasty but need this hack to join the lite and heavy db info
    $genotyped_snp->{'_ambiguity_code'} = $snp->{'_ambiguity_code'};
    $genotyped_snp->{'_type'} = $snp->{'_type'};
    $genotyped_snp->{'_mapweight'} = $snp->{'_mapweight'};
    $genotyped_snp->{'status'} = $snp->status;
  }

  return \@genotyped_snps;
}
1;
