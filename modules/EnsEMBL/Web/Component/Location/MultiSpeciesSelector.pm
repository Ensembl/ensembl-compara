=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Location::MultiSpeciesSelector;

use strict;

use base qw(EnsEMBL::Web::Component::MultiSelector);

sub _init {
  my $self = shift;
  
  $self->SUPER::_init;

  $self->{'link_text'}       = 'Select species or regions';
  $self->{'included_header'} = 'Selected species or regions';
  $self->{'excluded_header'} = 'Unselected species or regions';
  $self->{'panel_type'}      = 'MultiSpeciesSelector';
  $self->{'url_param'}       = 's';
  $self->{'rel'}             = 'modal_select_species_or_regions';
}

sub content_ajax {
  my $self            = shift;
  my $hub             = $self->hub;
  my $species_defs    = $hub->species_defs;
  my $params          = $hub->multi_params; 
  my $alignments      = $species_defs->multi_hash->{'DATABASE_COMPARA'}->{'ALIGNMENTS'} || {};
  my $primary_species = $hub->species;
  my $species_label   = $species_defs->species_label($primary_species, 1);
  my %shown           = map { $params->{"s$_"} => $_ } grep s/^s(\d+)$/$1/, keys %$params; # get species (and parameters) already shown on the page
  my $object          = $self->object;
  my $chr             = $object->seq_region_name;
  my $start           = $object->seq_region_start;
  my $end             = $object->seq_region_end;
  my $intra_species   = ($hub->species_defs->multi_hash->{'DATABASE_COMPARA'}{'INTRA_SPECIES_ALIGNMENTS'} || {})->{'REGION_SUMMARY'}{$primary_species};
  my $chromosomes     = $species_defs->ENSEMBL_CHROMOSOMES;
  my (%species, %included_regions);
  
  foreach my $alignment (grep $start < $_->{'end'} && $end > $_->{'start'}, @{$intra_species->{$object->seq_region_name}}) {
    my $type = lc $alignment->{'type'};
    my ($s)  = grep /--$alignment->{'target_name'}$/, keys %{$alignment->{'species'}};
    my ($sp, $target) = split '--', $s;
    s/_/ /g for $type, $target;
    
    $species{$s} = $species_defs->species_label($sp, 1) . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '') . " $target - $type";
  }
  
  foreach (grep !$species{$_}, keys %shown) {
    my ($sp, $target) = split '--';
    $included_regions{$target} = $intra_species->{$target} if $sp eq $primary_species;
  }
  
  foreach my $target (keys %included_regions) {
    my $s     = "$primary_species--$target";
    my $label = $species_label . (grep($target eq $_, @$chromosomes) ? ' chromosome' : '');
    
    foreach (grep $_->{'target_name'} eq $chr, @{$included_regions{$target}}) {
      (my $type = lc $_->{'type'}) =~ s/_/ /g;
      (my $t    = $target)         =~ s/_/ /g;
      $species{$s} = "$label $t - $type";
    }
  }
  
  foreach my $alignment (grep { $_->{'species'}{$primary_species} && $_->{'class'} =~ /pairwise/ } values %$alignments) {
    foreach (keys %{$alignment->{'species'}}) {
      if ($_ ne $primary_species) {
        my $type = lc $alignment->{'type'};
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
    $species{$primary_species} = "$species_label - chromosome $chr";
  }
  
  $self->{'all_options'}      = \%species;
  $self->{'included_options'} = \%shown;
  
  $self->SUPER::content_ajax;
}

1;
