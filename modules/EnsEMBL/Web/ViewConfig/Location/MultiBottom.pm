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
  $self->title = 'Comparison Image';
  
  $self->set_defaults({
    opt_pairwise_blastz   => 'normal',
    opt_pairwise_tblat    => 'normal',
    opt_pairwise_lpatch   => 'normal',
    opt_join_genes_bottom => 'off',
  });
}

sub extra_tabs {
  my $self = shift;
  my $hub  = $self->hub;
  
  return [
    'Select species or regions',
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
  
  foreach ([ 'blastz', 'BLASTz/LASTz net pairwise alignments' ], [ 'tblat', 'Translated BLAT net pairwise alignments' ], [ 'lpatch', 'LASTz patch alignments' ]) {
    $self->add_form_element({
      type   => 'DropDown',
      select => 'select',
      name   => "opt_pairwise_$_->[0]",
      label  => $_->[1],
      values => [
        { value => 0,         name => 'Off'     },
        { value => 'normal',  name => 'Normal'  },
        { value => 'compact', name => 'Compact' },
      ],
    });
  }
  
  $self->add_form_element({
    type  => 'CheckBox',
    label => 'Join genes',
    name  => 'opt_join_genes_bottom',
    value => 'on',
  });
  
  $self->add_fieldset('Display options');
  
  $self->add_form_element({ type => 'YesNo', name => 'show_bottom_panel', select => 'select', label => 'Show panel' });
}

1;
