package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
use warnings;
use Data::Dumper;

use EnsEMBL::Web::RegObj;

{

sub render {

  my ($class, $request) = @_;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my @valid_species = $species_defs->valid_species;
  my $species_check;
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species_info;
  foreach my $species (@valid_species) {
    my $info = {};
    $info->{'common'}     = $species_defs->get_config($species, "SPECIES_COMMON_NAME");
    $info->{'assembly'}   = $species_defs->get_config($species, "ASSEMBLY_NAME");
    $info->{'genebuild'}  = $species_defs->get_config($species, "GENEBUILD_DATE");
    $species_info{$species} = $info;
  }

  my %species_description = _setup_species_descriptions(\%species_info);

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my $html = '';

  if ($request && $request eq 'fragment') {
    $html .= _render_species_list(\%species_info, \%species_description); 
  } else {
    $html .= qq(<div id="reorder_species" style="display: none;">);
    $html .= _render_ajax_reorder_list(\%species_info); 
    $html .= qq(</div>\n<div id="full_species">);
    $html .= _render_species_list(\%species_info, \%species_description); 
    $html .= qq(</div>
<p>Other pre-build species are available in <a href="http://pre.ensembl.org" rel="external">Ensembl <em>Pre<span class="red">!</span></em> &rarr;</a></p>
);
  }

  return $html;

}

sub _render_species_list {
  my ($species_info, $description) = @_;
  my ($html, $species_name, $species_dir, $id, $group);
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my @favourites = @{_get_favourites($user, $species_info)};
  if (scalar(@favourites) < 1) {
    @favourites = @{_get_defaults($species_defs)};
  }
  my (%check_faves, @ok_faves);
  foreach my $fave (@favourites) {
    push @ok_faves, $fave unless $check_faves{$fave};
    $check_faves{$fave}++;
  }
 
  ## output list
  $html .= qq(<div id="static_favourite_species">
<h2 class="first">Browse a Genome</h2>
<p>The Ensembl project produces genome databases
  for vertebrates and other eukaryotic species, and makes this information
  freely available online.</p>
<p>Click on a link below to go to the species' home page.</p>

<p>);

  if ($species_defs->ENSEMBL_LOGINS && $user && scalar(@ok_faves)) {
    $html .= qq(<span style="font-size:1.2em;font-weight:bold">Favourite genomes</span>);
  }
  else {
    $html .= qq(<span style="font-size:1.2em;font-weight:bold">Popular genomes</span>);
  }
  if (!$user) {
    if ($species_defs->ENSEMBL_LOGINS) {
      $html .= qq# (<a href="/Account/Login" class="modal_link">Log in to customize this list</a>)#;
    }
  } else {
    if ($species_defs->ENSEMBL_LOGINS) {
      $html .= ' (<span class="link toggle_link">Change favourites</span>)';
    }
  }
  $html .= '</p>';
  $html .= _render_with_images(\@ok_faves, $species_defs, $description);

  $html .= "</div>\n";

  $html .= qq(<div id='static_all_species'>);
  $html .= _render_species_dropdown($species_info, $description);
  $html .= qq(</div>\n);
  return $html;
}

sub _render_species_dropdown {
  my ($species_info, $description) = @_; 
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $html = qq(<form action="#">
<h3>All genomes</h3>
<div>
<select name="species" class="dropdown_redirect" id="species_dropdown">
  <option value="/">-- Select a species --</option>
);

  my @all_species = keys %$species_info;

  ## sort out labels
  my $labels = $species_defs->TAXON_LABEL;
  my @group_order;
  my %label_check;
  if ($species_defs->TAXON_ORDER) {
    foreach my $taxon (@{$species_defs->TAXON_ORDER}) {
      my $label = $labels->{$taxon} || $taxon;
      push @group_order, $label unless $label_check{$label};
      $label_check{$label}++;
    }
  }

  ## Sort species into desired groups
  my (%phylo_tree, $species_name);
  foreach $species_name (@all_species) {
    my $group = $species_defs->get_config($species_name, "SPECIES_GROUP");
    if ($group) {
      $group = $labels->{$group} || $group;   
    }
    else {
      ## Allow for non-grouped species lists
      $group = 'no_group';
    }
    if ($phylo_tree{$group}) {
      push @{$phylo_tree{$group}}, $species_name;
    }
    else {
      $phylo_tree{$group} = [$species_name];
    }
  }  

  ## Output in taxonomic groups, ordered by common name
  my $others = 0;
  foreach my $group_name (@group_order) {
    my $optgroup = 0;
    my @sorted_by_common; 
    my $species_list = $phylo_tree{$group_name};
    if ($species_list && ref($species_list) eq 'ARRAY' && scalar(@$species_list) > 0) {
      if ($group_name eq 'no_group') {
        if (scalar(@group_order) > 1) {
          $html .= '<optgroup label="Other species">'."\n";
          $optgroup = 1;
          $others = 1;
        }
      }
      else {
        (my $group_text = $group_name) =~ s/&/&amp;/g;
        $html .= '<optgroup label="'.$group_text.'">'."\n";
        $optgroup = 1;
      }
      @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} }
			  map  { { 'name'=> $_, 'common' => $species_defs->get_config($_, "SPECIES_COMMON_NAME")} }
                          @$species_list;
    }
    foreach my $species (@sorted_by_common) {
      $html .= sprintf '<option value="%s/Info/Index">%s', CGI::escapeHTML( $species->{'name'} ), CGI->escapeHTML( $species->{'common'} );
      $html .= $description->{ $species->{'name'} }[1] if $description->{ $species->{'name'} }[1];
      $html .= '</option>'."\n";
    }
    if( $optgroup ) {
      $html .= '</optgroup>'."\n";
      $optgroup = 0;
    }
  }

  my $optgroup = 0;
  unless($others) {
    $html .= '<optgroup label="Other species">'."\n";
    $optgroup = 1;
  }

  $html .= qq(
  <option value="/species.html">-- Find a species --</option>);
  $html .= '
  </optgroup>'."\n" if $optgroup == 1;
  $html .= qq(
</select>
</div>
</form>
);
  return $html;

}  

sub _render_ajax_reorder_list {
  my $species_info = shift;
  my ($html, $species_name, $species_dir, $id);
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  $html .= qq(For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <span class="link toggle_link">Save</span><br /><br />\n);

  $html .= qq(<div id="favourite_species">\n<strong>Favourites</strong>);
  my @favourites = @{_get_favourites($user, $species_info)};
  if (scalar(@favourites) < 1) {
    @favourites = @{_get_defaults($species_defs)};
  }

  $html .= qq(<ul id="favourites_list">\n);
  foreach $species_name (@favourites) {
    $species_dir = $species_name;
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($species_dir, 'SPECIES_COMMON_NAME');
    $html .= qq#<li id="favourite-$species_dir">$common (<em>$species_name</em>)</li>\n#;
  }

  $html .= qq(</ul></div>
  <div id="all_species">\n<strong>Other available species</strong>
    <ul id="species_list">\n);

  my %sp_to_sort = %$species_info;
  foreach my $fave (@favourites) {
    delete $sp_to_sort{$fave};
  }
  my @sorted_by_common = sort {
                          $species_defs->get_config($a, "SPECIES_COMMON_NAME")
                          cmp
                          $species_defs->get_config($b, "SPECIES_COMMON_NAME")
                          } keys %sp_to_sort;
  foreach $species_name (@sorted_by_common) {
    $species_dir = $species_name;
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($species_dir, 'SPECIES_COMMON_NAME');
    $html .= qq#<li id="species-$species_dir">$common (<em>$species_name</em>)</li>\n#;
  }

  $html .= qq(</ul></div>
      <span class="link toggle_link">Save selection</span> &middot; <a href="/Account/ResetFavourites">Restore default list</a>);

  return $html;
}

sub _setup_species_descriptions {
  my $species_info = shift;
  my %description = ();
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $updated = '<strong class="alert">NEW ASSEMBLY</strong>';
  my ($html, $dropdown);

  while (my ($species, $info) = each (%$species_info)) {
    $html = qq( <span class="small normal">);
    $html .= $info->{'assembly'} if $info->{'assembly'};
=pod
    if (!$info->{'prev_assembly'}) {
      $dropdown = ' - NEW SPECIES';
    } elsif ($info->{'prev_assembly'} && $info->{'prev_assembly'} ne $info->{'assembly'}) {
      $html .= ' '.$updated;
      $dropdown = ' - NEW ASSEMBLY';
    }
    else {
      $dropdown = '';
    }
=cut
    $html  .= qq(</span>);
    if ($species) {
      $description{$species} = [$html, $dropdown];
    }
  }

  return %description;
}

sub _get_favourites {
  ## Returns a list of species as Genus_species strings
  my ($user, $species_info) = @_;

  my @specieslists = ();
  if ($user) {
    @specieslists = $user->specieslists;
  }
  my @favourites = ();

  if (scalar(@specieslists) > 0 && $specieslists[0]) {
    my $list = $specieslists[0];
    my @current_favourites = split(/,/, $list->favourites);
    ## Omit any species not currently online
    foreach my $fave (@current_favourites) {
      push @favourites, $fave if $species_info->{$fave};
    }
  }
  return \@favourites;
}

sub _get_defaults {
  my $species_defs = shift;
  my @defaults = ();
  @defaults = @{$species_defs->DEFAULT_FAVOURITES} if $species_defs->DEFAULT_FAVOURITES;
  if (scalar(@defaults) < 1) {
    @defaults = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES);
  }
  return \@defaults;
}

sub _render_with_images {
  my ($species_list, $species_defs, $description) = @_;

  my $html = qq(\n<dl class="species-list">\n);

  foreach my $species (@$species_list) {
    my $common_name = $species_defs->get_config($species, "SPECIES_COMMON_NAME") || '';
    (my $species_name = $species) =~ s/_/ /g;
    $html .= qq(<dt><a href="/$species/"><img src="/img/species/thumb_$species.png" alt="$species_name" title="Browse $species_name" class="sp-thumb" height="40" width="40" /></a><a href="/$species/Info/Index" title="$species_name">$common_name</a></dt>\n);
    $html .= "<dd>" . $description->{$species}[0] . "</dd>\n" if $description->{$species}[0];
  }
  $html .= "</dl>\n";
  
  return $html;
}

}

1;
