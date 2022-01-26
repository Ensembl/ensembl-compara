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

package EnsEMBL::Web::ZMenu::Repeat;

use strict;

use EnsEMBL::Draw::GlyphSet::repeat;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self       = shift;
  my $hub        = $self->hub;
  my $id         = $hub->param('id');
  my $click_data = $self->click_data;
  my @features;
  
  if ($click_data) {
    @features = @{EnsEMBL::Draw::GlyphSet::repeat->new($click_data)->features};
    @features = () unless grep $_->dbID eq $id, @features;
  }
  
  @features = $hub->get_adaptor('get_RepeatFeatureAdaptor')->fetch_by_dbID($id) unless scalar @features;
  
  $self->feature_content($_) for @features;
}

sub feature_content {
  my ($self, $f) = @_;
  my $consensus = $f->repeat_consensus;
  my $analysis  = $f->analysis;
  
  $self->new_feature;
  $self->caption($consensus->name);
  $self->add_entry({ type  => 'Location',    label      => sprintf('%s:%s-%s', $f->seq_region_name, $f->seq_region_start, $f->seq_region_end) });
  $self->add_entry({ type  => 'Length',      label      => $f->length });
  $self->add_entry({ type  => 'Strand',      label      => $f->strand }) if $f->strand;
  $self->add_entry({ type  => 'Type',        label      => $consensus->repeat_type });
  $self->add_entry({ type  => 'Class',       label      => $consensus->repeat_class });
  $self->add_entry({ type  => 'Consensus',   label_html => sprintf '<div style="word-break:break-all">%s</div>', $consensus->repeat_consensus });
  $self->add_entry({ type  => 'Analysis',    label_html => $analysis->display_label });
  $self->add_entry({ type  => 'Description', label_html => $analysis->description });
}

1;
  
