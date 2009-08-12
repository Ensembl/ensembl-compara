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

  ## Add in pre species
  my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  if ($pre_species) {
    while (my ($bioname, $common) = each (%$pre_species)) {
      my $status = $species{$common} ? 'both' : 'pre';
      $species{$common} = {
        'dir'     => $bioname,
        'status'  => $status,
      };
    }
  }
  

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
  my ($row, $col);
  my @species = sort keys %species;
  for (my $i=0; $i < $total; $i++) {
    $row = int($i/3);
    $col = $i % 3;
    if ($col == 0 && $i < ($total - 1)) {
     $html .= qq(</tr>\n<tr>);
    }
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
        $html .= qq(<span style = "$link_style">$link_text</span> (<a href="http://pre.ensembl.org/$dir/" rel="external">preview - assembly only</a>));
      }
      elsif ($info->{'status'} eq 'both') {
        $html .= qq#<a href="/$dir/Info/Index/"  style="$link_style">$link_text</a> (<a href="http://pre.ensembl.org/$dir/" rel="external">preview new assembly</a>)#;
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
