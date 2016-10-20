=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016] EMBL-European Bioinformatics Institute

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
  my ($align, $target_species, $target_slice_name_range) = split '--', $hub->param('align');
  my $url          = $hub->url({ %{$hub->multi_params}, align => undef }, 1);
  my $extra_inputs = join '', map qq(<input type="hidden" name="$_" value="$url->[1]{$_}" />), sort keys %{$url->[1] || {}};
  my $alignments   = $db_hash->{'DATABASE_COMPARA' . ($cdb =~ /pan_ensembl/ ? '_PAN_ENSEMBL' : '')}{'ALIGNMENTS'} || {}; # Get the compara database hash

  my $species = $hub->species;
  my $align_label = '';
  # Order by number of species (name is in the form "6 primates EPO"
  foreach my $row (sort { $a->{'name'} <=> $b->{'name'} } grep { $_->{'class'} !~ /pairwise/ && $_->{'species'}->{$species} } values %$alignments) {
    (my $name = $row->{'name'}) =~ s/_/ /g;
    if ($row->{id} == $align) {
      $align_label = encode_entities($name);
      last;
    }
  }
  # warn Data::Dumper::Dumper $alignments;
  # For the variation compara view, only allow multi-way alignments
  if ($align_label eq '') {
    my %species_hash;
    foreach my $key (grep { $alignments->{$_}{'class'} =~ /pairwise/ } keys %$alignments) {
      foreach (keys %{$alignments->{$key}->{'species'}}) {
        if ($alignments->{$key}->{'species'}->{$species} && $_ ne $species) {
          if ($key == $align) {
            $align_label = $species_defs->production_name_mapping($_);
            last;
          }          
        }
      } 
    }    
  }

  my $default_species = $species_defs->valid_species($hub->species) ? $hub->species : $hub->get_favourite_species->[0];

  my $modal_uri       = $hub->url('MultiSelector', {qw(type Location action TaxonSelector), align => $align, referer_action => $hub->action});

#  my $modal_uri = URI->new(sprintf '/%s/Component/Blast/Web/TaxonSelector/ajax?', $default_species || 'Multi' );
#  $modal_uri->query_form(align => $align) if $align; 

  ## Get the species in the alignment
  return sprintf(qq{
    <div class="js_panel alignment_selector_form">
      <input type="hidden" class="panel_type" value="ComparaAlignSliceSelector" />
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
  my $species_label = $self->hub->species_defs->get_config($species, 'SPECIES_COMMON_NAME');
  my $species_img = sprintf '<img class="nosprite" src="/i/species/48/%s.png">', $species;
  my $common_name = '';

  return sprintf '<span class="ss-alignment-selected-label">%s <span class="ss-selected">%s</span></span>',
          $species_label ? $species_img : '',
          $species_label ? $species_label : $species;
}

1;
