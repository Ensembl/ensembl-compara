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

package EnsEMBL::Web::ImageConfig::MultiSpecies;

use strict;
use warnings;

use parent qw(EnsEMBL::Web::ImageConfig);

## Data is stored in the database as follows:
## {
##   Homo_sapiens  => { nodes => {contig   => { display => 'off' }}, track_order => []}
##   Gallus_gallus => { nodes => {scalebar => { display => 'off' }}}
##   Multi         => { ... }
## }

sub _new {
  ## @override
  my ($class, $hub, $species, $type, $code) = @_;

  my $self = $class->SUPER::_new($hub, $hub->species, $type, $code);

  $self->set_parameter('multi_species', 1);

  return $self;
}

sub species_list {
  ## Gets the list of all the species selected for the image
  ## TODO - get rid of referer
  my $self = shift;

  if (!$self->{'species_list'}) {
    my $species_defs = $self->species_defs;
    my $referer      = $self->hub->referer;
    my $params       = $referer->{'params'};
    my %seen;
    my @species = grep !$seen{$_}++, $referer->{'ENSEMBL_SPECIES'}, map [ split '--', $params->{"s$_"}[0] ]->[0], sort { $a <=> $b } map { /^s(\d+)$/ ? $1 : () } keys %$params;

    $self->{'species_list'} = [ map [ $_, $species_defs->SPECIES_COMMON_NAME($_) ], @species ];
  }

  return $self->{'species_list'};
}

sub get_user_settings {
  ## @override
  ## Return only species specific settings
  my $self      = shift;
  my $settings  = $self->SUPER::get_user_settings(@_);

  return $settings->{$self->species} ||= {};
}

sub get_user_settings_to_save {
  ## @override
  return shift->SUPER::get_user_settings(@_);
}

1;
