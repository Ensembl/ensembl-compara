package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
#use warnings;

use EnsEMBL::Web::DBSQL::NewsAdaptor;
use EnsEMBL::Web::Object::Data::User;
use EnsEMBL::Web::RegObj;

{

sub render {
  my ($class, $request) = @_;

  my $species_defs = $ENSEMBL_WEB_REGISTRY->species_defs;

  my $adaptor = $ENSEMBL_WEB_REGISTRY->newsAdaptor();
  my %id_to_species = %{$adaptor->fetch_species($SiteDefs::ENSEMBL_VERSION)};

  my %species_description = setup_species_descriptions($species_defs);

  my $reg_user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $user_data = undef; 
  if ($reg_user->id > 0) {
    $user_data = EnsEMBL::Web::Object::Data::User->new({ id => $reg_user->id });
  }

  my $html = "";
  #warn "RENDERING CUSTOM SPECIES LIST WITH USER: " . $reg_user->id;
  if ($request && $request eq 'fragment') {
    $html .= render_species_list($user_data, $species_defs, \%id_to_species, \%species_description); 
  } else {
    #warn "REORDER LIST"; 
    $html .= "<div id='reorder_species' style='display: none;'>\n";
    $html .= render_ajax_reorder_list($user_data, $species_defs, \%id_to_species); 
    $html .= "</div>\n";
    #warn "FULL LIST";
    $html .= "<div id='full_species'>\n";
    $html .= render_species_list($user_data, $species_defs, \%id_to_species, \%species_description); 
    $html .= "</div>\n";
    $html .= qq(
<p>Other pre-build species are available in <a href='#top' onclick='show_pre();'>Ensembl Pre! &rarr;</a></p>);
  }
  return $html;

}

sub setup_species_descriptions {
  my $species_defs = shift;
  my %description = ();

  my $updated = '<strong class="alert">UPDATED!</strong>';
  my $new     = '<strong class="alert">NEW!</strong>';

  my $adaptor = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->newsAdaptor;

  my @current_species = @{$adaptor->fetch_species_data($species_defs->ENSEMBL_VERSION)};

  foreach my $species (@current_species) {
    my ($html, $short);
    my $sp = $species->{'name'};
    $html = qq( <span class="small normal">);
    $html .= $species->{'assembly'} if $species->{'assembly'};
    $short = $html;
    if (!$species->{'prev_assembly'}) {
      $html .= ' '.$new;
      $short = $html;
    } elsif ($species->{'prev_assembly'} && $species->{'prev_assembly'} ne $species->{'assembly'}) {
      $html .= ' '.$updated;
      $short = $html;
    }
    if ($species->{'vega'} && $species->{'vega'} eq 'Y') {
      $html .= qq( | <a href="http://vega.sanger.ac.uk/$sp/">Vega</a>);
    }
    if ($species->{'pre'}) {
      $html .= ' | ';
      if (!$species->{'prev_pre'} || ($species->{'prev_pre'} && $species->{'prev_pre'} ne $species->{'pre'})) {
        $html .= $updated.' ';
      }
      $html .= qq(<a href="http://pre.ensembl.org/$sp/"><i><span class="red">pr<span class="blue">e</span>!</span></i></a>);
    }
    $short .= qq(</span>);
    $html  .= qq(</span>);
    if ($sp) {
      (my $name = $sp) =~ s/_/ /;
      $description{$name} = [$html, $short];
    }
  }

  return %description;
}

sub render_species_list {
  my ($user, $species_defs, $id_to_species, $species_description) = @_;
  my %description = %{ $species_description };
  my %id_to_species = %{ $id_to_species };
  my %species_id = reverse %id_to_species;
  my @specieslists = ();
  if ($user && $user->id) {
    @specieslists = @{ $user->specieslists };
  }
  my @favourites = ();
  my $html = "";

  if ($#specieslists < 0) {
    my $defaults = $species_defs->DEFAULT_FAVOURITES;
    if (!$defaults || ref($defaults) ne 'ARRAY' || scalar(@$defaults < 1)) {
      $defaults = [$species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES];
    } 
    foreach my $name (@$defaults) {
      push @favourites, $species_id{$name};
    }
  }
  else {
    my $list = $specieslists[0];
    @favourites = split(/,/, $list->favourites); 
  }

  ## output list
  if (!$user) {
    $html .= "<b>Popular genomes</b> &middot; \n";
    $html .= '<a href="javascript:login_link()">Log in to customize</a>';
  } else {
    $html .= "<b>Favourite genomes</b> &middot; \n";
    $html .= '<a href="javascript:void(0);" onClick="toggle_reorder();">Change favourites</a>';
  }
  $html .= "<div id='static_favourite_species'>\n";
  $html .= "<div class='favourites-species-list'>\n";
  $html .= "<dl class='species-list'>\n";

  ## Render favourites with images
  foreach my $id (@favourites) {
    my $species_filename = $id_to_species{$id};
    my $species_name = $species_filename;
    my $common_name = $species_defs->other_species($species_filename, "SPECIES_COMMON_NAME");
    $species_name =~ s/_/ /g;
    $html .= "<dt class='species-list'><a href='/$species_filename/'><img src='/img/species/thumb_$species_filename.png' alt='$species_name' title='Browse $species_name' class='sp-thumb' height='40' width='40' /></a><a href='/$species_filename/' title='$species_name'>$common_name</a></dt>\n";
    $html .= "<dd>" . $description{$species_name}[0] . "</dd>\n";
  }
  $html .= "</dl>\n";
  $html .= "</div>\n";
  $html .= "</div>\n";

  $html .= qq(<div id='static_all_species'>
<form action="#">
<h3>All genomes</h3>
<select name="species"  id="species_dropdown" onchange="dropdown_redirect('species_dropdown');">
  <option value="/">-- Select a species --</option>
);

  my @all_species = keys %species_id;

  ## Sort species into phylogenetic groups
  my %phylo_tree;
  foreach my $species (@all_species) {
    my $group = $species_defs->other_species($species, "SPECIES_GROUP");
    if (!$group) {
      ## Allow for non-grouped species lists
      $group = 'no_group';
    }
    if ($phylo_tree{$group}) {
      push @{$phylo_tree{$group}}, $species;
    }
    else {
      $phylo_tree{$group} = [$species];
    }
  }  

  #my @taxon_order = @{$species_defs->TAXON_ORDER};
  my @taxon_order = ('Primates', 'Rodents etc.', 'Laurasiatheria', 'Afrotheria', 'Xenarthra',
                      'Marsupials &amp; Monotremes', 'Birds', 'Reptiles &amp; Amphibians',
                      'Fish', 'Other chordates', 'Other eukaryotes');

  ## Output in taxonomic groups, ordered by common name
  foreach my $group (@taxon_order) {
    $html .= '<optgroup label="'.$group.'">'."\n" unless $group eq 'no_group';
    my $species_group = $phylo_tree{$group};
    my @sorted_by_common; 
    if ($species_group && ref($species_group) eq 'ARRAY') {
      @sorted_by_common = sort {
                          $species_defs->other_species($a, "SPECIES_COMMON_NAME")
                          cmp
                          $species_defs->other_species($b, "SPECIES_COMMON_NAME")
                          } @$species_group;
    }
    foreach my $species (@sorted_by_common) {
      $html .= '<option value="/'.$species.'/">'.$species_defs->other_species($species, "SPECIES_COMMON_NAME").'</option>'."\n";
    }

    $html .= '</optgroup>'."\n" unless $group eq 'no_group';
  }

  $html .= qq(
</select>
</form>
);
  
  $html .= qq(</div>\n);
  return $html;
}

sub render_ajax_reorder_list {
  my ($user, $species_defs, $id_to_species) = @_;
  my %id_to_species = %{ $id_to_species };
  my %species_id = reverse %id_to_species;
  my $html = "";

  $html .= "For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <a href='javascript:void(0);' onClick='toggle_reorder();'>Done</a><br /><br />\n";

  $html .= "<div id='favourite_species'>\n<b>Favourites</b>";
  #warn "CHECKING FOR SPECIES IN AJAX LIST";
  my @specieslists;
  if ($user) {
    @specieslists = @{ $user->specieslists };
  }
  my @favourite_species = ();
  my %favourites = ();
  #warn "FOUND SPECIES LISTS:" . $#specieslists;
  if ($#specieslists < 0) {
    foreach my $name (("Homo_sapiens", "Mus_musculus", "Danio_rerio")) {
      push @favourite_species, $species_id{$name};
    }
  } else {
    my $list = $specieslists[0];
    @favourite_species = split(/,/, $list->favourites); 
  }
  foreach my $id (@favourite_species) {
    $favourites{$id} = 1;
  }

  $html .= "<ul id='favourites_list'>\n";
  foreach my $id (@favourite_species) {
    my $species_name = $id_to_species{$id};
    my $sp_dir = $species_name;
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($sp_dir, 'SPECIES_COMMON_NAME');
    $html .= "<li id='favourite_$id'>$common (<em>" .$species_name."</em>)</li>\n";
  }

  $html .= "</ul></div>\n";
  $html .= "<div id='all_species'>\n<b>Other available species</b>";
  $html .= "<ul id='species_list'>\n";


  my @sorted_by_common = sort {
                          $species_defs->other_species($id_to_species{$a}, "SPECIES_COMMON_NAME")
                          cmp
                          $species_defs->other_species($id_to_species{$b}, "SPECIES_COMMON_NAME")
                          } keys %id_to_species;

  foreach my $id (@sorted_by_common) {
    next if $favourites{$id};
    my $species_name = $id_to_species{$id};
    my $sp_dir = $species_name;
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($sp_dir, 'SPECIES_COMMON_NAME');
    $html .= "<li id='species_$id'>$common (<em>" . $species_name . "</em>)</li>\n";
  }

  $html .= "</ul></div>\n";
  $html .= "<a href='javascript:void(0);' onClick='toggle_reorder();'>Finished reordering</a> &middot; <a href='/common/user/reset_favourites'>Restore default list</a>";
#warn "HTML: $html";

  return $html;
}

}

1;
