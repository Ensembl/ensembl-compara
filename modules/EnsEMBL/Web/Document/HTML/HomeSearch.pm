package EnsEMBL::Web::Document::HTML::HomeSearch;

use strict;

use EnsEMBL::Web::RegObj;

{

sub render {
  my ($class, $request) = @_;


  my $html = qq(<div class="boxed pale" style="margin:10px 25px 0px 7px">
<div style="margin:auto; text-align:center">
  <h3>Search Ensembl</h3>

  <form action="/default/psychic" method="get" style="font-size: 0.9em"><div>

    Search:
    <select name="species" style="font-size: 0.9em">
      <option value="">All species</option>
      <option value="">---</option>
      <option value="Homo_sapiens">Homo sapiens</option>
      <option value="Mus_musculus">Mus musculus</option>
      <option value="Danio_rerio">Danio rerio</option>
      <option value="">---</option>
);

  my $species_defs = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->species_defs;
  foreach my $species (@{$species_defs->ENSEMBL_SPECIES}) {
    my $bio_name = $species_defs->other_species($species, "SPECIES_BIO_NAME");
    $html .= qq(<option value="$species">$bio_name</option>);
  }

  $html .= qq(</select>
    for <input name="query" size="50" value="" />
    <input type="submit" value="Go" class="red-button" /></div>
    <p>e.g. <strong>mouse chromosome 2</strong> or <strong>rat X:10000..20000</strong> or <strong>human gene BRCA2</strong></p>
    </form>

</div>
</div>
);

  return $html;

}


}

1;
