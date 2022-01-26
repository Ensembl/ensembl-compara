=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Component::Compara_AlignSliceSelector;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self         = shift;
  my $hub          = $self->hub;
  my $cdb          = shift || $hub->param('cdb') || 'compara';
  my $species_defs = $hub->species_defs;
  my $db_hash      = $species_defs->multi_hash;
  my ($align, $target_species, $target_slice_name_range) = split '--', $hub->get_alignment_id;
  my $url          = $hub->url({ %{$hub->multi_params}, align => undef }, 1);
  my $extra_inputs; 
  foreach (sort keys %{$url->[1] || {}}) {
    my $val = $url->[1]{$_};
    next if $val =~ /</; ## Reject parameters that might contain XSS
    $extra_inputs .= qq(<input type="hidden" name="$_" value="$val" />);
  }
  my $alignments   = $db_hash->{'DATABASE_COMPARA' . ($cdb =~ /pan_ensembl/ ? '_PAN_ENSEMBL' : '')}{'ALIGNMENTS'} || {}; # Get the compara database hash

  my $prodname = $hub->species_defs->SPECIES_PRODUCTION_NAME;
  my $align_label = '';
  # Order by number of species (name is in the form "6 primates EPO"
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$prodname} } values %$alignments) {
    (my $name = $row->{'name'}) =~ s/_/ /g;
    if ($row->{id} == $align) {
      $align_label = encode_entities($name);
      last;
    }
  }

  # For the variation compara view, only allow multi-way alignments
  my $lookup = $species_defs->prodnames_to_urls_lookup;
  if ($align_label eq '') {
    my %species_hash;
    foreach my $key (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
      foreach (keys %{$alignments->{$key}->{'species'}}) {
        if ($alignments->{$key}->{'species'}->{$prodname} && $_ ne $prodname) {
          if ($key == $align) {
            $align_label = $lookup->{$_};
            last;
          }
        }
      } 
    }    
  }

  my $default_species = $species_defs->valid_species($hub->species) ? $hub->species : $hub->get_favourite_species->[0];

  my $modal_uri       = $hub->url('MultiSelector', {type => $hub->type, action => 'TaxonSelector', align => $align, referer_type => $hub->type, referer_action => $hub->action});

  # Tackle action for alignments image and text
  my $action = $hub->function eq 'Image' ? 'Compara_AlignSliceBottom' : $hub->action;
  my $compara_config_url  = $hub->url('Config', {type => $hub->type,  action => $action});

  ## Get the species in the alignment
  return sprintf(qq{
    <div class="js_panel alignment_selector_form">
      <input type="hidden" class="panel_type" value="ComparaAlignSliceSelector" />
      <input type="hidden" class="update_component" value="Compara_AlignSliceBottom" />
      <input type="hidden" class="compara_config_url" value="$compara_config_url">
      <div class="navbar " style="width:%spx; text-align:left">
        <form action="%s" method="get">
          <div class="ss-alignment-container">
            <label for="align">Alignment:</label>
            %s
            <input class="ss-alignment-selected-value" type="hidden" name="align" value="%s" />
            <input class="panel_type" value="SpeciesSelect" type="hidden">
            %s
            <div class="links">
              <a class="modal_link data alignment-slice-selector-link go-button _species_selector" href="${modal_uri}">Select %s alignment</a>
              <a class="alignment-go" href=""></a>
            </div>            
          </div>
        </form>
      </div>
    </div>},
    $self->image_width, 
    $url->[0],
    $align_label ? $self->getLabelHtml($align_label) : '',
    $align,
    $extra_inputs,
    ($align) ? 'another' : 'an'
  );
}

sub getLabelHtml {
  my $self = shift;
  my $species = shift;
  my $species_label = $self->hub->species_defs->get_config($species, 'SPECIES_DISPLAY_NAME');
  my $species_image = $self->hub->species_defs->get_config($species, 'SPECIES_IMAGE');
  my $img_url = $self->hub->species_defs->ENSEMBL_IMAGE_ROOT . '/species/' . $species_image;
  my $species_img = sprintf '<img class="nosprite" src="%s.png">', $img_url;
  my $common_name = '';

  return sprintf '<span class="ss-alignment-selected-label">%s <span class="ss-selected">%s</span></span>',
          $species_label ? $species_img : '',
          $species_label ? $species_label : $species;
}

1;
