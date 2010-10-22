# $Id$

package EnsEMBL::Web::Document::HTML::SpeciesList;

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub new {
  my ($class, $hub) = @_;
  
  my $self = $class->SUPER::new(
    species_defs => $hub->species_defs,
    user         => $hub->user
  );
  
  bless $self, $class;
  
  $self->{'species_info'} = $self->set_species_info;
  
  return $self;
}

sub user         { return $_[0]{'user'};         }
sub species_info { return $_[0]{'species_info'}; }
sub image_type   { return '.png';                }

sub set_species_info {
  my $self         = shift;
  my $species_defs = $self->species_defs;
  
  if (!$self->{'species_info'}) {
    my $species_info = {};

    foreach ($species_defs->valid_species) {
      $species_info->{$_} = {
        name     => $species_defs->get_config($_, 'SPECIES_BIO_NAME',    1),
        common   => $species_defs->get_config($_, 'SPECIES_COMMON_NAME', 1),
        assembly => $species_defs->get_config($_, 'ASSEMBLY_NAME',       1)
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
  my $logins = $self->species_defs->ENSEMBL_LOGINS;
  my $user   = $self->user;
  
  my (%check_faves, @ok_faves);
  
  foreach ($self->get_favourites) {
    push @ok_faves, $_ unless $check_faves{$_}++;
  }
  
  my $count    = @ok_faves;
  my $fav_html = $self->render_favourites($count, \@ok_faves);
  
  return $fav_html if $fragment;
  
  # output list
  my $html = '
    <div class="static_favourite_species">
      <p>';
  
  if ($logins && $user && $count) {
    $html .= '<span style="font-size:1.2em;font-weight:bold">Favourite genomes</span>';
  } else {
    $html .= '<span style="font-size:1.2em;font-weight:bold">Popular genomes</span>';
  }
  
  if ($logins) {
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
  ', $fav_html, $self->render_species_dropdown);
  
  return $html;
}

sub render_favourites {
  my ($self, $count, $ok_faves) = @_;
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
      $self->render_with_images(\@first_half),
      $self->render_with_images($ok_faves)
    );
  } else {
    $html = $self->render_with_images($ok_faves);
  }
  
  return $html;
}

sub render_species_dropdown {
  my $self         = shift; 
  my $species_defs = $self->species_defs;
  my $sitename     = $species_defs->ENSEMBL_SITETYPE;
  my @all_species  = keys %{$self->species_info};
  my $labels       = $species_defs->TAXON_LABEL; ## sort out labels
  my (@group_order, %label_check);
  
  my $html = '
  <form action="#">
    <h3>All genomes</h3>
    <div>
    <select name="species" class="dropdown_redirect">
      <option value="/">-- Select a species --</option>
  ';
  
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
  my $self         = shift;
  my $species_defs = $self->species_defs;
  my @favourites   = $self->get_favourites;
  my @fav_list     = map { sprintf '<li id="favourite-%s">%s (<em>%s</em>)</li>', $_, $species_defs->get_config($_, 'SPECIES_COMMON_NAME'), $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME') } @favourites;
  my %sp_to_sort   = %{$self->species_info};
  
  delete $sp_to_sort{$_} for map s/ /_/, @favourites;
  
  my @sorted       = map { $_->[1] } sort { $a->[0] cmp $b->[0] } map {[ $species_defs->get_config($_, 'SPECIES_COMMON_NAME'), $_ ]} keys %sp_to_sort;
  my @species_list = map { sprintf '<li id="species-%s">%s (<em>%s</em>)</li>', $_, $species_defs->get_config($_, 'SPECIES_COMMON_NAME'), $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME') } @sorted;
  
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

sub get_favourites {
  ## Returns a list of species as Genus_species strings
  my $self          = shift;
  my $species_defs  = $self->species_defs;
  my $user          = $self->user;
  my $species_info  = $self->species_info;
  my @species_lists = $user ? $user->specieslists : ();
  my @favourites    = @species_lists && $species_lists[0] ? map { $species_info->{$_} ? $_ : () } split /,/, $species_lists[0]->favourites : @{$species_defs->DEFAULT_FAVOURITES || []}; # Omit any species not currently online
  @favourites       = ($species_defs->ENSEMBL_PRIMARY_SPECIES, $species_defs->ENSEMBL_SECONDARY_SPECIES) unless scalar @favourites;
  
  return @favourites;
}

sub render_with_images {
  my ($self, $species_list) = @_;
  my $species_defs = $self->species_defs;
  my $species_info = $self->species_info;
  my $html;
  
  foreach (@$species_list) {
    my $common_name  = $species_info->{$_}{'common'} || $species_defs->get_config($_, 'SPECIES_COMMON_NAME')     || '';
    my $species_name = $species_info->{$_}{'name'}   || $species_defs->get_config($_, 'SPECIES_SCIENTIFIC_NAME') || '';
    
    $html .= sprintf('
      <dt>
        <a href="%s/Info/Index">
          <img src="/img/species/thumb_%s%s" alt="%s" title="Browse %s" class="sp-thumb" height="40" width="40" />
          %s
        </a>
      </dt>
      <dd><span class="small normal">%s</span></dd>', 
      $_, $_, $self->image_type, $species_name, $species_name, $common_name, $species_info->{$_}{'assembly'}
    );
  }
  
  return qq{
    <dl class="species-list">
      $html
    </dl>
  };
}

1;
