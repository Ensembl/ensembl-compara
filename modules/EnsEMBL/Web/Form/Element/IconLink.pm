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