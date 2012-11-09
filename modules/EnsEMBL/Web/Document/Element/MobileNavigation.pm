# $Id$

package EnsEMBL::Web::Document::Element::MobileNavigation;

# Alternative to the left sided navigation menu, shown on mobile devices

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element::Navigation);

sub content {
  my $self = shift;
  my $tree = $self->tree;
  
  return unless $tree;
  
  my $active = $self->active;
  my @nodes  = grep { $_->can('data') && !$_->data->{'no_menu_entry'} && $_->data->{'caption'} } @{$tree->child_nodes};
  my $menu;
  
  if ($tree->get_node($active) || $nodes[0]) {
    $menu .= $_->render for @nodes;
  }
  
  return sprintf('
    <div id="mobile_context">
      <h2>%s</h2>
      <ul class="mobile_context">%s</ul>
    </div>',
    encode_entities($self->strip_HTML($self->caption)),
    $menu
  );
}

1;
