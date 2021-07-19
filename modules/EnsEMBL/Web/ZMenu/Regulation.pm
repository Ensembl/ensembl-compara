=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ZMenu::Regulation;

use strict;

use List::Util qw(first);

use base qw(EnsEMBL::Web::ZMenu::RegulationBase);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $rf   = $hub->param('rf');
  
  return unless $rf; 
  
  my $cell_line   = $hub->param('cl');
  my $reg_feature = $hub->database('funcgen')->get_RegulatoryFeatureAdaptor->fetch_by_stable_id($rf);

  my $caption = 'Regulatory Feature';
  $caption .= ' - '.$cell_line if $cell_line;
  $self->caption($caption);
  
  my $object         = $self->new_object('Regulation', $reg_feature, $self->object->__data);
  
  $self->add_entry({
    type  => 'Stable ID',
    label => $object->stable_id,
    link  => $object->get_summary_page_url
  });
  
  $self->add_entry({
    type  => 'Type',
    label => $object->feature_type->name
  });
  
  $self->add_entry({
    type        => 'Core bp',
    label       => sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $self->thousandify($object->seq_region_start),
      $self->thousandify($object->seq_region_end)
    ),
    link        => $object->get_location_url,
    link_class  => '_location_change _location_mark'
  });

  unless ($object->bound_start == $object->seq_region_start && $object->bound_end == $object->seq_region_end) {
    $self->add_entry({
      type        => 'Bounds bp',
      label       => sprintf(
        '%s: %s-%s',
        $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
        $self->thousandify($object->bound_start),
        $self->thousandify($object->bound_end)
      ),
      link        => $object->get_bound_location_url,
      link_class  => '_location_change _location_mark'
    });
  }

  my $epigenome;
  if ($cell_line) {
    $epigenome = $hub->database('funcgen')->get_EpigenomeAdaptor->fetch_by_short_name($cell_line);
    
    if ($epigenome) {
      $self->add_entry({
        type => 'Status',
        label => $object->activity($epigenome),
      });
    }
  }
  
  $self->_add_nav_entries;
  
  $self->_add_motif_feature_table($self->get_motif_features_by_epigenome($reg_feature, $epigenome));

}

1;
