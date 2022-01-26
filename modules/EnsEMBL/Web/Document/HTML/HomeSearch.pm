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

package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the species home page
### with sample search terms taken from ini files

use strict;

use List::MoreUtils qw(first_index);

use base qw(EnsEMBL::Web::Document::HTML);

use EnsEMBL::Web::Form;
use EnsEMBL::Web::Constants;

sub render {
  my ($self, $is_help) = @_;
  
  return if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;

  my $hub                 = $self->hub;
  my $species_defs        = $hub->species_defs;
  my $page_species        = $hub->species || 'Multi';
  my $multi               = $hub->species =~ /Multi/i;
  my $species_name        = $page_species eq 'Multi' ? '' : $species_defs->SPECIES_DISPLAY_NAME;
  my $favourites          = $hub->get_favourite_species;
  my $search_url          = $species_defs->ENSEMBL_WEB_ROOT . "$page_species/Psychic";
  my $default_search_code = $species_defs->ENSEMBL_DEFAULT_SEARCHCODE;

  ## Get appropriate configuration
  my $config;
  my $all_configs         = EnsEMBL::Web::Constants::SEARCH_CONFIG;
  if ($is_help || $hub->type eq 'Help') {
    $config = $all_configs->{'help'};
  }
  elsif ($hub->species && !$multi) {
    $config = $all_configs->{'species'};
  }
  else {
    $config = $all_configs->{'home'};
  }

  # form
  my $inline = $config->{'inline'};
  my @class = ('search-form','clear');
  if ($hub->type && $hub->type eq 'Search' && !$hub->species_defs->ENSEMBL_SOLR_ENDPOINT) {
    push (@class, 'unisearch');
  }
  push @class, @{$config->{'form_classes'}||[]};
  my $form = EnsEMBL::Web::Form->new({'action' => $search_url, 'method' => 'get', 'skip_validation' => 1, 'class' => \@class});
  $form->add_hidden({'name' => 'site', 'value' => $default_search_code});

  if ($config->{'header'}) {
    my $header = $form->add_field({'type' => 'Div', 'children' => [['h3', { inner_HTML => $config->{'header'}}]]});
  }

  # examples
  my $sample_data = {};
  my $keys = [];
  my ($examples, $extra_params);

  if ($config->{'sample_data'}) {
    $keys = $config->{'sample_data'}; 
    my %sample_data = map { $_ => $_ } @$keys;
    $sample_data = \%sample_data;
    $extra_params = ';species=help';
  }
  else {
    $keys = [qw(GENE_TEXT LOCATION_TEXT VARIATION_TEXT SEARCH_TEXT)];
    my %lookup = map {$_ => 1} @$keys;
    if ($hub->species && !$multi) {
      $sample_data = $species_defs->SAMPLE_DATA || {};
      $sample_data->{'GENE_TEXT'} = "$sample_data->{'GENE_TEXT'}" if $sample_data->{'GENE_TEXT'};
    } else {
      $sample_data = $species_defs->get_config('MULTI', 'GENERIC_DATA') || {};
      if (keys %$sample_data) {
        foreach (keys %$sample_data) {
          if ($_ =~ /SPECIES/) {
            (my $type = $_) =~ s/_SPECIES//;
            $extra_params->{$type.'_TEXT'} = ';species='.$sample_data->{$_};
          }
          ## Extra search types - mainly for UniSearch
          if ($_ =~ /TEXT/ && !$lookup{$_}) {
            push @$keys, $_; 
          }
        }
      }
      else {
        my $primary = $species_defs->ENSEMBL_PRIMARY_SPECIES;
        $sample_data = $species_defs->get_config($primary, 'SAMPLE_DATA') || {};
        $sample_data->{'GENE_TEXT'} = "$sample_data->{'GENE_TEXT'}" if $sample_data->{'GENE_TEXT'};
      }
    }
  }

  ## Remove variation link if species only has VCF variants
  my $vdb = $hub->species_defs->databases->{'DATABASE_VARIATION'};
  if ($vdb) {
    my $no_real_variants = 1;
    my $counts = $vdb->{'tables'}{'source'}{'counts'};
    foreach my $key (keys %{$counts||{}}) {
      if ($counts->{$key} > 0) {
        $no_real_variants = 0;
        last;
      }
    }
    if ($no_real_variants) {
      my $index = first_index {$_ eq 'VARIATION_TEXT'} @$keys;
      splice @$keys, $index, 1; 
    }
  }

  ## Remove examples that only have stable IDs
  foreach my $sample ('GENE', 'TRANSCRIPT') {
    if ($sample_data->{$sample.'_TEXT'} =~ /^ENS/) {
      my $index = first_index {$_ eq $sample.'_TEXT'} @$keys;
      splice @$keys, $index, 1; 
    }
  }


  if (keys %$sample_data) {
    my @eg_array;
    foreach (@$keys) {
      next unless $sample_data->{$_};
      (my $type = $_) =~ s/_TEXT//;
      my $param_name = $type.'_PARAM';
      my $param = $sample_data->{$param_name} ? $param_name : $_;
      push @eg_array, sprintf('<a class="nowrap" href="%s?q=%s%s">%s</a>', 
          $search_url, 
          $sample_data->{$param}, 
          ref $extra_params eq 'HASH' ? $extra_params->{$_} : $extra_params, 
          $sample_data->{$_}
        );
    } 
    $examples = join ' or ', @eg_array;
  }
  $examples = qq(<p class="search-example">e.g. $examples</p>) if $examples;

  # species dropdown
  if ($config->{'show_species'}) {
    my $field = $form->add_field({});
    my %species = $self->munge_species;
    my %sortable = reverse %species;
    my $values = [];
    if ($hub->species_defs->ENSEMBL_SOLR_ENDPOINT) {
      push @$values, (
                  {'value' => '', 'caption' => 'All species'},
                  {'value' => 'help', 'caption' => 'Help and Documentation' },
                  {'value' => '', 'caption' => '---', 'disabled' => 1},
                  );
    }
    ## If more than one species, show favourites
    if (scalar keys %species > 1) {
      my $group_label = $self->hub->species_defs->FAVOURITES_SYNONYM || 'Favourite';
      $group_label   .= ' species';
      push @$values, map({ $sortable{$_} ? {'value' => $_, 'caption' => $sortable{$_}, 'group' => $group_label} : ()} @$favourites);
      push @$values, {'value' => '', 'caption' => '---', 'disabled' => 1};
    }
    push @$values, map({'value' => $species{$_}, 'caption' => $_}, sort { uc $a cmp uc $b } keys %species);

    $field->add_element({
      'type'    => 'dropdown',
      'name'    => 'species',
      'label'   => 'Search',
      'id'      => 'species',
      'class'   => 'input',
      'values'  => $values,
    }, $inline)->first_child->after('label', {'inner_HTML' => '&nbsp;for', 'for' => 'q'});

  }

  # search input box & submit button
  my $search_prompt = defined($config->{'search_prompt'}) ? $config->{'search_prompt'}
                                                          : "Search&hellip;";
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

sub munge_species {
  my $self = shift;
  my $hub = $self->hub;

  my $species_info = $hub->get_species_info;
  my %species      = map { $species_info->{$_}{'display_name'} => $_ } grep { $species_info->{$_}{'is_reference'} } sort keys %$species_info;

  return %species;
}

sub render_help {
  my $self = shift;
  $self->render(1);
}

1;
