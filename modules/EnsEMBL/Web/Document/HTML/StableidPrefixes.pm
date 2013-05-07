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

  foreach my $species ($species_defs->valid_species) {
    my $prefix = $species_defs->get_config($species, 'SPECIES_PREFIX');
    next unless $prefix;
    my $name = $species_defs->get_config($species, 'SPECIES_SCIENTIFIC_NAME');
    my $common = $species_defs->get_config($species, 'SPECIES_COMMON_NAME');
    if ($common && $common !~ /\./) {
      $name .= " ($common)";
    }
    push @$rows, {'prefix' => $prefix, 'species' => $name};
  } 

  my $table = EnsEMBL::Web::Document::Table->new($columns, $rows);
  return $table->render;
}

1;
