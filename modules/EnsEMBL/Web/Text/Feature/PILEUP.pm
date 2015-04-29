=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Text::Feature::PILEUP;

### Pileup for SNP data (e.g. for Variant Effect Predictor)

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Text::Feature::SNP);
use Bio::EnsEMBL::Variation::Utils::Sequence qw/unambiguity_code/;

sub new {
  my( $class, $args ) = @_;
  
  my @new_args = ();
  
  # normal variation
  if($args->[2] ne "*"){
	my $var;
	
	if($args->[2] =~ /^[A|C|G|T]$/) {
	  $var = $args->[2];
	}
	else {
	  ($var = unambiguity_code($args->[3])) =~ s/$args->[2]//ig;
	}
	if(length($var)==1){
	  @new_args = ($args->[0], $args->[1], $args->[1], $args->[2]."/".$var, 1, undef);
	}
	else{
	  for my $nt(split //,$var){
		@new_args = ($args->[0], $args->[1], $args->[1], $args->[2]."/".$nt, 1, undef);
		last; # we can only create one feature per line in pileup unforunately
	  }
	}
  }
  
  # indel
  else{
	my %tmp_hash = map {$_ => 1} split /\//, $data[3];
	my @genotype = keys %tmp_hash;
	foreach my $allele(@genotype){
	  if(substr($allele,0,1) eq "+") { #ins
		@new_args = ($args->[0], $args->[1]+1, $args->[1], "-/".substr($allele,1), 1, undef);
		last;
	  }
	  elsif(substr($allele,0,1) eq "-"){ #del
		@new_args = ($args->[0], $args->[1] + 1, $args->[1]+length(substr($allele, 1)), substr($allele,1)."/-", 1, undef);
	  }
	}
  }
  
  return bless { '__raw__' => \@new_args }, $class;
}
 

1;