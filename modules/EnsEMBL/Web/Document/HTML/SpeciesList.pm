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

  foreach my $key (keys %id_to_species) {
    warn "KEY: " . $key;
  }
  my %species_description = setup_species_descriptions($species_defs);

  my $reg_user = $EnsEMBL::Web::RegObj::ENSEMBL_WEB_REGISTRY->get_user;
  my $user = EnsEMBL::Web::Object::Data::User->new({ id => $reg_user->id });

  my $html = "";
  warn "RENDERING CUSTOM SPECIES LIST WITH USER: " . $user->id;
  if ($request && $request eq 'fragment') {
    $html .= render_species_list($user, $species_defs, \%id_to_species, \%species_description); 
  } else {
    warn "REORDER LIST"; 
    $html .= "<div id='reorder_species' style='display: none;'>\n";
    $html .= render_ajax_reorder_list($user, $species_defs, \%id_to_species); 
    $html .= "</div>\n";
    warn "FULL LIST";
    $html .= "<div id='full_species'>\n";
    $html .= render_species_list($user, $species_defs, \%id_to_species, \%species_description); 
    $html .= "</div>\n";
    if ($species_defs->ENSEMBL_LOGINS && !$user->name) {
      $html .= "<div id='login_message'>";
      $html .= "<a href='javascript:login_link()'>Log in</a> to customise this list &middot; <a href='/common/register'>Register</a>";
      $html .= "</div>\n";
    }
  }
  warn "RETURNING HTML";
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

sub check_lists {
  my ($favourite_species, $species_list, $id_to_species) = @_;
  my @temp;
  my $ok = 0;
  foreach my $sp_id (keys %$id_to_species) {
    foreach my $id ((@$favourite_species, @$species_list)) {
      if ($id == $sp_id) {
        $ok = 1;
        last;
      }
    }
    push @temp, $sp_id if !$ok;
  }
  if (scalar(@temp) > 0) {
    unshift(@$species_list, @temp);
  }

  return $species_list;
}

sub render_species_list {
  my ($user, $species_defs, $id_to_species, $species_description) = @_;
  my %description = %{ $species_description };
  my %id_to_species = %{ $id_to_species };
  my %species_id = reverse %id_to_species;
  warn "RENDERING";
  my @specieslists = @{ $user->specieslists };
  warn "FOUND: SPECIES: ". $#specieslists;
  my %favourites = ();
  my @favourite_species = ();
  my @species_list = ();
  my $html = "";

  if ($#specieslists < 0) {
    foreach my $name (("Homo_sapiens", "Mus_musculus", "Danio_rerio")) {
      push @favourite_species, $species_id{$name};
    }
    my @name_order = sort {$a cmp $b} values %id_to_species;
    foreach my $name (@name_order) {
      unless ($name =~ /Homo_sapiens|Mus_musculus|Danio_rerio/) {
        push (@species_list, $species_id{$name});
      }
    }
  } else {
    my $list = $specieslists[0];
    @favourite_species = split(/,/, $list->favourites); 
    @species_list = split(/,/, $list->list); 
  }

  ## check lists for new or deleted species
  @species_list = @{check_lists(\@favourite_species, \@species_list, \%id_to_species)};

  ## output list
  if (!$user->name) {
    $html .= "<b>Popular genomes</b><br />\n";
  } else {
    $html .= "<b>Popular genomes</b> &middot; \n";
    $html .= "<a href='javascript:void(0);' onClick='toggle_reorder();'>Reorder</a>";
  }
  $html .= "<div id='static_favourite_species'>\n";
  $html .= "<div class='favourites-species-list'>\n";
  $html .= "<dl class='species-list'>\n";
  foreach my $id (@favourite_species) {
    $favourites{$id} = 1;
    my $species_filename = $id_to_species{$id};
    my $species_name = $species_filename;
    $species_name =~ s/_/ /g;
    $html .= "<dt class='species-list'><a href='/$species_filename/'><img src='/img/species/thumb_$species_filename.png' alt='$species_name' title='Browse $species_name' class='sp-thumb' height='40' width='40' /></a><a href='/$species_filename/'>$species_name</a></dt>\n";
    $html .= "<dd>" . $description{$species_name}[0] . "</dd>\n";
  }
  $html .= "</dl>\n";
  $html .= "</div>\n";
  $html .= "</div>\n";

  if (!$user->name) {
    $html .= "<b>More genomes</b><br />\n";
  } else {
    $html .= "<b>More genomes</b> &middot; \n";
    $html .= "<a href='javascript:void(0);' onClick='toggle_reorder();'>Reorder</a>";
  }
  $html .= "<div id='static_all_species'>\n";
  $html .= "<ul class='species-list spaced'>\n";

  foreach my $id (@species_list) {
    my $species_filename = $id_to_species{$id};
    my $species_name = $species_filename;
    $species_name =~ s/_/ /g;
    if (!$favourites{$id}) {
      $html .= "<li><span class='sp'><a href='/$species_filename/'>$species_name</a></span>".$description{$species_name}[1]."</li>\n";
      $favourites{$id} = 1;
    }
  }
  $html .= "</ul>\n";
  $html .= "Other pre-build species are available in <a href='#top' onclick='show_pre();'>Ensembl Pre! &rarr;</a>";
  $html .= "</div>\n";
  return $html;
}

sub render_ajax_reorder_list {
  my ($user, $species_defs, $id_to_species) = @_;
  my %id_to_species = %{ $id_to_species };
  my %species_id = reverse %id_to_species;
  my $html = "";


  $html .= "<b>Drag and drop species names to reorder this list</b> &middot; <a href='javascript:void(0);' onClick='toggle_reorder();'>Done</a><br /><br />\n";
  $html .= "Hint: For easy access to commonly used genomes, drag from the bottom list to the top one.";

  $html .= "<div id='favourite_species'>\n";
  warn "CHECKING FOR SPECIES IN AJAX LIST";
  my @specieslists = @{ $user->specieslists };
  my %favourites = ();
  my @favourite_species = ();
  my @species_list = ();
  warn "FOUND SPECIES LISTS:" . $#specieslists;
  if ($#specieslists < 0) {
    foreach my $name (("Homo_sapiens", "Mus_musculus", "Danio_rerio")) {
      push @favourite_species, $species_id{$name};
    }
    my @name_order = sort {$a cmp $b} values %id_to_species;
    foreach my $name (@name_order) {
      unless ($name =~ /Homo_sapiens|Mus_musculus|Danio_rerio/) {
        push (@species_list, $species_id{$name});
      }
    }
  } else {
    my $list = $specieslists[0];
    @favourite_species = split(/,/, $list->favourites); 
    @species_list = split(/,/, $list->list); 
  }

  ## check lists for new or deleted species
  @species_list = @{check_lists(\@favourite_species, \@species_list, \%id_to_species)};

  $html .= "<ul id='favourites_list'>\n";
  foreach my $id (@favourite_species) {
    my $species_name = $id_to_species{$id};
    $favourites{$id} = 1;
    my $sp_dir = $species_name;
    $species_name =~ s/_/ /;
    my $common = $species_defs->get_config($sp_dir, 'SPECIES_DESCRIPTION');
    $html .= "<li id='favourite_$id'><em>" .$species_name.'</em>';
    if ($common) {
      $html .= " ($common)";
    }
    $html .= "</li>\n";
  }

  $html .= "</ul></div>\n";
  $html .= "<div id='all_species'>\n";
  $html .= "<ul id='species_list'>\n";
  foreach my $id (@species_list) {
    my $species_name = $id_to_species{$id};
    if (!$favourites{$id}) {
      my $sp_dir = $species_name;
      $species_name =~ s/_/ /;
      my $common = $species_defs->get_config($sp_dir, 'SPECIES_DESCRIPTION');
      $html .= "<li id='species_$id'><em>" . $species_name . '</em>'; 
      if ($common) {
        $html .= " ($common)";
      }
      $html .= "</li>\n";
      $favourites{$id} = 1;
    }
  }

  ## Catch any species not yet displayed
  foreach my $id (keys %id_to_species) {
    my $species_name = $id_to_species{$id};
    if (!$favourites{$id}) {
      $species_name =~ s/_/ /;
      $html .= "<li id='species_$id'>" . $species_name . "</li>\n"; 
    }
  }

  $html .= "</ul></div>\n";
  $html .= "<a href='javascript:void(0);' onClick='toggle_reorder();'>Finished reordering</a> &middot; <a href='/common/user/reset_favourites'>Restore default list</a>";

  return $html;
}

sub species_html {
  my ($species, $prefix) = @_;
  my $html = "";
  return $html;
}

}

1;
