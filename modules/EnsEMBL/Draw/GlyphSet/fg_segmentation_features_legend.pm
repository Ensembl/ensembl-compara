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

package EnsEMBL::Draw::GlyphSet::fg_segmentation_features_legend;

### Legend showing colours used in segmentation bigbed files 

use strict;

use base qw(EnsEMBL::Draw::GlyphSet::legend);

sub _init {
  my $self = shift;

  ## Hide if corresponding tracks are all off
  my $node = $self->{'config'}{'_tree'}->get_node('seg_features');
  return unless $node;
  my $show = 0;
  foreach ($node->descendants) {
    if ($_->get('display') && $_->get('display') ne 'off') {
      $show = 1;
      last;
    }
  }
  return unless $show;

  my @features = @{$self->{'legend'}{'fg_segmentation_features_legend'}{'entries'}||[]};
  return unless @features;

  # Let them accumulate in structure if accumulating and not last
  my $Config         = $self->{'config'};
  return if ($self->my_config('accumulate') eq 'yes' &&
             $Config->get_parameter('more_slices'));
  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};
  # Clear features (for next legend)
  $self->{'legend'}{[split '::', ref $self]->[-1]} = {};
  return unless $self->{'legend'}{[split '::', ref $self]->[-1]};

  $self->init_legend();

  my $empty = 1;

  foreach (@features) {
    my ($key, $colour) = @$_;
    my $legend = $self->my_colour($key, 'text');
    if ($legend =~ /unknown/i) {
      $legend = ucfirst($key);
    }
    $colour ||= $self->my_colour($key);

    $self->add_to_legend({
      legend => $legend,
      colour => $colour,
    });

    $empty = 0;
  }

  $self->errorTrack('No Segmentation Features in this panel') if $empty;

  $self->add_space;
}

1;
