# $Id$

package EnsEMBL::Web::Document::HTML::FavouriteSpecies;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub new {
  my ($class, $hub) = @_;
  
  my $self = $class->SUPER::new(
    species_defs => $hub->species_defs,
    user         => $hub->user,
    favourites   => $hub->get_favourite_species
  );
  
  bless $self, $class;
  
  $self->{'species_info'} = $self->set_species_info;
  
  return $self;
}

sub user         { return $_[0]{'user'};         }
sub species_info { return $_[0]{'species_info'}; }
sub favourites   { return $_[0]{'favourites'};   }
sub image_type   { return '.png';                }

sub set_species_info {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  
  if (!$self->{'species_info'}) {
    my $species_info = {};

    foreach ($species_defs->valid_species) {
      $species_info->{$_} = {
        key        => $_,
        name       => $species_defs->get_config($_, 'SPECIES_BIO_NAME'),
        common     => $species_defs->get_config($_, 'SPECIES_COMMON_NAME'),
        scientific => $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME'),
        assembly   => $species_defs->get_config($_, 'ASSEMBLY_NAME')
      };
    }

    # give the possibility to add extra info to $species_info via the function
    $self->modify_species_info($species_info);
    
    $self->{'species_info'} = $species_info;
  }
  
  return $self->{'species_info'};
}

sub modify_species_info {}

sub render {
  my $self      = shift;
  my $fragment  = shift eq 'fragment';
  my $full_list = $self->render_species_list($fragment);
  
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
  ', $self->render_ajax_reorder_list, $full_list);

  return $html;
}

sub render_species_list {
  my ($self, $fragment) = @_;
  my $logins       = $self->species_defs->ENSEMBL_LOGINS;
  my $user         = $self->user;
  my $species_info = $self->species_info;
  
  my (%check_faves, @ok_faves);
  
  foreach (@{$self->favourites}) {
    push @ok_faves, $species_info->{$_} unless $check_faves{$_}++;
  }
  
  my $fav_html = $self->render_with_images(@ok_faves);
  
  return $fav_html if $fragment;
  
  # output list
  my $html = '
    <div class="static_favourite_species">';
  
  if ($logins && $user && scalar(@ok_faves)) {
    $html .= '<h3 class="box-header">Favourite genomes</h3>';
  } else {
    $html .= '<h3 class="box-header">Popular genomes</h3>';
  }
  
  if ($logins) {
    if ($user) {
      $html .= '(<span class="link toggle_link">Change favourites</span>)';
    } else {
      $html .= '(<a href="/Account/Login" class="modal_link modal_title_Login/Register">Log in to customize this list</a>)';
    }
  }
  
  $html .= sprintf('
      <div class="species_list_container">%s</div>
    </div>
  ', $fav_html);
  
  return $html;
}

sub render_ajax_reorder_list {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my $favourites   = $self->favourites;
  my %species_info = %{$self->species_info};
  my @fav_list     = map qq{<li id="favourite-$_->{'key'}">$_->{'common'} (<em>$_->{'scientific'}</em>)</li>}, map $species_info{$_}, @$favourites;
  
  delete $species_info{$_} for @$favourites;
  
  my @sorted       = sort { $a->{'common'} cmp $b->{'common'} } values %species_info;
  my @species_list = map qq{<li id="species-$_->{'key'}">$_->{'common'} (<em>$_->{'scientific'}</em>)</li>}, @sorted;
  
  return sprintf('
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
  ', join("\n", @fav_list), join("\n", @species_list));
}

sub render_with_images {
  my ($self, @species_list) = @_;
  my $species_defs  = $self->species_defs;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;
  my $image_type    = $self->image_type;
  my $html;
  
  foreach (@species_list) {
    $html .= qq{
      <dt>
        <a href="$_->{'key'}/Info/Index">
          <img src="$static_server/img/species/thumb_$_->{'key'}$image_type" alt="$_->{'name'}" title="Browse $_->{'name'}" class="sp-thumb" height="40" width="40" />
          $_->{'common'}
        </a>
      </dt>
      <dd><span class="small normal">$_->{'assembly'}</span></dd>
    };
  }
  
  return qq{
    <dl class="species-list">
      $html
    </dl>
  };
}

1;
