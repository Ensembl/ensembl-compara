# $Id$

package EnsEMBL::Web::ZMenu::Reference;

use strict;

use base qw(EnsEMBL::Web::ZMenu);

sub content {
  my $self = shift;
  my $hub  = $self->hub;
  my $ref  = $hub->param('reference');
  
  return unless $ref;
  
  $self->caption('Reference');
  
  $self->add_entry({
    label_html => "Compare to $ref",
    link       => $hub->url({ action => 'Population/Image', reference => $ref })
  });
}

1;
