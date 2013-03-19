package EnsEMBL::Web::Document::HTML::SpeciesPage;

### Renders the content of the  "Find a species page" linked to from the SpeciesList module

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my ($self, $request) = @_;

  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $sitename      = $species_defs->ENSEMBL_SITETYPE;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;

  ## Get current Ensembl species
  my @valid_species = $species_defs->valid_species;
  my $species_check;
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species;
  foreach my $sp (@valid_species) {
    my $info    = {
        'dir'       => $sp,
        'common'    => $species_defs->get_config($sp, "SPECIES_COMMON_NAME"),
        'status'    => 'live',
        'sci_name'  => $species_defs->get_config($sp, "SPECIES_SCIENTIFIC_NAME"),
        'assembly'  => $species_defs->get_config($sp, 'ASSEMBLY_NAME'),
    };
    $species{$sp} = $info;
  }

  ## Add in pre species
  my $pre_species = $species_defs->get_config('MULTI', 'PRE_SPECIES');
  if ($pre_species) {
    while (my ($bioname, $array) = each (%$pre_species)) {
      my ($common, $assembly) = @$array;
      $common =~ s/_/ /;
      my $status = $species{$bioname} ? 'both' : 'pre';
      my $info;
      if ($status eq 'pre') {
        ## This is a bit of a fudge, but we have only basic config atm
        (my $sci_name = $bioname) =~ s/_/ /g;
        $info = {
          'dir'       => $bioname,
          'common'    => $common,
          'sci_name'  => $sci_name,
          'status'    => $status,
          'assembly'  => $assembly,
        };
      }
      else {
        ## Don't overwrite existing meta info!
        $info = $species{$bioname};
        $info->{'pre_assembly'} = $assembly;
      }
      $info->{'status'} = $status;
      $species{$bioname} = $info;
    }
  }

  ## Display all the species in three column layout
  my @htmlspecies;
  my %htmllinks = (
    'pre'   => '<span class="bigtext">%2$s</span> (<a href="http://pre.ensembl.org/%1$s/" rel="external">preview - assembly only</a>)',
    'both'  => '<a class="bigtext" href="/%1$s/Info/Index/">%2$s</a> (<a href="http://pre.ensembl.org/%1$s/" rel="external">preview new assembly %4$s</a>)',
    'live'  => '<a class="bigtext" href="/%1$s/Info/Index/">%2$s</a>'
  );

  foreach my $info (sort {$a->{'common'} cmp $b->{'common'}} values %species) {
    next unless $info;
    my $dir       = $info->{'dir'};
    next unless $dir;
    my $common    = $info->{'common'};
    my $name      = $info->{'sci_name'};
    my $link_text = $common =~ /\./ ? $name : $common;

    push @htmlspecies, sprintf(
      '<div class="species-box"><span class="sp-img"><img src="%3$s/i/species/48/%1$s.png" alt="%5$s" /></span>'.$htmllinks{$info->{'status'}}.($_ =~ /\./ ? '' : '<br /><i>%5$s</i>').'<br />%6$s</div>',
      $dir,
      $link_text,
      $static_server,
      $info->{'pre_assembly'},
      $name,
      $info->{'assembly'}
    );
  }

  my $row_count = int @htmlspecies / 3 + 1;

  return sprintf('<h2>%s Species</h2>
    <div class="column-wrapper">
      <div class="column-three"><div class="column-padding no-left-margin">%s</div></div>
      <div class="column-three"><div class="column-padding">%s</div></div>
      <div class="column-three"><div class="column-padding no-right-margin">%s</div></div>
    </div>',
    $sitename,
    join('', splice @htmlspecies, 0, $row_count),
    join('', splice @htmlspecies, 0, $row_count),
    join('', @htmlspecies)
  );
}

1;
