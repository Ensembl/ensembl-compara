# $Id$

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;

use HTML::Entities qw(encode_entities);

use EnsEMBL::Web::RegObj;

sub render {
  my $class        = shift;
  my $fragment     = shift eq 'fragment';
  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;
  my $user         = $ENSEMBL_WEB_REGISTRY->get_user;
  my $species_info = {};
 
  foreach ($species_defs->valid_species) {
    $species_info->{$_} = {
      name     => $species_defs->get_config($_, 'SPECIES_BIO_NAME',    1),
      common   => $species_defs->get_config($_, 'SPECIES_COMMON_NAME', 1),
      assembly => $species_defs->get_config($_, 'ASSEMBLY_NAME',       1)
    };
  }
  
  my %description = map { $_ => qq{ <span class="small normal">$species_info->{$_}->{'assembly'}</span>} } grep { $_ && $species_info->{$_}->{'assembly'} } keys %$species_info;
  my $full_list   = render_species_list($species_defs, $user, $species_info, \%description, $fragment);
  
  my $html = $fragment ? $full_list : sprintf('
    <div id="species_list" class="js_panel">
      <input type="hidden" class="panel_type" value="SpeciesList" />
      <div class="reorder_species" style="display: none;">
         %s
      </div>
      <div class="full_species">
        %s 
      </div>
    </div>
  ', render_ajax_reorder_list($species_defs, $user, $species_info), $full_list);

  return $html;
}

sub render_species_list {
  my ($species_defs, $user, $species_info, $description, $fragment) = @_;
  my (%check_faves, @ok_faves);
  
  foreach (get_favourites($species_defs, $user, $species_info)) {
    push @ok_faves, $_ unless $check_faves{$_}++;
  }
  
  my $count    = @ok_faves;
  my $fav_html = render_favourites($count, \@ok_faves, $description, $species_defs);
  
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
  
  $html .= sprintf('
      </p>
      <div class="species_list_container">%s</div>
    </div>
    <div class="static_all_species">
      %s
    </div>
  ', $fav_html, render_species_dropdown($species_defs, $species_info, $description));
  
  return $html;
}

sub render_favourites {
  my ($count, $ok_faves, $description, $species_defs) = @_;
  
  my $html;
  
  if ($count > 3) {
    my $breakpoint = int($count / 2) + ($count % 2);
    my @first_half = splice @$ok_faves, 0, $breakpoint;
    
    $html = sprintf('
      <table style="width:100%">
        <tr>
          <td style="width:50%">%s</td>
          <td style="width:50%">%s</td>
        </tr>
      </table>',
      render_with_images(\@first_half, $species_defs, $description),
      render_with_images($ok_faves,    $species_defs, $description)
    );
  } else {
    $html = render_with_images($ok_faves, $species_defs, $description);
  }
  
  return $html;
}

sub render_species_dropdown {
  my ($species_defs, $species_info, $description) = @_; 
  my $sitename    = $species_defs->ENSEMBL_SITETYPE;
  my @all_species = keys %$species_info;
  my $labels      = $species_defs->TAXON_LABEL; ## sort out labels
  my @group_order;
  my %label_check;
  
  my $html = qq{
  <form action="#">
    <h3>All genomes</h3>
    <div>
    <select name="species" class="dropdown_redirect">
      <option value="/">-- Select a species --</option>
  };
  
  foreach my $taxon (@{$species_defs->TAXON_ORDER || []}) {
    my $label = $labels->{$taxon} || $taxon;
    push @group_order, $label unless $label_check{$label}++;
  }

  ## Sort species into desired groups
  my %phylo_tree;
  
  foreach (@all_species) {
    my $group = $species_defs->get_config($_, 'SPECIES_GROUP');
    $group    = $group ? $labels->{$group} || $group : 'no_group';
    
    push @{$phylo_tree{$group}}, $_;
  }  

  ## Output in taxonomic groups, ordered by common name  
  foreach my $group_name (@group_order) {
    my $optgroup     = 0;
    my $species_list = $phylo_tree{$group_name};
    my @sorted_by_common;
    
    if ($species_list && ref $species_list eq 'ARRAY' && scalar @$species_list) {
      if ($group_name eq 'no_group') {
        if (scalar @group_order) {
          $html    .= q{<optgroup label="Other species">\n};
          $optgroup = 1;
        }
      } else {
        (my $group_text = $group_name) =~ s/&/&amp;/g;
        $html    .= qq{<optgroup label="$group_text">\n};
        $optgroup = 1;
      }
      
      @sorted_by_common = sort { $a->{'common'} cmp $b->{'common'} } map  {{ name => $_, common => $species_defs->get_config($_, 'SPECIES_COMMON_NAME') }} @$species_list;
    }
    
    $html .= sprintf qq{<option value="%s/Info/Index">%s</option>\n}, encode_entities($_->{'name'}), encode_entities($_->{'common'}) for @sorted_by_common;
    
    if ($optgroup) {
      $html    .= "</optgroup>\n";
      $optgroup = 0;
    }
  }

  $html .= qq{
        </select>
      </div>
    </form>
    <p><a href="/info/about/species.html">View full list of all $sitename species</a></p>
  };
  
  return $html;
}

sub render_ajax_reorder_list {
  my ($species_defs, $user, $species_info) = @_;
  
  my @favourites = get_favourites($species_defs, $user, $species_info);
  my @fav_list   = map { sprintf '<li id="favourite-%s">%s (<em>%s</em>)</li>', $_, $species_defs->get_config($_, 'SPECIES_COMMON_NAME'), $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME') } @favourites;
  my %sp_to_sort = %$species_info;
  
  delete $sp_to_sort{$_} for map s/ /_/, @favourites;
  
  my @sorted       = map { $_->[1] } sort { $a->[0] cmp $b->[0] } map {[ $species_defs->get_config($_, 'SPECIES_COMMON_NAME'), $_ ]} keys %sp_to_sort;
  my @species_list = map { sprintf '<li id="species-%s">%s (<em>%s</em>)</li>', $_, $species_defs->get_config($_, 'SPECIES_COMMON_NAME'), $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME') } @sorted;
  
  return sprintf(qq{
    For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <span class="link toggle_link">Save</span>
    <br />
    <br />
    <strong>Favourites</strong>
    <ul class="favourites list">
      %s
    </ul>
    <strong>Other available species</strong>
    <ul class="species list">
      %s
    </ul>
    <span class="link toggle_link">Save selection</span> &middot; <a href="/Account/ResetFavourites">Restore default list</a>
  }, join("\n", @fav_list), join("\n", @species_list));
}

sub get_favourites {
  ## Returns a list of species as Genus_species strings
  my ($species_defs, $user, $species_info) = @_;

  my @specieslists = $user ? $user->specieslists : ();
  my @favourites   = @specieslists && $specieslists[0] ? map { $species_info->{$_} ? $_ : () } split /,/, $specieslists[0]->favourites : @{$species_defs->DEFAULT_FAVOURITES || []}; # Omit any species not currently online
  @favourites      = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES) unless scalar @favourites;
  
  return @favourites;
}

sub render_with_images {
  my ($species_list, $species_defs, $description) = @_;

  my $html = qq{
    <dl class="species-list">
  };

  foreach (@$species_list) {
    my $common_name  = $species_defs->get_config($_, 'SPECIES_COMMON_NAME')     || '';
    my $species_name = $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME') || '';
    
    $html .= qq{
      <dt>
        <a href="/$_/Info/Index"><img src="/img/species/thumb_$_.png" alt="$species_name" title="Browse $species_name" class="sp-thumb" height="40" width="40" /></a>
        <a href="/$_/Info/Index" title="$species_name">$common_name</a>
      </dt>
    };
    
    $html .= "<dd>$description->{$_}</dd>\n" if $description->{$_};
  }
  
  $html .= "
    </dl>
  ";
  
  return $html;
}

1;
