# $Id$

package EnsEMBL::Web::Document::Content;

use strict;

sub new {
  my $class = shift;
  
  my $self = {
    _renderer => undef,
    panels    => []
  };
  
  bless $self, $class;
  return $self;
}

sub renderer :lvalue { $_[0]->{'_renderer'}; }

sub printf { my $self = shift; $self->renderer->printf(@_) if $self->renderer; }
sub print  { my $self = shift; $self->renderer->print(@_)  if $self->renderer; }

sub add_panel {
  my ($self, $panel) = @_;
  push @{$self->{'panels'}}, $panel;
}

sub panel {
  my ($self, $code) = @_;
  
  foreach (@{$self->{'panels'}}) {
    return $_ if $code eq $_->{'code'};
  }
  
  return undef;
}

sub render {
  my $self = shift;
  return $self->print($self->_content);
}

sub _content {
  my $self = shift;
  my $content;
  
  foreach my $panel (@{$self->{'panels'}}) {
    next if $panel->{'code'} eq 'summary_panel';
    
    $panel->{'disable_ajax'} = 1;
    $panel->renderer = $self->renderer;
    $content .= $panel->component_content;
  }
  
  return $content;
}

sub init {
  my $self       = shift;
  my $controller = shift;
  my $node       = $controller->node;
  
  return unless $node;
  
  my $hub           = $controller->hub;
  my $object        = $controller->object;
  my $configuration = $controller->configuration;
  
  $configuration->{'availability'} = $object ? $object->availability : {};

  my %params = (
    object      => $object,
    code        => 'main',
    omit_header => 1
  );
  
  my $panel = $configuration->new_panel('Navigation', %params);
   
  if ($panel) {
    $panel->add_components(@{$node->data->{'components'}});
    $self->add_panel($panel);
  }
}

1;
