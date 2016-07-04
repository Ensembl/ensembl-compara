=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ImageConfig::lrgsnpview_snps;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub init {
  my ($self) = @_;  

  $self->set_parameters({
    title       => 'SNPs',
    show_labels => 'no',   # show track names on left-hand side
    label_width => 100,     # width of labels on left-hand side
    bgcolor     => 'background1',
    bgcolour1   => 'background3',
    bgcolour2   => 'background1',
  });
  
  $self->create_menus(
    other => 'Decorations',
  );
  
  $self->add_tracks('other',
    [ 'snp_fake',             '', 'snp_fake',             { display => 'on',  strand => 'f', colours => $self->species_defs->colour('variation'), tag => 2 }],
    [ 'variation_legend',     '', 'variation_legend',     { display => 'on',  strand => 'r', caption => 'Variant Legend' }],
    [ 'snp_fake_haplotype',   '', 'snp_fake_haplotype',   { display => 'off', strand => 'r', colours => $self->species_defs->colour('haplotype') }],
    [ 'tsv_haplotype_legend', '', 'tsv_haplotype_legend', { display => 'off', strand => 'r', colours => $self->species_defs->colour('haplotype'), caption => 'Haplotype legend', src => 'all' }],      
  );
 
  $self->load_tracks;
}

1;

