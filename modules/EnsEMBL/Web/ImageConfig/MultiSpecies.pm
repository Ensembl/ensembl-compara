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

package EnsEMBL::Web::ImageConfig::MultiSpecies;

use strict;

use base qw(EnsEMBL::Web::ImageConfig);

## Container for multiple species image configs. Data is stored in the database as follows:
## {
##   Homo_sapiens  => { contig   => { display => 'off' }}
##   Gallus_gallus => { scalebar => { display => 'off' }}
##   Multi         => { ... }
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
    my %seen;
    my @species = grep !$seen{$_}++, $referer->{'ENSEMBL_SPECIES'}, map [ split '--', $params->{"s$_"}[0] ]->[0], sort { $a <=> $b } map { /^s(\d+)$/ ? $1 : () } keys %$params;
    
    $self->{'species_list'} = [ map [ $_, $species_defs->SPECIES_COMMON_NAME($_) ], @species ];
  }
  
  return $self->{'species_list'};
}

sub get_user_settings {
  my $self     = shift;
  my $settings = $self->tree->user_data;
  
  if ($self->{'all_species'}) {
    my $species = $self->species;
    $self->{'user_settings'}{$species} = { %{$self->{'user_settings'}{$species} || {}}, %$settings };
    delete $self->{'user_settings'}{$species}{'track_order'} unless scalar keys %{$self->{'user_settings'}{$species}{'track_order'}};
    delete $self->{'user_settings'}{$species}                unless scalar keys %{$self->{'user_settings'}{$species}};
    return $self->{'user_settings'};
  } else {
    delete $settings->{'track_order'} unless scalar keys %{$settings->{'track_order'}};
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
 
  my $text = $node->data->{'name'} || $node->data->{'coption'}; 
  $self->altered($text) if $flag;
  
  delete $self->{'user_settings'}{$self->species}{$key} if $flag && !$node->user_data->{$key};
}

sub update_track_order {
  my ($self, $diff) = @_;
  
  if ($self->{'all_species'}) {
    my $species = $self->species;
    my $order   = $self->{'user_settings'}{$species}{'track_order'}{$species} || {};
    
    $self->{'user_settings'}{$species}{'track_order'}{$species} = { %$order, %{$diff->{'track_order'}} };
    $self->altered('Track order');
    
    return $self->get_parameter('sortable_tracks') ne 'drag';
  } else {
    return $self->SUPER::update_track_order($diff);
  }
}

sub reset {
  my $self = shift;
  
  if ($self->{'all_species'}) {
    my $species = $self->species;
    my $reset   = $self->hub->input->param('reset');
    my ($tracks, $order) = $reset eq 'all' ? (1, 1) : $reset eq 'track_order' ? (0, 1) : (1, 0);
    
    if ($tracks) {
      my $user_data = $self->{'user_settings'}{$species};
      
      foreach (keys %$user_data) {
        $self->altered($_) if $user_data->{$_}{'display'};
        delete $user_data->{$_}{'display'};
        delete $user_data->{$_} unless scalar keys %{$user_data->{$_}};
      }
    }
    
    if ($order) {
      my $node = $self->get_node('track_order');
      
      if ($self->{'user_settings'}{$species}{'track_order'}) {
        $self->altered('Track order');
        delete $self->{'user_settings'}{$species}{'track_order'};
      }
    }
  } else {
    $self->SUPER::reset(@_);
  }
}

sub share {
  my ($self, %shared_custom_tracks) = @_;
  
  if ($self->{'all_species'}) {
    my $hub = $self->hub;
    return { map { $_ => $hub->get_imageconfig($self->{'type'}, $_ . 'share', $_)->share(%shared_custom_tracks) } keys %{$self->get_user_settings} };
  } else {
    return $self->SUPER::share(%shared_custom_tracks);
  }
}

1;
