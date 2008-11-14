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
  $species{'Anole lizard'} = {
        'dir'  => 'Anolis_carolinensis',
        'status'  => 'pre',
  };
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
  $break++ if $total % 2;
  my $link_style = 'font-size:1.1em;font-weight:bold;text-decoration:none;';

  my $i = 1;
  my $html = qq(
<h2>Ensembl Species</h2>
<div class="threecol-left">
  <ul>);
  foreach my $common (sort keys %species) {
    if ($i == $break + 1) {
      $html .= qq(</ul>
</div><div class="threecol-middle">
  <ul>);
    }
    elsif ( $i == (2*$break)+1) {
      $html .= qq(</ul>
</div><div class="threecol-right">
  <ul>);
    }
    my $info = $species{$common};
    $html .= '<li style="list-style: url(/img/species/thumb_'.$info->{'dir'}.'.png)">';
    if ($info->{'status'} eq 'pre') {
      $html .= '<a href="http://pre.ensembl.org/'.$info->{'dir'}.'/" rel="external"';
    }
    else {
      $html .= '<a href="/'.$info->{'dir'}.'/Info/Index/"';
    }
    $html .= ' style="'.$link_style.'">'.$common.'</a>';
    $html .= ' (preview - assembly only)' if $info->{'status'} eq 'pre';
    $html .= '</li>';
    $i++;
  }
  $html .= qq(
  </ul>
</div>);
  return $html;

}

}

1;
