=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Regulation::Summary;

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component::Regulation);


sub _init {
  my $self = shift;
  $self->cacheable( 0 );
  $self->ajaxable(  0 );
}

sub _location_url {
  my ($self,$start,$end) = @_;

  my $object  = $self->object;
  my $url = $self->hub->url({
    'type'   => 'Location',
    'action' => 'View',
    'r'      => $object->seq_region_name.':'.$start.'-'.$end
  });

  my $location_html = sprintf('<p><a href="%s" class="constant">%s: %s-%s</a></p>',
    $url,
    $object->neat_sr_name( $object->seq_region_type, $object->seq_region_name ),
    $object->thousandify( $start ),
    $object->thousandify( $end ),
  );
}

sub content {
  my $self    = shift;
  my $object  = $self->object;
  my $summary = $self->new_twocol;

  $self->nav_buttons;
  my $location_html = $self->_location_url($object->seq_region_start,
                                           $object->seq_region_end);
  my $bound_html = $self->_location_url($object->bound_start,
                                        $object->bound_end);

  my @class = ($object->feature_type->name);

  $summary->add_row('Classification',join(', ',@class));
  $summary->add_row('Location', $location_html);
  $summary->add_row('Bound region', $bound_html) if $location_html ne $bound_html;

  my $nav_buttons = $self->nav_buttons;
  return $nav_buttons.$summary->render;
}

1;
