=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2017] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Family::ComparaFamily;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::Gene::Family);

sub init_form {
  ## @override
  my $self      = shift;
  my $form      = $self->SUPER::init_form(@_);
  my $fieldset  = $form->fieldsets->[0];

  # remove form field that contains 'collapsability' element
  $_->remove for grep scalar @{$_->get_elements_by_name('collapsability')}, @{$fieldset->fields};

  return $form;
}

1;
