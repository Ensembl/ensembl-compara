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

package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the species home page
### with sample search terms taken from ini files

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Constants;

sub render {
  my ($self, $is_help) = @_;
  
  return if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;

  my $hub                 = $self->hub;
  my $species_defs        = $hub->species_defs;
  my $page_species        = $hub->species || 'Multi';
  my $species_name        = $page_species eq 'Multi' ? '' : $species_defs->DISPLAY_NAME;
  my $favourites          = $hub->get_favourite_species;
  my $search_url          = $species_defs->ENSEMBL_WEB_ROOT . "$page_species/Psychic";
  my $default_search_code = $species_defs->ENSEMBL_DEFAULT_SEARCHCODE;

  ## Get appropriate configuration
  my $config;
  my $all_configs         = EnsEMBL::Web::Constants::SEARCH_CONFIG;
  if ($is_help || $hub->type eq 'Help') {
    $config = $all_configs->{'help'};
  }
  elsif ($hub->species) {
    $config = $all_configs->{'species'};
  }
  else {
    $config = $all_configs->{'home'};
  }

  # form
  my @class = ('search-form','clear');
  push @class, @{$config->{'form_classes'}||[]};
  my $form = EnsEMBL::Web::Form->new({'action' => $search_url, 'method' => 'get', 'skip_validation' => 1, 'class' => \@class});
  $form->add_hidden({'name' => 'site', 'value' => $default_search_code});

  if ($config->{'header'}) {
    my $header = $form->add_field({'type' => 'Div', 'children' => [['h3', { inner_HTML => $config->{'header'}}]]});
  }

  # examples
  my ($examples, $extra_params, %sample_data, @keys);
  my $inline = $config->{'inline'};

  if ($config->{'sample_data'}) {
    @keys = @{$config->{'sample_data'}}; 
    %sample_data = map { $_ => $_ } @keys;
    $extra_params = ';species=help';
  }
  else {
    if ($hub->species) {
      %sample_data = %{$species_defs->SAMPLE_DATA || {}};
      $sample_data{'GENE_TEXT'} = "$sample_data{'GENE_TEXT'}" if $sample_data{'GENE_TEXT'};
    } else {
      %sample_data = %{$species_defs->get_config('MULTI', 'GENERIC_DATA')};
    }
    @keys = qw(GENE_TEXT LOCATION_TEXT VARIATION_TEXT SEARCH_TEXT);
  }

  if (keys %sample_data) {
    $examples = join ' or ', map { $sample_data{$_} ? sprintf('<a class="nowrap" href="%s?q=%s%s">%s</a>', $search_url, $sample_data{$_}, $extra_params, $sample_data{$_}) : ()
    } @keys;
  }
  $examples = qq(<p class="search-example">e.g. $examples</p>) if $examples;

  # species dropdown
  if ($config->{'show_species'}) {
    my $field = $form->add_field({});

    my $species_info = $hub->get_species_info;
    my %species      = map { $species_info->{$_}{'common'} => $_ } grep { $species_info->{$_}{'is_reference'} } sort keys %$species_info;
    my %common_names = reverse %species;

    $field->add_element({
      'type'    => 'dropdown',
      'name'    => 'species',
      'label'   => 'Search',
      'id'      => 'species',
      'class'   => 'input',
      'values'  => [
        {'value' => '', 'caption' => 'All species'},
        {'value' => 'help', 'caption' => 'Help and Documentation' },
        {'value' => '', 'caption' => '---', 'disabled' => 1},
        map({ $common_names{$_} ? {'value' => $_, 'caption' => $common_names{$_}, 'group' => 'Favourite species'} : ()} @$favourites),
        {'value' => '', 'caption' => '---', 'disabled' => 1},
        map({'value' => $species{$_}, 'caption' => $_}, sort { uc $a cmp uc $b } keys %species)
      ]
    }, $inline)->first_child->after('label', {'inner_HTML' => '&nbsp;for', 'for' => 'q'});

  }

  # search input box & submit button
  my $search_prompt = defined($config->{'search_prompt'}) ? $config->{'search_prompt'}
                                                          : "Search $species_name&hellip;";
  my $q_params = {'type'        => 'string', 
                  'name'        => 'q', 
                  'id'          => 'q',
                  'value'       => $search_prompt, 
                  'size'        => 50, 
                  'class'       => 'query input inactive',
                  'is_encoded'  => $config->{'is_encoded'} || 0,
                  'notes'       => $examples,
                  };
  my $q_field = $form->add_field($q_params, $inline);
  $q_field->add_element({'type' => 'submit', 'value' => 'Go'}, 1);

  return sprintf '<div id="SpeciesSearch" class="js_panel"><input type="hidden" class="panel_type" value="SearchBox" />%s</div>', $form->render;
}

sub render_help {
  my $self = shift;
  $self->render(1);
}

1;
