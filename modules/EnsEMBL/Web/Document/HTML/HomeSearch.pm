package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

use EnsEMBL::Web::Form;

sub new {
  my ($class, $hub) = @_;
  my $self = $class->SUPER::new(
    species      => $hub->species || 'Multi',
    species_defs => $hub->species_defs,
    favourites   => $hub->get_favourite_species,
    query        => $hub->param('q'),
  );
  
  bless $self, $class;
  return $self;
}

sub species    { return $_[0]->{'species'};  }
sub favourites { return $_[0]{'favourites'}; }

sub render {
  my $self = shift;
  
  return if $ENV{'HTTP_USER_AGENT'} =~ /Sanger Search Bot/;
  
  my $species_defs        = $self->species_defs;
  my $page_species        = $self->species;
  my $species_name        = $page_species eq 'Multi' ? '' : $species_defs->DISPLAY_NAME;
     $species_name        = "<i>$species_name</i>" if $species_name =~ /\./;
  my $search_url          = $species_defs->ENSEMBL_WEB_ROOT . "$page_species/psychic";
  my $default_search_code = $species_defs->ENSEMBL_DEFAULT_SEARCHCODE;
  my $is_home_page        = $page_species eq 'Multi';
  my $input_size          = $is_home_page ? 30 : 50;
  my $favourites          = $self->favourites;
  my $q                   = $self->{'query'};

  # form
  my $form = EnsEMBL::Web::Form->new({'action' => $search_url, 'method' => 'get', 'validate' => 0, 'class' => [ $is_home_page ? 'homepage-search-form' : (), 'search-form' ]});
  $form->add_hidden({'name' => 'site', 'value' => $default_search_code});

  # examples
  my $examples;
  my $sample_data;

  if ($is_home_page) {
    $sample_data = $species_defs->get_config('MULTI', 'GENERIC_DATA') || {};
  } else {
    $sample_data = { %{$species_defs->SAMPLE_DATA || {}} };
    $sample_data->{'GENE_TEXT'} = "$sample_data->{'GENE_TEXT'}" if $sample_data->{'GENE_TEXT'};
  }

  if (keys %$sample_data) {
    $examples = join ' or ', map { $sample_data->{$_}
      ? qq(<a class="nowrap" href="$search_url?q=$sample_data->{$_}">$sample_data->{$_}</a>)
      : ()
    } qw(GENE_TEXT LOCATION_TEXT SEARCH_TEXT);
    $examples = qq(<p class="search-example">e.g. $examples</p>) if $examples;
  }

  # form field
  my $field = $form->add_field({'label' => $is_home_page ? 'Search' : 'Search for', 'notes' => $examples});

  # species dropdown
  if ($page_species eq 'Multi') {
    my %species      = map { $species_defs->get_config($_, 'DISPLAY_NAME') => $_ } @{$species_defs->ENSEMBL_DATASETS};
    my %common_names = reverse %species;

    $field->add_element({
      'type'    => 'dropdown',
      'name'    => 'species',
      'id'      => 'species',
      'class'   => 'input',
      'values'  => [
        {'value' => '', 'caption' => 'All species'},
        {'value' => '', 'caption' => '---', 'disabled' => 1},
        map({ $common_names{$_} ? {'value' => $_, 'caption' => $common_names{$_}, 'group' => 'Favourite species'} : ()} @$favourites),
        {'value' => '', 'caption' => '---', 'disabled' => 1},
        map({'value' => $species{$_}, 'caption' => $_}, sort { uc $a cmp uc $b } keys %species)
      ]
    }, 1)->first_child->after('label', {'inner_HTML' => 'for', 'for' => 'q'});
  }

  # search input box & submit button
  $field->add_element({'type' => 'string', 'value' => $q, 'id' => 'q', 'size' => $input_size, 'name' => 'q', 'class' => 'input'}, 1);
  $field->add_element({'type' => 'submit', 'value' => 'Go'}, 1);

  my $elements_wrapper = $field->elements->[0];
  $elements_wrapper->append_child('span', {'class' => 'inp-group', 'children' => [ splice @{$elements_wrapper->child_nodes}, 0, 2 ]})->after({'node_name' => 'wbr'}) for (0..1);

  return $form->render;
}

1;
