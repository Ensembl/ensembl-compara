# $Id$

package EnsEMBL::Web::ViewConfig::Location::MultiBottom;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;

  $self->set_defaults({
    show_bottom_panel => 'yes'
  });
  
  $self->add_image_config('MultiBottom', 'nodas');
  $self->title = 'Multi-species Image';
  
  $self->set_defaults({
    opt_pairwise_blastz => 'normal',
    opt_pairwise_tblat  => 'normal',
    opt_join_genes      => 'off',
  });
}

sub extra_tabs {
  my $self = shift;
  my $hub  = $self->hub;
  
  return [
    'Select species',
    $hub->url('Component', {
      action   => 'Web',
      function => 'MultiSpeciesSelector/ajax',
      time     => time,
      %{$hub->multi_params}
    })
  ];
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Comparative features');
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    label  => 'BLASTz/LASTz net pairwise alignments',
    name   => 'opt_pairwise_blastz',
    values => [
      { value => 0,         name => 'Off'     },
      { value => 'normal',  name => 'Normal'  },
      { value => 'compact', name => 'Compact' },
    ],
  });
  
  $self->add_form_element({
    type   => 'DropDown',
    select => 'select',
    label  => 'Translated BLAT net pairwise alignments',
    name   => 'opt_pairwise_tblat',
    values => [
      { value => 0,         name => 'Off'     },
      { value => 'normal',  name => 'Normal'  },
      { value => 'compact', name => 'Compact' },
    ],
  });
  
  $self->add_form_element({
    type  => 'CheckBox', 
    label => 'Join genes',
    name  => 'opt_join_genes',
    value => 'on',
  });
  
  $self->add_fieldset('Display options');
  
  $self->add_form_element({ type => 'YesNo', name => 'show_bottom_panel', select => 'select', label => 'Show panel' });
}

1;
