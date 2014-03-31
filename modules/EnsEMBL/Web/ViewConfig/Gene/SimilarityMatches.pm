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

package EnsEMBL::Web::ViewConfig::Gene::SimilarityMatches;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->set_defaults({ map { $_->{'name'} => $_->{'priority'} > 100 ? 'yes' : 'off' } $self->get_xref_types });
  $self->title = 'External references';
}

sub form {
  my $self = shift;
  foreach (sort { $b->{'priority'} <=> $a->{'priority'} || $a->{'name'} cmp $b->{'name'}} $self->get_xref_types) {
    $self->add_form_element({
      type   => 'CheckBox',
      select => 'select',
      name   => $_->{'name'},
      label  => $_->{'name'},
      value  => 'yes'
    });
  }
}

sub get_xref_types {
  my $self = shift;
  my @xref_types;
  my $no_vega_trans = 1 if ($self->hub->get_db eq 'vega' || $self->species_defs->ENSEMBL_SITETYPE eq 'Vega');
  foreach (split /,/, $self->species_defs->XREF_TYPES) {
    my @type_priorities = split /=/;
    next if ($no_vega_trans && $type_priorities[0] =~ /Vega/);
    push @xref_types, {
      name     => $type_priorities[0],
      priority => $type_priorities[1]
    };
  }
  return @xref_types;
}

1;
