package EnsEMBL::Web::Document::HTML::HomeSearch;

use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub new {
  return shift->SUPER::new(
    '_home_url' => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_WEB_ROOT,
    '_default'  => $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs->ENSEMBL_DEFAULT_SEARCHCODE,
  );
}

sub home_url { return $_[0]{'_home_url'};  }
sub default_search_code { return $_[0]{'_default'}; }
sub search_url { return $_[0]->home_url.$EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_species.'/Search'; }

sub render {
  my $self = shift;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $species = $ENV{'ENSEMBL_SPECIES'};
  (my $bio_name = $species) =~ s/_/ /g; 
  my $html = qq(<div class="center">\n);

  $html .= sprintf(qq(<h2>Search Genome Databases</h2>
<form action="%s" method="get">
  <input type="hidden" name="site" value="%s" />),
  $self->search_url, $self->default_search_code
);

  if (!$species) {
    $html .= qq(<label for="species">Search</label>: <select name="species">
<option value="">All species</option>
<option value="">---</option>
);

    foreach $species (@{$species_defs->ENSEMBL_SPECIES}) {
      ($bio_name = $species) =~ s/_/ /g;
      $html .= qq(<option value="$species">$bio_name</option>);
    }

    $html .= qq(</select>
    <label for="q">for</label> );
  }
  else {
    $html .= qq(<label for="q">Search for</label>: );
  }

  $html .= qq(<input name="q" size="50" value="" />
    <input type="submit" value="Go" class="input-submit" />);

  ## Examples
  my @examples = ('mouse chromosome 2', 'rat X:10000..20000', 'human gene BRCA2');
  $html .= '<p>e.g. ' . join(' or ', map {'<strong>'.$_.'</strong>'} @examples) . '</p>';

  $html .= qq(\n</form>\n</div>\n);

  return $html;

}

1;
