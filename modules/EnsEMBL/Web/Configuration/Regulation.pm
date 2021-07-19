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

package EnsEMBL::Web::Configuration::Regulation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub init {
  my $self = shift;
  my $hub  = $self->hub;

  $self->SUPER::init;
  return unless $hub->session;

  my $cell_url = $hub->param('cell');
  my $cell_session = $hub->session->get_data(type => 'cell', code => 'cell');
  $cell_session = $cell_session->{$hub->species} if $cell_session;
  if(!$cell_url and $cell_session) {
    my $new_url = $hub->url({
      action => 'Evidence',
      function => undef,
      cell => $cell_session
    });
    $self->tree->get_node('Evidence')->set('url',$new_url);
  }
}

sub has_tabs { return 1; }

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Summary';
}

sub populate_tree {
  my $self = shift;
  $self->create_node('Summary', 'Summary',
    [qw(        buttons EnsEMBL::Web::Component::Regulation::SummaryButtons
        feature_details EnsEMBL::Web::Component::Regulation::FeatureDetails )],
    { 'availability' => 'regulation', 'concise' => 'Summary' }
  );

  $self->create_node('Cell_line', 'Details by cell type',
    [qw( buttons    EnsEMBL::Web::Component::Regulation::Buttons
         cell_line EnsEMBL::Web::Component::Regulation::FeaturesByCellLine )],
    { 'availability' => 'regulation', 'concise' => 'Details by cell type' }
  );

  $self->create_node('Context', 'Feature Context',
    [qw( feature_summary EnsEMBL::Web::Component::Regulation::FeatureSummary )],
    { 'availability' => 'regulation', 'concise' => 'Feature context' }
  );
  
  $self->create_node('Evidence', 'Source Data',
    [qw( evidence EnsEMBL::Web::Component::Regulation::Evidence )],
    { 'availability' => 'regulation', 'concise' => 'Source data' }
  );
}

1;
