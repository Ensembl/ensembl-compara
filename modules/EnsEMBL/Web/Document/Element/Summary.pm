# $Id$

package EnsEMBL::Web::Document::Element::Summary;

# Generates the top summary panel in dynamic pages

use strict;

use base qw(EnsEMBL::Web::Document::Element);

sub init {
  my $self       = shift;
  my $controller = shift;
  my $object     = $controller->object;
  my $caption    = $object ? $object->caption : $controller->configuration->caption;
  my $component  = sprintf 'EnsEMBL::Web::Component::%s::%s', $controller->type, $controller->action eq 'Multi' ? 'MultiIdeogram' : 'Summary';
  
  return unless $self->dynamic_use($component);
  
  my $panel = $self->new_panel('Summary',
    $controller,
    code    => 'summary_panel',
    caption => $caption
  );
  
  $panel->add_component('summary', $component);
  $controller->page->content->add_panel($panel);
}

1;