=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::SpeciesBar;

# Generates the global context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::Utils::FormatText qw(glossary_helptip);

use base qw(EnsEMBL::Web::Document::Element);

sub init {
  my $self          = shift;
  $self->init_species_list($self->hub);
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  return if ($hub->type eq 'GeneTree' || $hub->type eq 'Tools');

  ## User-friendly species name and assembly
  my $species  = $hub->species_defs->SPECIES_COMMON_NAME; 
  return '' if $species =~ /^(multi|common)$/i;
  my $assembly = $hub->species_defs->ASSEMBLY_NAME;

  ## Species header
  my $home_url  = $hub->url({'type' => 'Info', 'action' => 'Index'});

  ## Make accommodations for EG bacteria
  my ($header, $arrow, $dropdown);
  if ($hub->species_defs->EG_DIVISION && $hub->species_defs->EG_DIVISION eq 'bacteria') {
    my $full_name = $hub->species_defs->SPECIES_SCIENTIFIC_NAME;
    ## Bacterial names can include strain and assembly info, so parse it out for nicer display
    $full_name =~ /([A-Za-z]+)\s([a-z]+)\s([^\(]+)(.*)/;
    $header = sprintf '<span class="species">%s %s</span> <span class="more">%s %s</span>', $1, $2, $3, $4;
    ## No dropdown species selector
    $arrow = '';
    $dropdown = ''; 
  }
  else {
    $header = sprintf '<img src="/i/species/%s.png" class="badge-32"><span class="species">%s</span> <span class="more">(%s)</span>', $hub->species, $species, $assembly;
    ## Species selector
    $arrow     = sprintf '<span class="dropdown"><a class="toggle species" href="#" rel="species">&#9660;</a></span>';
    $dropdown  = $self->species_list;
  }

  my $content = sprintf '<span class="header"><a href="%s">%s</a></span> %s %s', 
                          $home_url, $header, $arrow, $dropdown;
 
  return $content;
}

sub init_species_list {
  my ($self, $hub) = @_;
  my $species_defs = $hub->species_defs;
  
  $self->{'species_list'} = [ 
    sort { $a->[1] cmp $b->[1] } 
    map  [ $hub->url({ species => $_, type => 'Info', action => 'Index', __clear => 1 }), $species_defs->get_config($_, 'SPECIES_COMMON_NAME') ],
    $species_defs->reference_species
  ];

  #adding species strain (Mouse strains) to the list above
  foreach ($species_defs->valid_species) {
    $species_defs->get_config($_, 'ALL_STRAINS') ? push( @{$self->{'species_list'}}, [ $hub->url({ species => $_, type => 'Info', action => 'Strains', __clear => 1 }), $species_defs->get_config($_, 'SPECIES_COMMON_NAME')." Strains"] ) : next;
  }
  @{$self->{'species_list'}} = sort { $a->[1] cmp $b->[1] } @{$self->{'species_list'}}; #just a precautionary bit - sorting species list again after adding the strain  
  
  my $favourites = $hub->get_favourite_species;
  
  $self->{'favourite_species'} = [ map {[ $hub->url({ species => $_, type => 'Info', action => 'Index', __clear => 1 }), $species_defs->get_config($_, 'SPECIES_COMMON_NAME') ]} @$favourites ] if scalar @$favourites;
}

sub species_list {
  my $self      = shift;
  my $total     = scalar @{$self->{'species_list'}};
  my $remainder = $total % 3;
  my $third     = int($total / 3) - 1;
  my ($all_species, $fav_species);
  
  if ($self->{'favourite_species'}) {
    $fav_species .= qq{<li><a class="constant" href="$_->[0]">$_->[1]</a></li>} for @{$self->{'favourite_species'}};
    $fav_species  = qq{<h4>Favourite species</h4><ul>$fav_species</ul><div style="clear: both;padding:1px 0;background:none"></div>};
  }
  
  # Ok, this is slightly mental. Basically, we're building a 3 column structure with floated <li>'s.
  # Because they are floated, if they were printed alphabetically, this would result in a menu with was alphabetised left to right, i.e.
  # A B C
  # D E F
  # G H I
  # Because the list is longer than it is wide, it is much easier to find what you want if alphabetised top to bottom, i.e.
  # A D G
  # B E H
  # C F I
  # The code below achieves that goal
  my @ends = ( $third + !!($remainder && $remainder--) );
  push @ends, $ends[0] + 1 + $third + !!($remainder && $remainder--);
  
  my @output_order;
  push @{$output_order[0]}, $self->{'species_list'}->[$_] for 0..$ends[0];
  push @{$output_order[1]}, $self->{'species_list'}->[$_] for $ends[0]+1..$ends[1];
  push @{$output_order[2]}, $self->{'species_list'}->[$_] for $ends[1]+1..$total-1;
  
  for my $i (0..$#{$output_order[0]}) {
    for my $j (0..2) {
      $all_species .= sprintf '<li>%s</li>', $output_order[$j][$i] ? qq{<a class="constant" href="$output_order[$j][$i][0]">$output_order[$j][$i][1]</a>} : '&nbsp;';
    }
  }

  return sprintf '<div class="dropdown species">%s<h4>%s</h4><ul>%s</ul></div>', $fav_species, $fav_species ? 'All species' : 'Select a species', $all_species;  
}

1;
