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

package EnsEMBL::Web::ViewConfig::Location::Compara_Alignments;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::Compara_Alignments);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_default_options({'strand' => 1});
}

sub field_order {
  ## @override
  my @order = shift->SUPER::field_order(@_);

  # add strand
  splice @order, 1, 0, 'strand';

  # remove flank display
  return grep !m/flank(3|5)_display/, @order;
}

1;
