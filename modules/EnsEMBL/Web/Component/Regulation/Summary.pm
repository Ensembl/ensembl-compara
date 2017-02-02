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

  my %active;
  my $reg_feat = $object->fetch_by_stable_id;
  my $active_epigenomes = $reg_feat->get_epigenomes_by_activity('ACTIVE');

  foreach my $ag (@{$active_epigenomes}) {
    $active{$ag->display_label} = 1;
  }
  my $num_active = scalar( @{$active_epigenomes});

  my $show        = $self->hub->get_cookie_value('toggle_epigenomes_list') eq 'open';
  my @class = ($object->feature_type->name);

  my $epigenome_count = 0;
  if ( $self->hub->species_defs->databases->{'DATABASE_FUNCGEN'} ) {
    $epigenome_count = grep { $_ > 0 } values %{$self->hub->species_defs->databases->{'DATABASE_FUNCGEN'}->{'tables'}{'cell_type'}{'ids'}};
  }

  $summary->add_row('Classification',join(', ',@class));
  $summary->add_row('Location', $location_html);
  $summary->add_row('Bound region', $bound_html) if $location_html ne $bound_html;

  my $toggle = $num_active > 0 
                ? sprintf('- <a title="Click to show list of epigenomes" rel="epigenomes_list" href="#" class="toggle_link toggle %s _slide_toggle set_cookie ">%s</a></p>
                              <div class="epigenomes_list twocol-cell">
                                <div class="toggleable" style="font-weight:normal;%s">
                                  <ul>%s</ul>
                                </div>
                              </div>',
                            $show ? 'open' : 'closed',
                            $show ? 'Hide' : 'Show',
                            $show ? '' : 'display:none',
                            join('', map "<li>$_</li>", sort {lc($a) cmp lc($b)} keys %active)
                  )
                : '</p>';

  $summary->add_row('Active in', sprintf('<p>%s/%s epigenomes%s', $num_active, $epigenome_count, $toggle));

  my $nav_buttons = $self->nav_buttons;
  return $nav_buttons.$summary->render;
}

1;
