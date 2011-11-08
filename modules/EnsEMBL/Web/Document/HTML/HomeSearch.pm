package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

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
  $species_name           = "<i>$species_name</i>" if $species_name =~ /\./;
  my $search_url          = $species_defs->ENSEMBL_WEB_ROOT . "$page_species/psychic";
  my $default_search_code = $species_defs->ENSEMBL_DEFAULT_SEARCHCODE;
  my $input_size          = $page_species eq 'Multi' ? 30 : 50;
  my $favourites          = $self->favourites;
  my $q                   = $self->{'query'};
  
  my $html = qq{
  <div class="center">
    <form action="$search_url" method="get"><div>
      <input type="hidden" name="site" value="$default_search_code" />};
  
  if ($page_species eq 'Multi') {
    my %species      = map { $species_defs->get_config($_, 'DISPLAY_NAME') => $_ } @{$species_defs->ENSEMBL_DATASETS};
    my %common_names = reverse %species;
    
    $html .= '
    <label for="species">Search</label>: <select id="species" name="species">
      <option value="">All species</option>
      <option value="">---</option>';
    
    if (scalar @$favourites) {
      $html .= '<optgroup label="Favourite species">';
      $html .= qq{<option value="$_">$common_names{$_}</option>} for grep $common_names{$_}, @$favourites;
      $html .= '</optgroup>';
    }
    
    $html .= '<option value="">---</option>';
    $html .= qq{<option value="$species{$_}">$_</option>} for sort { uc $a cmp uc $b } keys %species;
    $html .= '
    </select>
    <label for="q">for</label>';
  } else {
    $html .= '<label for="q">Search for</label>:';
  }

  $html .= qq{
    <input id="q" name="q" size="$input_size" value="$q" />
    <input type="submit" value="Go" class="input-submit" />};

  ## Examples
  my $sample_data;
  
  if ($page_species eq 'Multi') {
    $sample_data = $species_defs->get_config('MULTI', 'GENERIC_DATA') || {};
  } else {
    $sample_data = { %{$species_defs->SAMPLE_DATA || {}} };
    $sample_data->{'GENE_TEXT'} = "$sample_data->{'GENE_TEXT'}" if $sample_data->{'GENE_TEXT'};
  }
  
  if (keys %$sample_data) {
    my @examples = map $sample_data->{$_} || (), qw(GENE_TEXT LOCATION_TEXT SEARCH_TEXT);
  
    $html .= sprintf '<p>e.g. %s</p>', join ' or ', map qq{<strong><a href="$search_url?q=$_" style="text-decoration:none">$_</a></strong>}, @examples if scalar @examples;
    $html .= '
      </div></form>
    </div>';
  }

  return $html;
}

1;
