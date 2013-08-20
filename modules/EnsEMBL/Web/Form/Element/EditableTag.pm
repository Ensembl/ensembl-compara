package EnsEMBL::Web::Form::Element::EditableTag;

use strict;

use base qw(EnsEMBL::Web::Form::Element::NoEdit);

use constant {
  CSS_CLASS       => 'editable-tag',
  CSS_CLASS_ICON  => 'et-icon'
};

sub configure {
  ## @overrides
  my ($self, $params) = @_;

  my $dom = $self->dom;

  $params->{'tags'}       = [{ map { exists $params->{$_} ? ($_ => delete $params->{$_}) : () } qw(tag_class tag_type tag_attribs caption value) }] unless $params->{'tags'};
  $params->{'_children'}  = [ map $dom->create_element('div', {
    %{$_->{'tag_attribs'} || {}},
    'class'       => [ ref $_->{'tag_class'} ? @{$_->{'tag_class'}} : $_->{'tag_class'} || (), $self->CSS_CLASS, $_->{'tag_type'} || () ],
    'inner_HTML'  => sprintf('<span>%s</span><span class="%s"></span>%s', $_->{'caption'} || '', $self->CSS_CLASS_ICON, $params->{'no_input'} ? '' : qq(<input type="hidden" name="$params->{'name'}" value="$_->{'value'}">))
  }), @{delete $params->{'tags'}} ];
  $params->{'no_input'}   = 1;

  $self->SUPER::configure($params);
}

sub caption {} # disabling this method since this exists in the parent module

1;