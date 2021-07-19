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

package EnsEMBL::Web::Document::HTML::StableidPrefixes;

### Table of species' stable ID prefixes, taken from meta table in core db 

use strict;
use EnsEMBL::Web::Document::Table;
use base qw(EnsEMBL::Web::Document::HTML);

sub render { 
  my $self = shift;

  my $species_defs  = $self->hub->species_defs;

  my $columns = [
    {'key' => 'prefix',   'title' => 'Prefix'},
    {'key' => 'species',  'title' => 'Species name'},
  ]; 

  my $rows = [];

  my @A = $species_defs->valid_species;
  foreach my $species ($species_defs->valid_species) {
    my $prefix = $species_defs->get_config($species, 'SPECIES_PREFIX');
    next unless $prefix;
    my $name = $species_defs->get_config($species, 'SPECIES_SCIENTIFIC_NAME');
    my $common = $species_defs->get_config($species, 'SPECIES_DISPLAY_NAME');
    if ($common && $common !~ /\./) {
      $name .= " ($common)";
    }
    push @$rows, {'prefix' => $prefix, 'species' => $name};
  } 

  my $table = EnsEMBL::Web::Document::Table->new($columns, $rows);
  return $table->render;
}

1;
