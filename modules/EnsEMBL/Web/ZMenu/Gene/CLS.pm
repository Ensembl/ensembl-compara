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

package EnsEMBL::Web::ZMenu::Gene::CLS;

use strict;

use Bio::EnsEMBL::SubSlicedFeature;
use EnsEMBL::Web::Utils::FormatText qw(helptip);

use base qw(EnsEMBL::Web::ZMenu::Gene);

sub content {
  my $self        = shift;
  my $hub         = $self->hub;
  my $object      = $self->object;
  my $gene;

  eval {
    $gene = $object->gene;
  };

  if ($@) {
    $gene = $object->gene;
  }

  $self->caption($gene->stable_id . ' (Long-Seq)');
  
  $self->add_entry({
    type  => 'Location',
    label => sprintf(
      '%s: %s-%s',
      $self->neat_sr_name($object->seq_region_type, $object->seq_region_name),
      $self->thousandify($object->seq_region_start),
      $self->thousandify($object->seq_region_end)
    ),
    link_class => '_location_change _location_mark',
    link  => $hub->url({
      type   => 'Location',
      action => 'View',
      r      => $object->seq_region_name . ':' . $object->seq_region_start . '-' . $object->seq_region_end
    })
  });
    
  $self->add_entry({
    type  => 'Strand',
    label => $object->seq_region_strand < 0 ? 'Reverse' : 'Forward'
  });

  my $analysis = $gene->analysis;
  my $source = $gene->source;

  $self->add_entry({
    type        => 'Source',
    label_html  => helptip($analysis->display_label, $analysis->description)
  });
}

1;
