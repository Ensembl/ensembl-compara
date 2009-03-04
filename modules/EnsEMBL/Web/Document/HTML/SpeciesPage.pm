package EnsEMBL::Web::Document::HTML::SpeciesPage;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;
use warnings;
use Data::Dumper;

use EnsEMBL::Web::RegObj;

{

sub render {

  my ($class, $request) = @_;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $sitename = $species_defs->ENSEMBL_SITETYPE;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;
  my $species_check;
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species;
  foreach my $species (@valid_species) {
    my $common = $species_defs->get_config($species, "SPECIES_COMMON_NAME");
    my $info = {
          'dir'     => $species,
          'status'  => 'live',
    };
    $species{$common} = $info;
  }

  ## Add in pre species (currently hard-coded)
  $species{'Lamprey'} = {
        'dir' => 'Petromyzon_marinus',
        'status'  => 'pre',
  };
  $species{'Pig'} = {
        'dir' => 'Sus_scrofa',
        'status'  => 'pre',
  };

  my $total = scalar(keys %species);
  my $break = int($total / 3);
  $break++ if $total % 3;
  ## Reset total to number of cells required for a complete table
  $total = $break * 3;
  my $link_style = 'font-size:1.1em;font-weight:bold;text-decoration:none;';

  my $html = qq(
<h2>$sitename Species</h2>
<table>
  <tr>
  );
  my $row = -1;
  my @species = sort keys %species;
  for (my $i=0; $i < $total; $i++) {
    my $col = int($i % 3);
    if ($col == 0 && $i < ($total - 1)) {
     $html .= qq(</tr>\n<tr>);
    }
    my $row = int($i/3);
    $row++ if $col == 0;
    my $j = $row + $break * $col;
    my $common = $species[$j];
    next unless $common;
    my $info = $species{$common};
    my $dir = $info->{'dir'};
    (my $name = $dir) =~ s/_/ /;
    my $link_text = $common =~ /\./ ? $name : $common;
    $html .= qq(<td style="width:8%;text-align:right;padding-bottom:1em">);
    if ($dir) {
      $html .= qq(<img src="/img/species/thumb_$dir.png" alt="$name">);
    }
    else {
      $html .= '&nbsp;';
    }
    $html .= qq(</td><td style="width:25%;padding:2px;padding-bottom:1em">);
    if ($dir) {
      if ($info->{'status'} eq 'pre') {
        $html .= qq(<a href="http://pre.ensembl.org/$dir/" style="$link_style" rel="external">$link_text</a> (preview - assembly only));
      }
      else {
        $html .= qq(<a href="/$dir/Info/Index/"  style="$link_style">$link_text</a>);
      }
      unless ($common =~ /\./) {
        $html .= "<br /><i>$name</i>";
      }
    }
    else {
      $html .= '&nbsp;';
    }
    $html .= '</td>';
  }
  $html .= qq(
  </tr>
</table>);
  return $html;

}

}

1;
