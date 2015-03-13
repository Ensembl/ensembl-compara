=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Document::HTML::FavouriteSpecies;

use strict;

use base qw(EnsEMBL::Web::Document::HTML);

sub render {
  my $self      = shift;
  my $fragment  = shift eq 'fragment';
  my $full_list = $self->render_species_list($fragment);
  
  my $html = $fragment ? $full_list : sprintf('
      <div class="reorder_species" style="display: none;">
         %s
      </div>
      <div class="full_species">
        %s 
      </div>
  ', $self->render_ajax_reorder_list, $full_list);


  #warn $html;

  return $html;
}

sub render_species_list {
  my ($self, $fragment) = @_;
  my $hub           = $self->hub;
  my $logins        = $hub->users_available;
  my $user          = $hub->user;
  my $species_info  = $hub->get_species_info;
  
  my (%check_faves, @ok_faves);
  
  foreach (@{$hub->get_favourite_species}) {
    push @ok_faves, $species_info->{$_} unless $check_faves{$_}++;
  }
  
  my $fav_html = $self->render_with_images(@ok_faves);
  
  return $fav_html if $fragment;
  
  # output list
  my $star = '<img src="/i/16/star.png" style="vertical-align:middle;margin-right:4px" />';
  my $html = sprintf qq{<div class="static_favourite_species"><h3>%s genomes</h3><div class="species_list_container species-list">$fav_html</div>%s</div>}, 
    $logins && $user && scalar(@ok_faves) ? 'Favourite' : 'Popular',
    $logins
      ? sprintf('<p class="customise-species-list">%s</p>', $user
        ? qq(<span class="link toggle_link">${star}Change favourites</span>)
        : qq(<a href="/Account/Login" class="modal_link modal_title_Login/Register">${star}Log in to customize this list</a>)
      )
    : ''
  ;

  return $html;
}

sub render_ajax_reorder_list {
  my $self          = shift;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $favourites    = $hub->get_favourite_species;
  my %species_info  = %{$hub->get_species_info};
  my @fav_list      = map qq\<li id="favourite-$_->{'key'}">$_->{'common'} (<em>$_->{'scientific'}</em>)</li>\, map $species_info{$_}, @$favourites;
  
  delete $species_info{$_} for @$favourites;
  
  my @sorted       = sort { $a->{'common'} cmp $b->{'common'} } values %species_info;
  my @species_list = map qq\<li id="species-$_->{'key'}">$_->{'common'} (<em>$_->{'scientific'}</em>)</li>\, @sorted;
  
  return sprintf('
    <p>For easy access to commonly used genomes, drag from the bottom list to the top one &middot; <span class="link toggle_link">Save</span></p>
    <p><strong>Favourites</strong></p>
    <ul class="favourites list">
      %s
    </ul>
    <p><strong>Other available species</strong></p>
    <ul class="species list">
      %s
    </ul>
    <p><span class="link toggle_link">Save selection</span> &middot; <a href="/Account/Favourites/Reset">Restore default list</a></p>
  ', join("\n", @fav_list), join("\n", @species_list));
}

sub render_with_images {
  my ($self, @species_list) = @_;
  my $hub           = $self->hub;
  my $species_defs  = $hub->species_defs;
  my $static_server = $species_defs->ENSEMBL_STATIC_SERVER;
  my $html;

  foreach (@species_list) {
    $html .= qq(
      <div class="species-box">
        <a href="$_->{'key'}/Info/Index">
          <span class="sp-img"><img src="$static_server/i/species/48/$_->{'key'}.png" alt="$_->{'name'}" title="Browse $_->{'name'}" height="48" width="48" /></span>
          <span>$_->{'common'}</span>
        </a>
        <span>$_->{'assembly'}</span>
      </div>
    );
  }

  return $html;
}

1;
