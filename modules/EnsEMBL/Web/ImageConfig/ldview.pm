# $Id$

package EnsEMBL::Web::ImageConfig::ldview;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

sub menus {
  return (
    population  => 'Population features',
    transcript  => 'Genes',
    prediction  => 'Prediction transcripts',
    variation   => 'Germline variation',
    somatic     => 'Somatic Mutations',
    other       => 'Additional decorations',
    information => 'Information',
  );
}

sub init {
  my $self    = shift;
  my $colours = $self->species_defs->colour('variation');
  
  $self->set_parameters({
    show_labels  => 'yes', # show track names on left-hand side
    label_width  => 100,   # width of labels on left-hand side
    title        => 'LD Panel',
  });
  
  $self->create_menus($self->menus);
  
  $self->load_tracks;
  
  $self->add_tracks('population',
    [ 'text',       '', 'text',       { display => 'normal', strand => 'r', menu    => 'no'                                                                                       }],
    [ 'tagged_snp', '', 'tagged_snp', { display => 'normal', strand => 'r', colours => $colours, caption => 'Tagged SNPs',  name => 'Tagged SNPs', depth => 10000, style => 'box' }],
    [ 'ld_r2',      '', 'ld',         { display => 'normal', strand => 'r', colours => $colours, caption => 'LD (r2)',      name => 'LD (r2)', key => 'r2',                       }],
    [ 'ld_d_prime', '', 'ld',         { display => 'normal', strand => 'r', colours => $colours, caption => 'LD (d_prime)', name => "LD (d')", key => 'd_prime'                   }],
  );
  
  $self->add_tracks('other',
    [ 'scalebar', '', 'scalebar', { display => 'normal', strand => 'r', name => 'Scale bar', description => 'Shows the scalebar'                             }],
    [ 'ruler',    '', 'ruler',    { display => 'normal', strand => 'f', name => 'Ruler',     description => 'Shows the length of the region being displayed' }],
  );
  
  $self->modify_configs(
    [ 'transcript_core_ensembl' ],
    { display => 'transcript_label' }
  );
  
  $self->modify_configs(
    [ 'variation_feature_variation' ],
    { display => 'normal', caption => 'Variations', strand => 'r' }
  );
}

sub init_slice {
  my ($self, $parameters) = @_;
  
  $self->set_parameters({
    %$parameters,
    _userdatatype_ID   => 30,
    _transcript_names_ => 'yes',
    context            => 20000,
  });
  
  $self->get_node('population')->remove;
}

sub init_population {
  my ($self, $parameters, $pop_name) = @_;
  my %menus = $self->menus;
  
  $self->set_parameters($parameters);
  
  $self->{'_ld_population'} = [ $pop_name ];
  
  $self->get_node('text')->set('text', $pop_name);
  $self->get_node($_)->remove for grep $_ ne 'population', keys %menus;
}

1;

