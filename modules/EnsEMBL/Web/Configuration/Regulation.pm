package EnsEMBL::Web::Configuration::Regulation;

use strict;

sub global_context { return $_[0]->_global_context; }
sub ajax_content   { return $_[0]->_ajax_content;   }
sub configurator   { return $_[0]->_configurator;   }
sub local_context  { return $_[0]->_local_context;  }
sub local_tools    { return $_[0]->_local_tools;    }
sub content_panel  { return $_[0]->_content_panel;  }
sub context_panel  { return $_[0]->_context_panel;  }

use base qw(EnsEMBL::Web::Configuration);

sub set_default_action {
  my $self = shift;
  
  if (!ref $self->object){
    $self->{'_data'}->{'default'} = 'Cell_line';
    return;
  }
  
  my $x = $self->object->availability || {};
  
  if ($x->{'regulation'}) {
    $self->{'_data'}->{'default'} = 'Summary';
  }
}

sub populate_tree {
  my $self = shift;
  $self->create_node('Summary', 'Summary',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeatureDetails )],
    { 'availability' => 'regulation', 'concise' => 'Summary' }
  );

  $self->create_node('Cell_line', 'Details by cell line',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeaturesByCellLine )],
    { 'availability' => 'regulation', 'concise' => 'Features by cell line' }
  );

  $self->create_node('Context', 'Context',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeatureSummary )],
    { 'availability' => 'regulation', 'concise' => 'Feature context' }
  );
  
  $self->create_node('Evidence', 'Evidence',
    [qw( summary EnsEMBL::Web::Component::Regulation::Evidence )],
    { 'availability' => 'regulation', 'concise' => 'Evidence' }
  );
}

1;
