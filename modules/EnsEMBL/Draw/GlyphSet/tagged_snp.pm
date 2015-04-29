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

package EnsEMBL::Draw::GlyphSet::tagged_snp;

### Draws the Tagged SNPs track on /Location/LD

use strict;


use base qw(EnsEMBL::Draw::GlyphSet::_variation);

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

