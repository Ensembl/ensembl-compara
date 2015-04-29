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
        { value => 0,         caption => 'Off'     },
        { value => 'normal',  caption => 'Normal'  },
        { value => 'compact', caption => 'Compact' },
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
