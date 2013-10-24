# $Id$

package EnsEMBL::Web::Document::Element::ModalTabs;

# Generates the global context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element::Tabs EnsEMBL::Web::Document::Element::Modal);

sub init {
  my $self       = shift;
  my $controller = shift;
  my $hub        = $self->hub;
  my $type       = $controller->page_type eq 'Configurator' ? 'Config' : $hub->type;
  my $config     = 'config_' . $hub->action;
  
  $self->EnsEMBL::Web::Document::Element::Modal::init($controller);
  
  foreach (@{$self->entries}) {
    if (($type eq 'Config' && $_->{'id'} eq $config) || ($type eq 'UserData' && $_->{'id'} eq 'user_data')) {
      $_->{'class'} = 'active';
      $self->active = 'modal_' . lc $_->{'id'};
      last;
    }
  }
}

sub get_json {
  my $self    = shift;
  my $content = $self->content;
  return $content ? { tabs => $content, activeTab => $self->active } : {};
}

1;
