=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Draw::GlyphSet::multiwig;

### Module for drawing multiple bigWig files in a single track 
### (used by some trackhubs via the 'container = multiWig' directive)

use strict;

use parent qw(EnsEMBL::Draw::GlyphSet::bigwig);

sub can_json { return 1; }

sub init {
  my $self = shift;
  $self->{'my_config'}->set('scaleable', 1);
  my $data = [];
  foreach my $track (@{$self->my_config('subtracks')||{}}) {
    my $aref = $self->get_data(undef, $track->{'source_url'});
    ## Override default colour with value from parsed trackhub
    $aref->[0]{'metadata'}{'colour'} = $track->{'colour'};
    push @$data, $aref->[0];
  }
  $self->{'data'} = $data;
}

sub render_signal {
  my $self = shift;
  $self->{'my_config'}->set('drawing_style', ['Graph']);
  $self->{'my_config'}->set('height', 60);
  $self->{'my_config'}->set('multi', 1);
  $self->_render_aggregate;
}


1;
