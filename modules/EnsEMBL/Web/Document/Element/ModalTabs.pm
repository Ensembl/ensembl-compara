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
  my $config     = 'config_' . $hub->param('config');
  $config        =~ s/__/_/; # config paramenter can be _page, so in this case make sure we have the correct value
  
  $self->EnsEMBL::Web::Document::Element::Modal::init($controller);
  
  foreach (@{$self->entries}) {
    if (($type eq 'Config' && $_->{'id'} eq $config) || ($type ne 'Config' && $type eq $_->{'type'})) {
      $_->{'class'} = 'active';
      last;
    }
  }
}

1;
