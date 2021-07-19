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
  my $species  = $hub->species_defs->SPECIES_DISPLAY_NAME; 
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
    my $image = $hub->species_defs->SPECIES_IMAGE || $hub->species;
    $header = sprintf '<img src="/i/species/%s.png" class="badge-32"><span class="species">%s</span> <span class="more">(%s)</span>', $image, $hub->species_defs->SPECIES_DISPLAY_NAME, $assembly;
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
  my $name_key     = 'SPECIES_DISPLAY_NAME';

  my $species_hash = {};
  my $species_list = [];

  foreach ($species_defs->reference_species) {
    my $name = $species_defs->get_config($_, $name_key);
    $species_hash->{$name} = $hub->url({ species => $_, type => 'Info', action => 'Index', __clear => 1 }); 
  }

  foreach (sort keys %$species_hash) {
    push @$species_list, [$species_hash->{$_}, $_];
  }

  $self->{'species_list'} = $species_list;
   
  #adding species strain (Mouse strains, Pig breeds, etc) to the list above
  foreach ($species_defs->valid_species) {
    my $strain_type = ucfirst($species_defs->get_config($_, 'STRAIN_TYPE').'s');
    $species_defs->get_config($_, 'ALL_STRAINS') ? push( @{$self->{'species_list'}}, [ $hub->url({ species => $_, type => 'Info', action => 'Strains', __clear => 1 }), $species_defs->get_config($_, $name_key)." $strain_type"] ) : next;
  }
  @{$self->{'species_list'}} = sort { $a->[1] cmp $b->[1] } @{$self->{'species_list'}}; #just a precautionary bit - sorting species list again after adding the strain  
  
  my $favourites = $hub->get_favourite_species;
  
  $self->{'favourite_species'} = [ map {[ $hub->url({ species => $_, type => 'Info', action => 'Index', __clear => 1 }), $species_defs->get_config($_, $name_key) ]} @$favourites ] if scalar @$favourites;
}

sub species_list {
  my $self      = shift;
  my $total     = scalar @{$self->{'species_list'}};
  my ($all_species, $fav_species);

  if ($self->{'favourite_species'}) {
    my $fave_text = $self->hub->species_defs->FAVOURITES_SYNONYM || 'Favourite';
    $fav_species .= qq{<li><a class="constant" href="$_->[0]">$_->[1]</a></li>} for @{$self->{'favourite_species'}};
    $fav_species  = qq{<h4>$fave_text species</h4><ul>$fav_species</ul><div style="clear: both;padding:1px 0;background:none"></div>};
  }

  for my $i (0..$total-1) {
    $all_species .= sprintf '<li>%s</li>', $self->{'species_list'}[$i] ? qq{<a class="constant" href="$self->{'species_list'}[$i][0]">$self->{'species_list'}[$i][1]</a>} : '&nbsp;';
  }

  return sprintf '<div class="dropdown species">%s<h4>%s</h4><ul>%s</ul></div>', $fav_species, $fav_species ? 'All species' : 'Select a species', $all_species;
}

1;
