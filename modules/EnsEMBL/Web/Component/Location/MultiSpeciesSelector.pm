package EnsEMBL::Web::Component::Location::MultiSpeciesSelector;

use strict;
use warnings;
no warnings 'uninitialized';

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select species for comparison';
  $self->{'included_header'} = 'Selected species';
  $self->{'excluded_header'} = 'Unselected species';
  $self->{'panel_type'}      = 'MultiSpeciesSelector';
  $self->{'url_param'}       = 's';
}

sub content_ajax {
  my $self            = shift;
  my $object          = $self->object;
  my $params          = $object->multi_params; 
  my $alignments      = $object->species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $object->species;
  my %shown           = map { $object->param("s$_") => $_ } grep s/^s(\d+)$/$1/, $object->param; # get species (and parameters) already shown on the page
  my $next_id         = 1 + scalar keys %shown;
  my %species;
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
      # this will fail for vega intra species compara
      if ($alignments->{$i}->{'species'}->{$primary_species} && !/^$primary_species|merged$/) {
        my $type = lc $alignments->{$i}->{'type'};
        
        $type =~ s/_net//;
        $type =~ s/_/ /g;
        
        if ($species{$_}) {
          $species{$_} .= "/$type";
        } else {
          $species{$_} = $object->species_defs->species_label($_, 1) . " - $type";
        }
      }
    }
  }
  
  if ($shown{$primary_species}) {
    my ($chr) = split ':', $params->{"r$shown{$primary_species}"};
    $species{$primary_species} = $object->species_defs->species_label($primary_species, 1) . " - chromosome $chr";
  }
  
  $self->{'all_options'}      = \%species;
  $self->{'included_options'} = \%shown;
  
  $self->SUPER::content_ajax;
}

1;
