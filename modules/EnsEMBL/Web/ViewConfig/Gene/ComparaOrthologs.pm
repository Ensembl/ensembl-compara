# $Id$

package EnsEMBL::Web::ViewConfig::Gene::ComparaOrthologs;

use strict;

use base qw(EnsEMBL::Web::ViewConfig);

sub init {
  my $self = shift;
  $self->set_defaults({ map { 'species_' . lc($_) => 'yes' } $self->species_defs->valid_species });
  
  $self->code  = 'Gene::HomologAlignment';
  $self->title = 'Homologs';
}

sub form {
  my $self = shift;
  
  $self->add_fieldset('Selected species');
  
  my $species_defs = $self->species_defs;
  my %species      = map { $species_defs->species_label($_) => $_ } $species_defs->valid_species;
  
  foreach (sort { ($a =~ /^<.*?>(.+)/ ? $1 : $a) cmp ($b =~ /^<.*?>(.+)/ ? $1 : $b) } keys %species) {
    $self->add_form_element({
      type  => 'CheckBox', 
      label => $_,
      name  => 'species_' . lc $species{$_},
      value => 'yes',
      raw   => 1
    });
  }
}

1;
