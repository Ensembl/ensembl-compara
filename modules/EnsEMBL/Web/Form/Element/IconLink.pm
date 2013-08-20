package EnsEMBL::Web::Form::Element::IconLink;

use strict;

use base qw(EnsEMBL::Web::Form::Element::NoEdit);

use constant CSS_CLASS => 'ff-icon-link';

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  $params->{'is_html'}        = 1; # forced to be on so it's always a div
  $params->{'no_input'}       = 1; # don't need any hidden input
  $params->{'caption_class'}  = [ $self->CSS_CLASS, $params->{'caption_class'} || () ];
  $params->{'caption'}        = sprintf '<a href="#"%s><span class="sprite %s_icon">%s</span></a>', $params->{'link_class'} ? qq( class="$params->{'link_class'}") : '', $params->{'link_icon'}, $params->{'caption'};

  $self->SUPER::configure($params);
}

sub caption {} # disabling this method since this exists in the parent module

1;