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
  $self->{'rel'}             = 'modal_select_species';
}

sub content_ajax {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $params          = $hub->multi_params; 
  my $alignments      = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $hub->species;
  my %shown           = map { $params->{"s$_"} => $_ } grep s/^s(\d+)$/$1/, keys %$params; # get species (and parameters) already shown on the page
  my $object          = $self->object;
  my $start           = $object->seq_region_start;
  my $end             = $object->seq_region_end;
  my $intra_species   = ($hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'INTRA_SPECIES_ALIGNMENTS'} || {})->{'REGION_SUMMARY'}{$primary_species}{$object->seq_region_name};
  my $chromosomes     = $species_defs->ENSEMBL_CHROMOSOMES;
  my %species;
  
  foreach my $alignment (grep $start < $_->{'end'} && $end > $_->{'start'}, @$intra_species) {
    my $type = lc $alignment->{'type'};
    my ($s)  = grep /--$alignment->{'target_name'}$/, keys %{$alignment->{'species'}};
    my ($sp, $target) = split '--', $s;
    s/_/ /g for $type, $target;
    
    $species{$s} = $species_defs->species_label($sp, 1) . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '') . " $target - $type";
  }
  
  foreach my $i (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
    foreach (keys %{$alignments->{$i}->{'species'}}) {
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
