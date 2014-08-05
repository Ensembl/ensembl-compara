=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Regulation::Page;

# Really this should be a superclass for regulation VeiwConfigs, but the
# code picks that package name up even for components without viewconfigs in
# their own right (eg Buttons component).

use strict;

use base qw(EnsEMBL::Web::ViewConfig);
use List::MoreUtils qw(firstidx);

sub reg_extra_tabs {
  my $self = shift;
  my $hub  = $self->hub;
  
  return ([
    'Select cell types',
    $hub->url('Component', {
      action   => 'Web',
      function => 'CellTypeSelector/ajax',
      time     => time,
      %{$hub->multi_params}
    })],[
    'Select evidence',
    $hub->url('Component', {
      action   => 'Web',
      function => 'EvidenceSelector/ajax',
      time     => time,
      %{$hub->multi_params}
    })],
  );
}

sub reg_renderer {
  my ($self,$hub,$image_config,$renderer,$state) = @_;

  my $mask = firstidx { $renderer eq $_ } qw(x peaks signals);
  my $image_config = $hub->get_imageconfig($image_config);
  foreach my $type (qw(reg_features seg_features reg_feats_core reg_feats_non_core)) {
    my $menu = $image_config->get_node($type);
    next unless $menu;
    foreach my $node (@{$menu->child_nodes}) {
      my $old = $node->get('display');
      my $renderer = firstidx { $old eq $_ }
        qw(off compact tiling tiling_feature);
      next if !$renderer;
      $renderer |= $mask if $state;
      $renderer &=~ $mask unless $state;
      $renderer = 1 unless $renderer;
      $renderer = [ qw(off compact tiling tiling_feature) ]->[$renderer];
      $image_config->update_track_renderer($node->id,$renderer);
    }
  }
  $hub->session->store;
}

sub update_from_url {  
  my ($self, $r, $delete_params) = @_;

  my $modified = 0;
  my $input = $self->hub->input;
  my $plus = $input->param('plus_signal');
  if($plus) {
    $self->reg_renderer($self->hub,$plus,'signals',1);
    if($delete_params) {
      $input->delete('plus_signal');
      $modified = 1;
    }
  }
  return $self->SUPER::update_from_url($r,$delete_params) || $modified;
}

1;
