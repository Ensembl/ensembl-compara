# $Id$

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
use warnings;
no warnings qw(uninitialized);
use Data::Dumper;

use EnsEMBL::Web::RegObj;

{

sub render {
  my $class = shift;
  my $fragment = (shift eq 'fragment');
  
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my @valid_species = $species_defs->valid_species;
  my $species_check;
  
  foreach my $sp (@valid_species) {
    $species_check->{$sp}++;
  }

  my %species_info;
  
  foreach my $species (@valid_species) {
    my $info = {};
    $info->{'name'}       = $species_defs->get_config($species, "SPECIES_BIO_NAME", 1);
    $info->{'common'}     = $species_defs->get_config($species, "SPECIES_COMMON_NAME", 1);
    $info->{'assembly'}   = $species_defs->get_config($species, "ASSEMBLY_NAME", 1);
    $species_info{$species} = $info;
  }

  my %species_description = _setup_species_descriptions(\%species_info);

  my $user = $ENSEMBL_WEB_REGISTRY->get_user;
  my $full_list = _render_species_list(\%species_info, \%species_description, $fragment);
  
  my $html = $fragment ? $full_list : '
    <div id="species_list" class="js_panel">
      <input type="hidden" class="panel_type" value="SpeciesList" />
      <div class="reorder_species" style="display: none;">
         ' . _render_ajax_reorder_list(\%species_info) . '
      </div>
      <div class="full_species">
        ' . $full_list . ' 
      </div>
    </div>
  ';

  return $html;
}

sub _render_species_list {
  my ($species_info, $description, $fragment) = @_;
  
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  my @favourites = @{_get_favourites($user, $species_info)};
  
  @favourites = @{_get_defaults($species_defs)} if scalar @favourites < 1;
  
  my (%check_faves, @ok_faves);
  
  foreach my $fave (@favourites) {
    push @ok_faves, $fave unless $check_faves{$fave};
    $check_faves{$fave}++;
  }
  
  my $count = @ok_faves;
  
  my $fav_html = _render_favourites($count, \@ok_faves, $description, $species_defs);
  
  return $fav_html if $fragment;
  
  # output list
  my $html = '
    <div class="static_favourite_species">
      <p>';

  if ($species_defs->ENSEMBL_LOGINS && $user && $count) {
    $html .= '<span style="font-size:1.2em;font-weight:bold">Favourite genomes</span>';
  } else {
    $html .= '<span style="font-size:1.2em;font-weight:bold">Popular genomes</span>';
  }
  
  if ($species_defs->ENSEMBL_LOGINS) {
    if ($user) {
      $html .= ' (<span class="link toggle_link">Change favourites</span>)';
    } else {
      $html .= ' (<a href="/Account/Login" class="modal_link">Log in to customize this list</a>)';
    }
  }
  
  $html .= '</p>';
  $html .= qq{<div class="species_list_container">$fav_html</div>};
  $html .= "</div>\n";

  $html .= '<div class="static_all_species">';
  $html .= _render_species_dropdown($species_info, $description);
  $html .= "</div>\n";
  
  return $html;
}

sub _render_favourites {
  my ($count, $ok_faves, $description, $species_defs) = @_;
  
  my $html;
  
  if ($count > 3) {
    my $breakpoint = int($count / 2) + ($count % 2);
    my @first_half = splice @$ok_faves, 0, $breakpoint;
    
    $html  = '<table style="width:100%"><tr><td style="width:50%">';
    $html .= _render_with_images(\@first_half, $species_defs, $description);
    $html .= '</td><td style="width:50%">';
    $html .= _render_with_images($ok_faves, $species_defs, $description);
    $html .= '</td></tr></table>';
  } else {
    $html  = _render_with_images($ok_faves, $species_defs, $description);
  }
  
  return $html;
}

sub _render_species_dropdown {
  my ($species_info, $description) = @_; 
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $sitename = $species_defs->ENSEMBL_SITETYPE;

  my $html = qq(<form action="#">
<h3>All genomes</h3>
<div>
<select name="species" class="dropdown_redirect">
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
  <option value="/info/about/species.html">-- Full list of $sitename species --</option>);
  $html .= '
  </optgroup>'."\n" if $optgroup == 1;
  $html .= qq(
</select>
</div>
</form>
<p><a href="/info/about/species.html">View full list of all $sitename species</a></p>
);
  return $html;

}  

sub _render_ajax_reorder_list {
  my $species_info = shift;
  my ($html, $species_name, $species_dir, $id);
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user = $ENSEMBL_WEB_REGISTRY->get_user;

  $html .= qq(For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <span class="link toggle_link">Save</span><br /><br />\n);

  $html .= qq(<strong>Favourites</strong>);
  my @favourites = @{_get_favourites($user, $species_info)};
  if (scalar(@favourites) < 1) {
    @favourites = @{_get_defaults($species_defs)};
  }

  $html .= qq(<ul class="favourites list">\n);
  foreach $species_name (@favourites) {
    $species_dir = $species_name;
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($species_dir, 'SPECIES_COMMON_NAME');
    $html .= qq#<li id="favourite-$species_dir">$common (<em>$species_name</em>)</li>\n#;
  }

  $html .= qq(</ul>
  <strong>Other available species</strong>
    <ul class="species list">\n);

  my %sp_to_sort = %$species_info;
  foreach my $fave (@favourites) {
    (my $dir = $fave) =~ s/ /_/;
    delete $sp_to_sort{$dir};
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

  $html .= qq(</ul>
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
    $html .= qq(<dt><a href="/$species/Info/Index"><img src="/img/species/thumb_$species.png" alt="$species_name" title="Browse $species_name" class="sp-thumb" height="40" width="40" /></a><a href="/$species/Info/Index" title="$species_name">$common_name</a></dt>\n);
    $html .= "<dd>" . $description->{$species}[0] . "</dd>\n" if $description->{$species}[0];
  }
  $html .= "</dl>\n";
  
  return $html;
}

}

1;
