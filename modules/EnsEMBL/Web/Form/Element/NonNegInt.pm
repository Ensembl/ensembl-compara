=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Form::Element::NonNegInt;

use strict;

use base qw(EnsEMBL::Web::Form::Element::String);

use constant {
  VALIDATION_CLASS =>  '_nonnegint',
};

sub configure {
  ## @overrides
  my ($self, $params) = @_;
  if ($params->{'max'}) {
    $params->{'shortnote'}   .= sprintf '(Maximum of %s)', $params->{'max'};
    $params->{'class'}        = [] unless exists $params->{'class'} && defined $params->{'class'};

    if (ref $params->{'class'}) {
      push @{$params->{'class'}}, 'max_'.$params->{'max'};
    } else {
      $params->{'class'} .= ' max_'.$params->{'max'};
    }
  }
  $self->SUPER::configure($params);
}

1;
