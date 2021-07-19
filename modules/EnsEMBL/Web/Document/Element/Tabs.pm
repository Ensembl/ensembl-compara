=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Document::Element::Tabs;

# Generates the global context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::Element);

sub new {
  return shift->SUPER::new({
    %{$_[0]},
    active       => undef,
    entries      => [],
    history      => {},
    bookmarks    => {},
    species_list => [],
  });
}

sub entries { return $_[0]->{'entries'}; }

sub active {
  my $self = shift;
  $self->{'active'} = shift if @_;
  return $self->{'active'};
}

sub add_entry { push @{shift->{'entries'}}, @_; }

sub init_history {} # stub for users plugin

sub init {
  my $self          = shift;
  my $controller    = shift;
  my $builder       = $controller->builder;
  my $object        = $controller->object;
  my $configuration = $controller->configuration;
  my $hub           = $controller->hub;
  my $type          = $hub->type;
  my $species_defs  = $hub->species_defs;  
  my @data;

  foreach (@{$hub->ordered_objects}) {
    my $o = $builder->object($_);
    push @data, { type => $_, action => $o->default_action, caption => $o->short_caption('global'), dropdown => !!($self->{'history'}{lc $_} || $self->{'bookmarks'}{lc $_} || $_ eq 'Location') } if $o;
  }
 
  push @data, { type => $object->type,        action => $object->default_action,        caption => $object->short_caption('global')       } if $object && !@data;
  push @data, { type => $configuration->type, action => $configuration->default_action, caption => $configuration->{'_data'}->{'default'} } if $type eq 'Location' && !@data;
 
  foreach my $row (@data) {
    next if $row->{'type'} eq 'Location' && $type eq 'LRG';
    
    my $class = $row->{'class'} || lc $row->{'type'};
    
    $self->add_entry({
      type     => $row->{'type'}, 
      caption  => $row->{'caption'},
      url      => $hub->url({ type => $row->{'type'}, action => $row->{'action'} }),
      class    => $class . ($row->{'type'} eq $type ? ' active' : ''),
      dropdown => $row->{'dropdown'} ? $class : '',
      disabled => $row->{'disabled'}
    });
  }
}

sub content {
  my $self  = shift;
  my $hub   = $self->hub;
  my $count = scalar @{$self->entries};
  
  return '' unless $count;
  
  my ($content, $short_tabs, $long_tabs);
  my $static  = $self->isa('EnsEMBL::Web::Document::Element::StaticTabs');
  my @style   = $count > 4 && !$static ? () : (' style="display:none"', ' style="display:block"');
  my $history = 0;

  $self->init_history($hub) if $hub->user;

  foreach my $entry (@{$self->entries}) {
    $entry->{'url'} ||= '#';
    
    my $name         = encode_entities($self->strip_HTML($entry->{'caption'}));
    my ($short_name) = split /\b/, $name;
    my $constant     = $entry->{'constant'} ? ' class="constant"' : '';
    my $url = encode_entities($entry->{'url'});
    my $short_link   = qq(<a href="$url" title="$name"$constant>$short_name</a>);
    my $long_link    = qq(<a href="$url"$constant>$name</a>);
    
    if ($entry->{'disabled'}) {
      my $span = $entry->{'dropdown'} ? qq(<span class="disabled toggle" title="$entry->{'dropdown'}">) : '<span class="disabled">';
      $_ = qq{$span$name</span>} for $short_link, $long_link;
    }
    
    if ($entry->{'dropdown'}) {
      # Location tab always has a dropdown because its history can be changed dynamically by the slider navigation.
      # Hide the toggle arrow if there are no bookmarks or history items for it.
      my @hide = $entry->{'type'} eq 'Location' && !($self->{'history'}{'location'} || $self->{'bookmarks'}{'location'}) ? (' empty', ' style="display:none"') : ();
      $history = 1;
      $_       = qq(<span class="dropdown$hide[0]">$_<a class="toggle" href="#" rel="$entry->{'dropdown'}"$hide[1]>&#9660;</a></span>) for $short_link, $long_link;
    }
    
    $short_tabs .= qq(<li class="$entry->{'class'} short_tab"$style[0]>$short_link</li>);
    $long_tabs  .= qq(<li class="$entry->{'class'} long_tab"$style[1]>$long_link</li>);
  }
  
  $content  = $short_tabs . $long_tabs;
  $content  = qq{<ul class="tabs">$content</ul>} if $content;
  $content .= join '', values %{$self->dropdown} if $history;
  
  return $content;
}

sub dropdown {
  my $self = shift;
  my %html;
  
  foreach my $type (grep scalar @{$self->{'history'}->{$_}}, keys %{$self->{'history'}}) {
    my $history  = join '', map sprintf('<li><a href="%s" class="constant %s">%s</a></li>', $_->[0], $_->[2], encode_entities($_->[1])), @{$self->{'history'}->{$type}};
    $html{$type} = qq{<h4>Recent ${type}s</h4><ul class="recent">$history</ul>};
  }
  
  foreach my $type (grep scalar @{$self->{'bookmarks'}->{$_}}, keys %{$self->{'bookmarks'}}) {
    my $bookmarks = join '', map sprintf('<li><a href="%s" class="constant %s">%s</a></li>', $_->[0], $_->[2], encode_entities($_->[1])), @{$self->{'bookmarks'}->{$type}};
    $html{$type} .= sprintf qq{<h4>%s bookmarks</h4><ul class="bookmarks">$bookmarks</ul>}, ucfirst $type;
  }
  
  $html{$_} = qq(<div class="dropdown history $_">$html{$_}</div>) for keys %html;
  
  $html{'location'} ||= '
    <div class="dropdown history location">
      <h4>Recent locations</h4>
      <ul class="recent"><li><a class="constant clear_history bold" href="/Account/ClearHistory?object=Location">Clear history</a></li></ul>
    </div>';
  
  return \%html;
}

1;
