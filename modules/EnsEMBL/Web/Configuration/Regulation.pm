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
    $self->{'_data'}->{'default'} = 'Details';
    return;
  }
  
  my $x = $self->availability || {};
  
  if ($x->{'regulation'}) {
    $self->{'_data'}->{'default'} = 'Details';
  }
}

sub availability {
  my $self = shift;
  my $hash = $self->default_availability;
  if ($self->model->api_object('Regulation')->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature')){
    $hash->{'regulation'} =1;
  }
  return $hash;
}

sub counts {
  my $self = shift;
  my $obj = $self->model->api_object('Regulation');
  return {} unless $obj->isa('Bio::EnsEMBL::Funcgen::RegulatoryFeature');
  return {};
}

sub short_caption {
  my $self = shift;
  return 'Regulation-based displays';
}

sub caption {
 my $self = shift; 
 my $caption = 'Regulatory Feature: '.$self->model->object('Regulation')->stable_id;

 return $caption;
}   

sub populate_tree {
  my $self = shift;

  $self->create_node('Details', 'Details',
    [qw( summary EnsEMBL::Web::Component::Regulation::FeatureDetails )],
    { 'availability' => 'regulation', 'concise' => 'Feature in detail' }
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
