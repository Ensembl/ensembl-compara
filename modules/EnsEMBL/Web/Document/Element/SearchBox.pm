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

package EnsEMBL::Web::Document::Element::SearchBox;

### Generates small search box (used in top left corner of pages)

use strict;
                                                                                
use base qw(EnsEMBL::Web::Document::Element);

sub search_options {
  ## Returns the options for the search dropdown based upon the current species
  my $self          = shift;
  my $species       = $self->species;
  my $species_name  = $species ? $self->species_defs->SPECIES_DISPLAY_NAME : '';
  my $image         = $self->species_defs->SPECIES_IMAGE;

  return [ $species ? (
    'ensembl'         => { 'label' => "Search $species_name",   'icon' => "species/${image}.png"   }) : (),
    'ensembl_all'     => { 'label' => 'Search all species',     'icon' => 'search/ensembl.gif'          },
    'ensembl_genomes' => { 'label' => 'Search Ensembl genomes', 'icon' => 'search/ensembl_genomes.gif'  },
    'vega'            => { 'label' => 'Search Vega',            'icon' => 'search/vega.gif'             },
    'ebi'             => { 'label' => 'Search EMBL-EBI',        'icon' => 'search/ebi.gif'              },
    'sanger'          => { 'label' => 'Search Sanger',          'icon' => 'search/sanger.gif'           }
  ];
}

sub default_search_code {
  ## Returns the search code either set by the user previously by selecting one of the options in the drodpown, or defaults to the one specified in sitedefs
  return $_[0]->{'_default'} ||= $_[0]->hub->get_cookie_value('ENSEMBL_SEARCH') || $_[0]->species_defs->ENSEMBL_DEFAULT_SEARCHCODE || 'ensembl';
}

sub species {
  ## Ignores common and Multi as species names
  my $species = $_[0]->hub->species;
  return $species =~ /multi|common/i ? '' : $species;
}

sub content {
  my $self            = shift;
  my $img_url         = $self->img_url;
  my $species         = $self->species;
  my $search_url      = $self->hub->url('Psychic', {'species' => $species || 'Multi', 'type' => '', 'action' => '', 'function' => '', '__clear' => 1});
  my $options         = $self->search_options;
  my %options_hash    = @$options;
  my $search_code     = lc $self->default_search_code;
     $search_code     = $options->[0] unless exists $options_hash{$search_code};
  my $search_options  = join '', map {
    if ($_ % 2 == 0) {
      my $code    = $options->[$_];
      my $details = $options->[$_ + 1];
      qq(<div class="$code"><img class="no-sprite" src="${img_url}$details->{'icon'}" class="badge-16" alt="$details->{'label'}"/>$details->{'label'}<input type="hidden" value="$details->{'label'}&hellip;" /></div>\n);
    }
  } 0..scalar @$options - 1;

  return qq(
    <div id="searchPanel" class="js_panel">
      <input type="hidden" class="panel_type" value="SearchBox" />
      <form action="$search_url">
        <div class="search print_hide">
          <div class="sites button">
            <img class="search_image no-sprite badge-16" src="${img_url}$options_hash{$search_code}{'icon'}" alt="" />
            <img src="${img_url}search/down.gif" style="width:7px" alt="" />
            <input type="hidden" name="site" value="$search_code" />
          </div>
          <div>
            <label class="hidden" for="se_q">Search terms</label>
            <input class="query inactive" id="se_q" type="text" name="q" value="$options_hash{$search_code}{'label'}&hellip;" data-role="none" onkeydown="if (event.keyCode == 13) { \$(this).closest('form').submit(); return false; }" />
          </div>
          <div class="button"><img src="${img_url}16/search.png" alt="Search&nbsp;&raquo;" onClick="\$(this).closest('form').submit()" /></div>
        </div>
        <div class="site_menu hidden">
          $search_options
        </div>
      </form>
    </div>
  );
}

1;
