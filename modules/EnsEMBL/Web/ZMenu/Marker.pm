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

package EnsEMBL::Web::ZMenu::Marker;

use strict;

use EnsEMBL::Draw::GlyphSet::marker;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $m          = $hub->param('m');
  my $click_data = $self->click_data;
  my @features;
  
  if ($click_data) {
    my $glyphset = EnsEMBL::Draw::GlyphSet::_marker->new($click_data);
    $glyphset->{'text_export'} = 1;
    @features = @{$glyphset->features};
    @features = () unless grep $_->{'drawing_id'} eq $m, @features;
  }
  
  @features = { drawing_id => $m } unless scalar @features;
  
  $self->feature_content($_) for @features;
}

sub feature_content {
  my ($self, $f) = @_;
  my $hub = $self->hub;
  
  $self->new_feature;
  $self->caption($f->{'drawing_id'});
  
  $self->add_entry({
    label => 'Marker info.',
    link  => $hub->url({
      type   => 'Marker',
      action => 'Details',
      m      => $f->{'drawing_id'}
    })
  });
}

1;
