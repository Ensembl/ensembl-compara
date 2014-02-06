=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

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