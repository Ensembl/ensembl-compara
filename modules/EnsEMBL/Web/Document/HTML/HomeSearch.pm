package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use strict;
use base qw(EnsEMBL::Web::Document::HTML);

use EnsEMBL::Web::RegObj;

sub render {
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $page_species = $ENV{'ENSEMBL_SPECIES'};
  my $species_name = '';
  $species_name = $species_defs->SPECIES_COMMON_NAME if $page_species;
  if( $species_name =~ /\./ ) {
    $species_name = '<i>'.$species_name.'</i>'
  }
  my $html = q(
<div class="center">);

  my $search_url = $species_defs->ENSEMBL_WEB_ROOT;
  $search_url .= $page_species if $page_species.'/';
  $search_url .= 'psychic';
  my $default_search_code = $species_defs->ENSEMBL_DEFAULT_SEARCHCODE;

  $html .= sprintf q(
  <h2 class="first">Search %s %s</h2>), $species_defs->ENSEMBL_SITETYPE, $species_name unless $species_name;
  $html .= sprintf q(
  <form action="%s" method="get"><div>
    <input type="hidden" name="site" value="%s" />),
  $search_url, $default_search_code;

  my $input_size = 50;

  if (!$page_species) {
    $html .= q(
    <label for="species">Search</label>: <select id="species" name="species">
      <option value="">All species</option>
      <option value="">---</option>
);
    $input_size = 30;

    my %species = map {
      $species_defs->get_config($_, 'SPECIES_COMMON_NAME') => $_
    } @{$species_defs->ENSEMBL_SPECIES};
    foreach my $common_name (sort {uc($a) cmp uc($b)} keys %species) {
      $html .= qq(<option value="$species{$common_name}">$common_name</option>);
    }

    $html .= q(
    </select>
    <label for="q">for</label>);
  }
  else {
    $html .= q(
    <label for="q">Search for</label>:);
  }

  $html .= qq(
    <input id="q" name="q" size="$input_size" value="" />
    <input type="submit" value="Go" class="input-submit" />);

  ## Examples
  my %sample_data = %{$species_defs->SAMPLE_DATA};
  my @examples;
  if (!$page_species) {
    @examples = ('human gene BRCA2', 'rat X:100000..200000', 'insulin');
  }
  else {
    @examples = ('gene '.$sample_data{'GENE_TEXT'}, $sample_data{'LOCATION_TEXT'}, $sample_data{'SEARCH_TEXT'});
  }
  $html .= '
    <p>e.g. ' . join(' or ', map {'<strong>'.$_.'</strong>'} @examples) . '</p>';

  $html .= qq(
  </div></form>
</div>);

  return $html;

}

1;
