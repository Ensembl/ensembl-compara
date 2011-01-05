package EnsEMBL::Web::Document::HTML::SpeciesPanel;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use EnsEMBL::Web::RegObj;

sub render {

  my ($class, $request) = @_;

  my $species_defs  = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $tree          = $species_defs->SPECIES_INFO;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;
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
  

  my $link_style = 'font-size:1.1em;font-weight:bold;text-decoration:none;';

  my $html = qq(
<h2 class="first">$sitename Species</h2>
<table>
  <tr>
  );
  my @species = sort keys %species;

  foreach my $common (@species) {
    my $info = $species{$common};
    my $dir = $info->{'dir'};
    (my $name = $dir) =~ s/_/ /;
    my $link_text = $common =~ /\./ ? $name : $common;
    $html .= qq(<tr><td style="width:8%;text-align:right;padding-bottom:1em">);
    if ($dir) {
      $html .= qq(<img src="$static_server/img/species/thumb_$dir.png" alt="$name" />);
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

    ## Add links to static content, if any
    my $static = $tree->{$dir};
    #use Data::Dumper;
    #warn ">>> $dir ".Dumper($static);

    if (keys %$static) {
      my @page_order = sort {
        $static->{$a}{'_order'} <=> $static->{$b}{'_order'} ||
        $static->{$a}{'_title'} cmp $static->{$b}{'_title'} ||
        $static->{$a} cmp $static->{$b}
      } keys %$static;

      $html .= '<ul>';

      foreach my $filename (@page_order) {
        if ($static->{$filename}{'_title'}) {
          $html .= sprintf '<li><a href="/%s/Info/Content?file=%s">%s</a></li>', 
                    $dir, $filename, $static->{$filename}{'_title'};
        }
      }
  
      $html .= '</ul>';
    }




    $html .= '</td></tr>';
  }
  $html .= qq(
</table>
);

  return $html;
}

1;
