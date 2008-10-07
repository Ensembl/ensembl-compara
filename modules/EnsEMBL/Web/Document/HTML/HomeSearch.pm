package EnsEMBL::Web::Document::HTML::HomeSearch;

### Generates the search form used on the main home page and species
### home pages, with sample search terms taken from ini files

use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub new {
  return shift->SUPER::new(
    '_home_url' => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT,
    '_default'  => $ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEFAULT_SEARCHCODE,
  );
}

sub home_url { return $_[0]{'_home_url'};  }

sub default_search_code { return $_[0]{'_default'}; }

sub search_url {
    my $species = $_[0]->home_url.$ENSEMBL_WEB_REGISTRY->get_species;
    return $species ? "$species/psychic" : '/common/psychic';
}

sub render {
  my $self = shift;
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $page_species = $ENV{'ENSEMBL_SPECIES'};
  $page_species = '' if $page_species eq 'common';
  my $species_name = $species_defs->SPECIES_COMMON_NAME if $page_species;
  if ($species_name =~ /\./) {
    $species_name = '<i>'.$species_name.'</i>'
  }
  my $html = qq(<div class="center">\n);

  $html .= sprintf(qq(<h2 class="first">Search %s %s</h2>
<form action="%s" method="get"><div>
  <input type="hidden" name="site" value="%s" />),
  $species_defs->ENSEMBL_SITETYPE, $species_name, $self->search_url, $self->default_search_code
);

  my $input_size = 50;

  if (!$page_species) {
    $html .= qq(<label for="species">Search</label>: <select id="species" name="species">
<option value="">All species</option>
<option value="">---</option>
);
  $input_size = 30;

  foreach $species (@{$species_defs->ENSEMBL_SPECIES}) {
    my $common_name = $species_defs->get_config($species, 'SPECIES_COMMON_NAME');
      $html .= qq(<option value="$species">$common_name</option>);
    }

    $html .= qq(</select>
    <label for="q">for</label> );
  }
  else {
    $html .= qq(<label for="q">Search for</label>: );
  }

  $html .= qq(<input id="q" name="q" size="$input_size" value="" />
    <input type="submit" value="Go" class="input-submit" />);

  ## Examples
  my %sample_data = %{$species_defs->SAMPLE_DATA};
  my @examples;
  if (!$page_species) {
    @examples = ('human gene BRCA2', 'rat X:100000..200000', 'insulin');
  }
  else {
    @examples = ('gene '.$sample_data{'GENE_TEXT'}, $sample_data{'LOCATION_PARAM'}, $sample_data{'SEARCH_TEXT'});
  }
  $html .= '<p>e.g. ' . join(' or ', map {'<strong>'.$_.'</strong>'} @examples) . '</p>';

  $html .= qq(\n</div></form>\n</div>\n);

  return $html;

}

1;
