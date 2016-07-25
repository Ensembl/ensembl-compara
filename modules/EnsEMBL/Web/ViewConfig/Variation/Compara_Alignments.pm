=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::ViewConfig::Variation::Compara_Alignments;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ViewConfig::Compara_Alignments);

sub init_cacheable {
  ## @override
  my $self = shift;

  $self->SUPER::init_cacheable(@_);

  $self->set_default_options({ 'title_display' => 'yes' });
}

sub init_non_cacheable {
  ## @override
  my $self = shift;

  # Set a default align parameter (the smallest multiway alignment with available for this species)
  if (!$self->hub->param('align')) {
    my @alignments = map { /species_(\d+)/ && $self->{'options'}{join '_', 'species', $1, lc $self->species} ? $1 : () } keys %{$self->{'options'}};
    my %align;

    $align{$_}++ for @alignments;

    $self->hub->param('align', [ sort { $align{$a} <=> $align{$b} } keys %align ]->[0]);
  }
}

sub field_order {
  ## @override
  return qw(hide_long_snps line_numbering title_display);
}

1;
