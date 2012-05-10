package EnsEMBL::Web::Document::HTML::SpeciesPage;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use POSIX qw(ceil floor);
use EnsEMBL::Web::RegObj;

sub render {

  my ($class, $request) = @_;

  my $species_defs  = $ENSEMBL_WEB_REGISTRY->species_defs;
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
    my $common  = $species_defs->get_config($species, "SPECIES_COMMON_NAME");
    my $info    = {
        'dir'       => $species,
        'status'    => 'live',
        'sci_name'  => $species_defs->get_config($species, "SPECIES_SCIENTIFIC_NAME"),
        'assembly'  => $species_defs->get_config($species, 'ASSEMBLY_NAME'),
    };
    $species{$common} = $info;
  }

  ## Add in pre species
  my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  if ($pre_species) {
    while (my ($bioname, $array) = each (%$pre_species)) {
      my ($common, $assembly) = @$array;
      $common =~ s/_/ /;
      my $status = $species{$common} ? 'both' : 'pre';
      my $info;
      if ($status eq 'pre') {
        ## This is a bit of a fudge, but we have only basic config atm
        (my $sci_name = $bioname) =~ s/_/ /g;
        $info = {
          'dir'       => $bioname,
          'sci_name'  => $sci_name,
          'status'    => $status,
          'assembly'  => $assembly,
        };
      }
      else {
        ## Don't overwrite existing meta info!
        $info = $species{$common};
        $info->{'pre_assembly'} = $assembly;
      }
      $info->{'status'} = $status;
      $species{$common} = $info;
    }
  }

  ## Display all the species in three column layout
  my @htmlspecies;
  my %htmllinks = (
    'pre'   => '<span class="bigtext">%2$s</span> (<a href="http://pre.ensembl.org/%1$s/" rel="external">preview - assembly only</a>)',
    'both'  => '<a class="bigtext" href="/%1$s/Info/Index/">%2$s</a> (<a href="http://pre.ensembl.org/%1$s/" rel="external">preview new assembly %4$s</a>)',
    'live'  => '<a class="bigtext" href="/%1$s/Info/Index/">%2$s</a>'
  );

  for (sort keys %species) {
    next unless $_;
    my $info      = $species{$_};
    my $dir       = $info->{'dir'};
    next unless $dir;
    my $name      = $info->{'sci_name'};
    my $link_text = $_ =~ /\./ ? $name : $_;

    push @htmlspecies, sprintf(
      '<div class="species-box"><img src="%3$s/img/species/thumb_%1$s.png" alt="%5$s" />'.$htmllinks{$info->{'status'}}.($_ =~ /\./ ? '' : '<br /><i>%5$s</i>').'<br />%6$s</div>',
      $dir,
      $link_text,
      $static_server,
      $info->{'pre_assembly'},
      $name,
      $info->{'assembly'}
    );
  }

  my $row_count = ceil(@htmlspecies / 3);

  return sprintf('<h2>%s Species</h2>
    <div class="threecol-wrapper">
      <div class="threecol-column"><div class="threecol-padding">%s</div></div>
      <div class="threecol-column"><div class="threecol-padding">%s</div></div>
      <div class="threecol-column"><div class="threecol-padding">%s</div></div>
    </div>',
    $sitename,
    join('', splice @htmlspecies, 0, $row_count),
    join('', splice @htmlspecies, 0, $row_count),
    join('', @htmlspecies)
  );
}

1;
