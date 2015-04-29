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

package EnsEMBL::Draw::GlyphSet::_repeat;

### Draws repeat feature tracks as simple (grey) blocks

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub features {
  my $self        = shift;
  my $types       = $self->my_config('types');
  my $logic_names = $self->my_config('logic_names');
  my @repeats     = sort { $a->seq_region_start <=> $b->seq_region_end } map { my $t = $_; map @{$self->{'container'}->get_all_RepeatFeatures($t, $_)}, @$types } @$logic_names;

  $self->errorTrack(sprintf 'No %s features in this region', $self->my_config('name')) unless scalar @repeats >= 1 || $self->{'config'}->get_option('opt_empty_tracks') == 0;
  
  return \@repeats;
}

sub colour_key { return 'repeat'; }
sub class      { return 'group'; }
sub title      { return sprintf '%s; bp: %s-%s; length: %s', $_[1]->repeat_consensus->name, $_[1]->seq_region_start, $_[1]->seq_region_end, $_[1]->length; }

sub href {
  my ($self, $f)  = @_;
  
  return $self->_url({
    species => $self->species,
    type    => 'Repeat',
    id      => $f->dbID
  });
}

sub export_feature {
  my ($self, $feature) = @_;
  my $id = "repeat:$feature->{'dbID'}";
  
  return if $self->{'export_cache'}{$id};
  
  $self->{'export_cache'}{$id} = 1;
  
  return $self->_render_text($feature, 'Repeat', undef, { source => $feature->display_id });
}

1;
