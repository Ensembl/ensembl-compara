# $Id$

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
    [ 'variation_legend',     '', 'variation_legend',     { display => 'on',  strand => 'r', caption => 'Variation legend' }],
    [ 'snp_fake_haplotype',   '', 'snp_fake_haplotype',   { display => 'off', strand => 'r', colours => $self->species_defs->colour('haplotype') }],
    [ 'tsv_haplotype_legend', '', 'tsv_haplotype_legend', { display => 'off', strand => 'r', colours => $self->species_defs->colour('haplotype'), caption => 'Haplotype legend', src => 'all' }],      
  );
 
  $self->load_tracks;
}

1;

