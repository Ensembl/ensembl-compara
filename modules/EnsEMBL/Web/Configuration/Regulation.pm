# $Id$

package EnsEMBL::Web::Configuration::Regulation;

use strict;

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  $self->{'_data'}->{'default'} = $self->object ? $self->object->default_action : 'Summary';
}

sub populate_tree {
  my $self = shift;
  $self->create_node('Summary', 'Summary',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeatureDetails )],
    { 'availability' => 'regulation', 'concise' => 'Summary' }
  );

  $self->create_node('Cell_line', 'Details by cell line',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeaturesByCellLine )],
    { 'availability' => 'regulation', 'concise' => 'Details by cell line' }
  );

  $self->create_node('Context', 'Feature Context',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeatureSummary )],
    { 'availability' => 'regulation', 'concise' => 'Feature context' }
  );
  
  $self->create_node('Evidence', 'Evidence',
    [qw( summary EnsEMBL::Web::Component::Regulation::Evidence )],
    { 'availability' => 'regulation', 'concise' => 'Evidence' }
  );
}

1;
