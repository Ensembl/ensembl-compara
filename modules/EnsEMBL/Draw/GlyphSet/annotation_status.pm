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

package EnsEMBL::Draw::GlyphSet::annotation_status;

### Annotation status display for vega

use strict;

use base qw(EnsEMBL::Draw::GlyphSet_simple);

sub features {
  my $self     = shift;
  my @features = @{$self->{'container'}->get_all_MiscFeatures('NoAnnotation')};
  
  foreach my $f (@features) {
    my ($ms) = @{$f->get_all_MiscSets('NoAnnotation')};
    $f->{'_miscset_code'} = $ms->code;
  }
  
  return \@features;
}

sub colour_key { return 'NoAnnotation'; }

sub title {
  my ($self, $f) = @_;
  return $self->my_colour($f->{'_miscset_code'}, 'text');
}

sub tag {
  my ($self, $f) = @_;
  my $colour = $self->my_colour($f->{'_miscset_code'}, 'join');
  
  return {
    style  => 'join',
    tag    => "$f->{'start'}-$f->{'end'}",
    colour => $colour,
    zindex => -20,
  };
}

1;
