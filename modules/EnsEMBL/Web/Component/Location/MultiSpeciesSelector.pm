# $Id$

package EnsEMBL::Web::Component::Location::MultiSpeciesSelector;

use strict;

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select species';
  $self->{'included_header'} = 'Selected species';
  $self->{'excluded_header'} = 'Unselected species';
  $self->{'panel_type'}      = 'MultiSpeciesSelector';
  $self->{'url_param'}       = 's';
}

sub content_ajax {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $params          = $hub->multi_params; 
  my $alignments      = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $hub->species;
  my %shown           = map { $hub->param("s$_") => $_ } grep s/^s(\d+)$/$1/, $hub->param; # get species (and parameters) already shown on the page
  my %species;
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
      # this will fail for vega intra species compara
      if ($alignments->{$i}->{'species'}->{$primary_species} && $_ ne $primary_species) {
        my $type = lc $alignments->{$i}->{'type'};
        
        $type =~ s/_net//;
        $type =~ s/_/ /g;
        
        if ($species{$_}) {
          $species{$_} .= "/$type";
        } else {
          $species{$_} = $species_defs->species_label($_, 1) . " - $type";
        }
      }
    }
  }
  
  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $species{$primary_species} = $species_defs->species_label($primary_species, 1) . " - chromosome $chr";
  }
  
  $self->{'all_options'}      = \%species;
  $self->{'included_options'} = \%shown;
  
  $self->SUPER::content_ajax;
}

1;
