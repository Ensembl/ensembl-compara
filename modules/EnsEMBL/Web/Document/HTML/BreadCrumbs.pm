package EnsEMBL::Web::Document::HTML::BreadCrumbs;
use strict;
use EnsEMBL::Web::Document::HTML;
use EnsEMBL::Web::RegObj;

### Package to generate breadcrumb links (currently incorporated into masthead)
### Limited to three levels in order to keep masthead neat :)

our @ISA = qw(EnsEMBL::Web::Document::HTML);

sub render   {
  my $sd = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $you_are_here = $ENV{'SCRIPT_NAME'};
  my $html;

  ## Link to home page
  if ($you_are_here eq '/index.html') {
    $html = qq(<strong>Home</strong>);
  }
  else {
    $html = qq(<a href="/">Home</a>);
  }

  ## Species/static content links
  my $species = $ENV{'ENSEMBL_SPECIES'};

  ## Temporary hack to deal with broken species_defs
  my %sp_info = (
    'Aedes_aegypti'       => 'Aedes',
    'Anopheles_gambiae'   => 'Anopheles',
    'Bos_taurus'          => 'Cow',
    'Caenorhabditis_elegans' => '<i>C. elegans</i>',
    'Canis_familiaris'    => 'Dog',
    'Cavia_porcellus'     => 'Guinea pig',
    'Ciona_intestinalis'  => '<i>C. intestinalis</i>',
    'Ciona_savignyi'      => '<i>C. savignyi</i>',
    'Danio_rerio'         => 'Zebrafish',
    'Dasypus_novemcinctus' => 'Armadillo',
    'Drosophila_melanogaster' => 'Fly',
    'Echinops_telfairi'   => 'Lesser hedgehog tenrec',
    'Erinaceus_europaeus' => 'Hedgehog',
    'Equus_caballus'      => 'Horse',
    'Felis_catus'         => 'Cat',
    'Gallus_gallus'       => 'Chicken',
    'Gasterosteus_aculeatus' => 'Stickleback',
    'Homo_sapiens'        => 'Human',
    'Loxodonta_africana'  => 'Elephant',
    'Macaca_mulatta'      => 'Macaque',
    'Microcebus_murinus'  => 'Bushbaby',
    'Monodelphis_domestica' => 'Opossum',
    'Mus_musculus'        => 'Mouse',
    'Myotis_lucifugus'    => 'Microbat',
    'Ochotona_princeps'   => 'Pika',
    'Ornithorhynchus_anatidus' => 'Platypus',
    'Oryctolagus_cuniculus' => 'Rabbit',
    'Oryzias_latipes'     => 'Medaka',
    'Pan_troglodytes'     => 'Chimp',
    'Pongo_pygmaeus'      => 'Orangutan',
    'Rattus_norvegicus'   => 'Rat',
    'Saccharomyces_cerevisiae' => 'Yeast',
    'Sorex_araneus'       => 'Shrew',
    'Spermophilus_tridecemlineatus' => 'Ground squirrel',
    'Takifugu_rubripes'   => 'Fugu',
    'Tetraodon_nigroviridis' => 'Tetraodon',
    'Tupaia_belangeri'    => 'Tree shrew',
    'Xenopus_tropicalis'  => '<i>X. tropicalis</i>',
  );

  if ($species) {
    if ($species eq 'common') {
      $html .= qq( &gt; <strong>Control Panel</strong>);
    }
    else {
      my $display_name = $sp_info{$species};
      if ($you_are_here eq '/'.$species.'/index.html') {
        $html .= qq( &gt; <strong>$display_name</strong>);
      }
      else {
        $html .= qq( &gt; <a href="/$species/">).$display_name.qq(</a>);
      }
    }
  }
  elsif ($you_are_here =~ m#^/info/#) {

    ## Level 2 link
    if ($you_are_here eq '/info/index.html') {
      $html .= qq( &gt; <strong>Documentation</strong>);
    }
    else {
      $html .= qq( &gt; <a href="/info/">Documentation</a>);
    }

    ## Level 3 link - TO DO
  }
  $_[0]->printf($html);
}

1;

