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

package EnsEMBL::Draw::GlyphSet::fg_regulatory_features_legend;

### Legend for regulatory features track

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self = shift;

  ## Hide if corresponding tracks are all off
  my $show = 0;

  ## Check main regulatory build track
  my $reg_build = $self->{'config'}->get_node('regulatory_build');
  if ($reg_build && $reg_build->get('display') && $reg_build->get('display') ne 'off') {
    $show = 1;
  }

  ## Also check regulatory features
  unless ($show) {
    my $node = $self->{'config'}->get_node('regulatory_features');
    if ($node) {
      foreach ($node->descendants) {
        if ($_->get('display') && $_->get('display') ne 'off') {
          $show = 1;
          last;
        }
      }
    }
  }
  return unless $show; 
 
  my $entries     = $self->{'legend'}{'fg_regulatory_features_legend'}{'entries'} || {};
  my $activities  = $self->{'legend'}{'fg_regulatory_features_legend'}{'activities'} || {};
  return unless scalar keys %$entries;

  # Let them accumulate in structure if accumulating and not last
  my $Config         = $self->{'config'};
  return if ($self->my_config('accumulate') eq 'yes' &&
             $Config->get_parameter('more_slices'));
  # Clear features (for next legend)
  $self->{'legend'}{[split '::', ref $self]->[-1]} = {};
  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};
 
  $self->init_legend();
 
  my $empty = 1;

  foreach (sort keys %$entries) {
    $self->add_to_legend($entries->{$_});
    $empty = 0;
  }

  unless($empty) {
    if (scalar keys %$activities) {
      $self->add_space;
      foreach (sort keys %$activities) {
        $self->add_to_legend($activities->{$_});
      }
    }
  }
  
  $self->errorTrack('No Regulatory Features in this panel') if $empty;

  $self->add_space;
}

1;
