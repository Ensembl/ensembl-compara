# $Id$

package EnsEMBL::Web::ImageConfig::MultiSpecies;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

## Container for multiple species image configs. Data is stored in the database as follows:
## {
##   Homo_sapiens  => {'contig'   => {'display' => 'off'}}
##   Gallus_gallus => {'scalebar' => {'display' => 'off'}}
##   Multi         => {...}
## }
##
## When calling get_imageconfig with species as 3rd parameter, it behaves like a normal image config for that species.
## When calling get_imageconfig without species, the all_species flag is set. It is then possible to set/get user data on all species.
## This is used when saving configurations, in order to stop settings being lost from the species that is not currently being configured.

sub new {
  my $class   = shift;
  my $hub     = shift;
  my $species = shift;
  my $self    = $class->SUPER::new($hub, $species || $hub->species, @_);
  
  $self->{'all_species'} = !$species;
  
  return $self;
}

sub multi_species { return 1; }

sub species_list {
  my $self = shift;
  
  if (!$self->{'species_list'}) {
    my $species_defs = $self->species_defs;
    my $referer      = $self->hub->referer;
    my $params       = $referer->{'params'};
    
    $self->{'species_list'} = [ map [ $_, $species_defs->SPECIES_COMMON_NAME($_) ], $referer->{'ENSEMBL_SPECIES'}, map $params->{"s$_"}->[0], sort { $a <=> $b } map { /^s(\d+)$/ ? $1 : () } keys %$params ];
  }
  
  return $self->{'species_list'};
}


sub get_user_settings {
  my $self     = shift;
  my $settings = $self->tree->user_data;
  
  if ($self->{'all_species'}) {
    my $species = $self->species;
    $self->{'user_settings'}{$species} = { %{$self->{'user_settings'}{$species} || {}}, %$settings };
    delete $self->{'user_settings'}{$species} unless scalar keys %{$self->{'user_settings'}{$species}};
    return $self->{'user_settings'};
  } else {
    return $settings;
  }
}

# applying session data to IC
sub set_user_settings {
  my ($self, $settings) = @_;
  
  if ($self->{'all_species'}) {
    $self->{'user_settings'} = $settings;
  } else {
    $self->SUPER::set_user_settings($settings->{$self->species} || {});
  }
}

sub update_track_renderer {
  my ($self, $key, $renderer, $on_off) = @_;
  my $node = $self->get_node($key);
  
  return unless $node;
  
  my %valid_renderers = @{$node->data->{'renderers'}};
  my $flag            = 0;

  # if $on_off == 1, only allow track enabling/disabling. Don't allow enabled tracks' renderer to be changed.
  $flag += $node->set_user('display', $renderer) if $valid_renderers{$renderer} && (!$on_off || $renderer eq 'off' || $node->get('display') eq 'off');
  
  $self->altered = 1 if $flag;
  
  delete $self->{'user_settings'}{$self->species}{$key} if $flag && !$node->user_data->{$key};
}

sub update_track_order {
  my ($self, $diff) = @_;
  
  if ($self->{'all_species'}) {
    my $species = $self->species;
    my $order   = $self->{'user_settings'}{$species}{'track_order'}{$species} || {};
    
    $self->{'user_settings'}{$species}{'track_order'}{$species} = { %$order, %{$diff->{'track_order'}} };
    $self->altered = 1;
    
    return $self->get_parameter('sortable_tracks') ne 'drag';
  } else {
    return $self->SUPER::update_track_order($diff);
  }
}

sub reset {
  my $self = shift;
  
  if ($self->{'all_species'}) {
    my $species = $self->species;
    
    if ($self->hub->input->param('reset') eq 'track_order') {
      my $node = $self->get_node('track_order');
      
      if ($self->{'user_settings'}{$species}{'track_order'}) {
        $self->altered = 1;
        delete $self->{'user_settings'}{$species}{'track_order'};
      }
    } else {
      my $user_data = $self->{'user_settings'}{$species};
      
      foreach (keys %$user_data) {
        $self->altered = 1 if $user_data->{$_}{'display'};
        delete $user_data->{$_}{'display'};
        delete $user_data->{$_} unless scalar keys %{$user_data->{$_}};
      }
    }
  } else {
    $self->SUPER::reset;
  }
}

1;