package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;
use warnings;

use EnsEMBL::Web::Object::User;
use EnsEMBL::Web::SpeciesDefs;

{

sub render {
  my ($class, $request) = @_;

  my $species_defs = EnsEMBL::Web::SpeciesDefs->new();
  my %species_id = ();
  my %id_to_species = ();
  my $count = 0;

  foreach my $species (sort $species_defs->valid_species) {
    $count++; 
    $species =~ s/_/ /g;
    $species_id{$species} = $count;
    $id_to_species{$count} = $species;
  }
  
  my %species_description = setup_species_descriptions();

  my $user = EnsEMBL::Web::Object::User->new({ id => $ENV{'ENSEMBL_USER_ID'} });
  my $html = "";
  if ($request eq 'fragment') {
    $html .= render_species_list($user, $species_defs, \%id_to_species, \%species_id, \%species_description); 
  } else {
    
    $html .= "<div id='reorder_species' style='display: none;'>\n";
    $html .= render_ajax_reorder_list($user, $species_defs, \%id_to_species, \%species_id); 
    $html .= "</div>\n";

    $html .= "<div id='full_species'>\n";
    $html .= render_species_list($user, $species_defs, \%id_to_species, \%species_id, \%species_description); 
    $html .= "</div>\n";
    if (!$user->name) {
      $html .= "<div id='login_message'>";
      $html .= "<a href='javascript:login_link()'>Log in</a> to customise this list &middot; <a href='/common/register'>Register</a>";
      $html .= "</div>\n";
    }
  }

  return $html;

}

sub setup_species_descriptions {
  my %description = ();
  $description{'Homo sapiens'} = qq(<span class="small normal">NCBI&nbsp;36</span><span class="small normal"> | <a href="http://vega.sanger.ac.uk/Homo_sapiens/">Vega</a>);
  $description{'Mus musculus'} = qq(<span class="small normal">NCBI&nbsp;m36</span><span class="small normal"> | <a href="http://vega.sanger.ac.uk/Mus_musculus/">Vega</a>);
  $description{'Danio rerio'} = qq(<span class="small normal">Zv&nbsp;6</span><span class="small normal"> | <a href="http://vega.sanger.ac.uk/Danio_rerio/">Vega</a>);
  return %description;
}

sub render_species_list {
  my ($user, $species_defs, $id_to_species, $species_id, $species_description) = @_;
  my %description = %{ $species_description };
  my %id_to_species = %{ $id_to_species };
  my %species_id = %{ $species_id };
  my ($species) = $user->species_records;
  my %favourites = ();
  my @favourite_species = ();
  my @species_list = ();
  my $html = "";

  if (!$species) {
    foreach my $name (("Homo sapiens", "Mus musculus", "Danio rerio")) {
      push @favourite_species, $species_id{$name};
    }
    @species_list = sort {$a <=> $b} keys %id_to_species;
  } else {
    @favourite_species = split(/,/, $species->favourites); 
    @species_list = split(/,/, $species->list); 
  }

  if (!$user->name) {
    $html .= "<b>Popular genomes</b><br />\n";
  } else {
    $html .= "<b>Popular genomes</b> &middot; \n";
    $html .= "<a href='javascript:void(0);' onClick='toggle_reorder();'>Reorder</a>";
  }

  $html .= "<div id='static_favourite_species'>\n";
  $html .= "<ul class='favourites-species-list'>\n";
  $html .= "<dl class='species-list'>\n";
  foreach my $id (@favourite_species) {
    $favourites{$id} = 1;
    my $species_name = $id_to_species{$id};
    my $species_filename = $species_name;
    $species_filename =~ s/ /_/g;
    $html .= "<dt class='species-list'><a href='/$species_filename/'><img src='/img/species/thumb_$species_filename.png' alt='$species_name' title='Browse $species_name' class='sp-thumb' height='40' width='40' /></a><a href='/$species_filename/'>$species_name</a></dt>\n";
    $html .= "<dd>" . $description{$species_name} . "</dd>\n";
  }
  $html .= "</dl>\n";
  $html .= "</ul>\n";
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
    my $species_name = $id_to_species{$id};
    my $species_filename = $species_name;
    $species_filename =~ s/ /_/g;
    if (!$favourites{$id}) {
      $html .= "<li><span class='sp'><a href='/$species_filename/'>$species_name</a></span><span class='small normal'> </span></li>\n";
      $favourites{$id} = 1;
    }
  }
  $html .= "</ul>\n";
  $html .= "</div>\n";
  return $html;
}

sub render_ajax_reorder_list {
  my ($user, $species_defs, $id_to_species, $species_id) = @_;
  my %id_to_species = %{ $id_to_species };
  my %species_id = %{ $species_id };
  my $html = "";


  $html .= "<b>Drag and drop species names to reorder this list</b> &middot; <a href='javascript:void(0);' onClick='toggle_reorder();'>Done</a><br /><br />\n";
  $html .= "Hint: For easy access to commonly used genomes, drag from the bottom list to the top one.";

  $html .= "<div id='favourite_species'>\n";

  my ($species) = $user->species_records;
  my %favourites = ();
  my @favourite_species = ();
  my @species_list = ();

  if (!$species) {
    foreach my $name (("Homo sapiens", "Mus musculus", "Danio rerio")) {
      push @favourite_species, $species_id{$name};
    }
    @species_list = sort keys %id_to_species;
  } else {
    @favourite_species = split(/,/, $species->favourites); 
    @species_list = split(/,/, $species->list); 
  }


  $html .= "<ul id='favourites_list'>\n";
  foreach my $species (@favourite_species) {
    $species = $id_to_species{$species};
    $favourites{$species} = 1;
    $html .= "<li id='favourite_" . $species_id{$species} . "'>$species</li>\n";
  }

  $html .= "</ul></div>\n";
  $html .= "<div id='all_species'>\n";
  $html .= "<ul id='species_list'>\n";
  foreach my $species (@species_list) {
    $species = $id_to_species{$species};
    if (!$favourites{$species}) {
      $html .= "<li id='species_" . $species_id{$species} . "'>" . $species . "</li>\n"; 
      $favourites{$species} = 1;
    }
  }

  ## Catch any species not yet displayed
  foreach my $species ($species_defs->valid_species) {
    $species =~ s/_/ /;
    if (!$favourites{$species}) {
      $html .= "<li id='species_" . $species_id{$species} . "'>" . $species . "</li>\n"; 
    }
  }

  $html .= "</ul></div>\n";
  $html .= "<a href='javascript:void(0);' onClick='toggle_reorder();'>Finished reordering</a> &middot; <a href='/common/reset_favourites'>Restore default list</a>";

  return $html;
}

sub species_html {
  my ($species, $prefix) = @_;
  my $html = "";
  return $html;
}

}

1;
