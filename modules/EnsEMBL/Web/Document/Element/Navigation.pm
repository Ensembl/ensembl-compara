# $Id$

package EnsEMBL::Web::Document::Element::Navigation;

# Base class for left sided navigation menus

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    tree    => undef,
    active  => undef,
    caption => 'Local context',
    counts  => {}
  });
}

sub tree {
  my $self = shift;
  $self->{'tree'} = shift if @_;
  return $self->{'tree'};
}

sub active {
  my $self = shift;
  $self->{'active'} = shift if @_;
  return $self->{'active'};
}

sub caption {
  my $self = shift;
  $self->{'caption'} = shift if @_;
  return $self->{'caption'};
}

sub counts {
  my $self = shift;
  $self->{'counts'} = shift if @_;
  return $self->{'counts'} || {};
}

sub configuration {
  my $self = shift;
  $self->{'configuration'} = shift if @_;
  return $self->{'configuration'};
}

sub availability {
  my $self = shift;
  $self->{'availability'} = shift if @_;
  $self->{'availability'} ||= {};
  return $self->{'availability'};
}

sub buttons {
  my $self = shift;
  return $self->{'_buttons'} || [];
}

sub add_button {
  my $self = shift;
  push @{$self->{'_buttons'}}, @_;
}


sub get_json {
  my $self = shift;
  return { nav => $self->content };
}

sub init {
  my $self          = shift;
  my $controller    = shift;    
  my $object        = $controller->object;
  my $hub           = $controller->hub;
  my $configuration = $controller->configuration;
  return unless $configuration;
  my $action        = $configuration->get_valid_action($hub->action, $hub->function);
 
  $self->tree($configuration->{'_data'}{'tree'});
  $self->active($action);
  $self->caption(ref $object && $object->short_caption ? $object->short_caption : $configuration->short_caption);
  $self->counts($object->counts) if ref $object;
  $self->availability(ref $object ? $object->availability : {});     
  
  $self->{'hub'} = $hub;

  $self->modify_init($controller);
}

## Implement in subclasses

sub content {}

sub build_menu {}

sub modify_init {}

1;
