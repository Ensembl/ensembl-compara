# $Id$

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

sub entries :lvalue { $_[0]->{'entries'}; }
sub active  :lvalue { $_[0]->{'active'};  }
sub add_entry       { push @{shift->{'entries'}}, @_; }

sub init {
  my $self          = shift;
  my $controller    = shift;
  my $builder       = $controller->builder;
  my $object        = $controller->object;
  my $configuration = $controller->configuration;
  my $hub           = $controller->hub;
  my $type          = $hub->type;
  my $species_defs  = $hub->species_defs;  
  my @data          = ($species_defs->valid_species($hub->species) ? {
    class    => 'species',
    type     => 'Info',
    action   => 'Index',
    caption  => sprintf('%s (%s)', $species_defs->SPECIES_COMMON_NAME, $species_defs->ASSEMBLY_NAME),
    dropdown => 1
  } : {
    class    => 'species',
    caption  => 'Species',
    disabled => 1,
    dropdown => 1
  });
  
  $self->init_history($hub, $builder) if $hub->user;
  $self->init_species_list($hub);
  
  foreach (@{$builder->ordered_objects}) {
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

sub init_species_list {
  my ($self, $hub) = @_;
  my $species      = $hub->species;
  my $species_defs = $hub->species_defs;
  
  $self->{'species_list'} = [ 
    sort { $a->[1] cmp $b->[1] } 
    map  { $_ eq $species ? () : [ $hub->url({ species => $_, type => 'Info', action => 'Index', __clear => 1 }), $species_defs->get_config($_, 'SPECIES_COMMON_NAME') ]}
    $species_defs->valid_species
  ];
}

sub init_history {
  my ($self, $hub, $builder) = @_;
  my $user         = $hub->user;
  my $species_defs = $hub->species_defs;
  my $type         = $hub->type;
  my $species      = $hub->species;
  my $servername   = $species_defs->ENSEMBL_SERVERNAME;
  my (%history, %bookmarks);
  
  push @{$history{$_->{'object'}}},   $_ for grep $_->{'object'} && $builder->object($_->{'object'}) && $_->{'url'} =~ /$servername/, $user->histories;
  push @{$bookmarks{$_->{'object'}}}, $_ for grep $_->{'object'} && $_->{'url'} =~ /\/$_->{'object'}\// && $builder->object($_->{'object'}) && $_->{'url'} =~ /$servername/, $user->bookmarks;
  
  foreach my $t (keys %history) {
    foreach (@{$history{$t}}) {
      my %clear = $_->{'species'} eq $species ? () : ( __clear => 1 );
      unshift @{$self->{'history'}{lc $t}}, [ $type eq $t ? $hub->url({ species => $_->{'species'}, $_->{'param'} => $_->{'value'}, %clear }) : $_->{'url'}, $_->{'name'} ];
    }
    
    push @{$self->{'history'}{lc $t}}, [ "/Account/ClearHistory?object=$t", 'Clear history', ' clear_history bold' ] if scalar @{$history{$t}};
  }
  
  foreach my $t (keys %bookmarks) {
    my $i;
    
    foreach (sort { $b->{'click'} <=> $a->{'click'} || $b->{'modified_at'} cmp $a->{'modified_at'} } @{$bookmarks{$t}}) {
      push @{$self->{'bookmarks'}{lc $t}}, [ '/Account/UseBookmark?id=' . $_->id, $_->{'shortname'} && length $_->{'shortname'} < length $_->{'name'} ? $_->{'shortname'} : $_->{'name'}, $_->id ];
      last if ++$i == 5;
    }
    
    push @{$self->{'bookmarks'}{lc $t}}, [ '/Account/Bookmark/List', 'More...',  ' modal_link bold' ] if scalar @{$bookmarks{$t}} > 5;
  }
}

sub get_json {
  my $self    = shift;
  my $content = $self->content;
  return $content ? { tabs => $content, activeTab => $self->active } : {};
}

sub content {
  my $self  = shift;
  my $count = scalar @{$self->entries};
  
  return '' unless $count;
  
  my ($content, $short_tabs, $long_tabs);
  my @style   = $count > 4 ? () : (' style="display:none"', ' style="display:block"');
  my $history = 0;
  
  foreach my $entry (@{$self->entries}) {
    $entry->{'url'} ||= '#';
    
    my $name         = encode_entities($self->strip_HTML($entry->{'caption'}));
    my ($short_name) = split /\b/, $name;
    my $constant     = $entry->{'constant'} ? ' class="constant"' : '';
    my $short_link   = qq{<a href="$entry->{'url'}" title="$name"$constant>$short_name</a>};
    my $long_link    = qq{<a href="$entry->{'url'}"$constant>$name</a>};
    
    if ($entry->{'disabled'}) {
      my $span = $entry->{'dropdown'} ? qq{<span class="disabled toggle" title="$entry->{'dropdown'}">} : '<span class="disabled">';
      $_ = qq{$span$name</span>} for $short_link, $long_link;
    }
    
    if ($entry->{'dropdown'}) {
      # Location tab always has a dropdown because its history can be changed dynamically by the slider navigation.
      # Hide the toggle arrow if there are no bookmarks or history items for it.
      my @hide = $entry->{'type'} eq 'Location' && !($self->{'history'}{'location'} || $self->{'bookmarks'}{'location'}) ? (' empty', ' style="display:none"') : ();
      $history = 1;
      $_       = qq{<span class="dropdown$hide[0]">$_<a class="toggle" href="#" rel="$entry->{'dropdown'}"$hide[1]>&#9660;</a></span>} for $short_link, $long_link;
    }
    
    $short_tabs .= qq{<li class="$entry->{'class'} short_tab"$style[0]>$short_link</li>};
    $long_tabs  .= qq{<li class="$entry->{'class'} long_tab"$style[1]>$long_link</li>};
    
    $self->active = $name if $entry->{'class'} =~ /\bactive\b/;
  }
  
  $content  = $short_tabs . $long_tabs;
  $content  = qq{<ul class="tabs">$content</ul>} if $content;
  $content .= $self->species_list                if $self->{'species_list'};
  $content .= $self->history                     if $history;
  
  return $content;
}

sub species_list {
  my $self      = shift;
  my $total     = scalar @{$self->{'species_list'}};
  my $remainder = $total % 3;
  my $third     = int($total / 3) - 1;
  my $html;
  
  # Ok, this is slightly mental. Basically, we're building a 3 column structure with floated <li>'s.
  # Because they are floated, if they were printed alphabetically, this would result in a menu with was alphabetised left to right, i.e.
  # A B C
  # D E F
  # G H I
  # Because the list is longer than it is wide, it is much easier to find what you want if alphabetised top to bottom, i.e.
  # A D G
  # B E H
  # C F I
  # The code below achieves that goal
  my @ends = ( $third + !!($remainder && $remainder--) );
  push @ends, $ends[0] + 1 + $third + !!($remainder && $remainder--);
  
  my @output_order;
  push @{$output_order[0]}, $self->{'species_list'}->[$_] for 0..$ends[0];
  push @{$output_order[1]}, $self->{'species_list'}->[$_] for $ends[0]+1..$ends[1];
  push @{$output_order[2]}, $self->{'species_list'}->[$_] for $ends[1]+1..$total-1;
  
  for my $i (0..$#{$output_order[0]}) {
    for my $j (0..2) {
      $html .= sprintf '<li>%s</li>', $output_order[$j][$i] ? qq{<a class="constant" href="$output_order[$j][$i][0]">$output_order[$j][$i][1]</a>} : '&nbsp;';
    }
  }
  
  return qq{<div class="dropdown species"><h4>Select a species</h4><ul>$html</ul></div>};
}

sub history {
  my $self = shift;
  my %html;
  
  foreach my $type (grep scalar @{$self->{'history'}->{$_}}, keys %{$self->{'history'}}) {
    my $history  = join '', map qq{<li><a href="$_->[0]" class="constant $_->[2]" >$_->[1]</a></li>}, @{$self->{'history'}->{$type}};
    $html{$type} = qq{<h4>Recent ${type}s</h4><ul class="recent">$history</ul>};
  }
  
  foreach my $type (grep scalar @{$self->{'bookmarks'}->{$_}}, keys %{$self->{'bookmarks'}}) {
    my $bookmarks = join '', map qq{<li><a href="$_->[0]" class="constant $_->[2]" >$_->[1]</a></li>}, @{$self->{'bookmarks'}->{$type}};
    $html{$type} .= sprintf qq{<h4>%s bookmarks</h4><ul class="bookmarks">$bookmarks</ul>}, ucfirst $type;
  }
  
  $html{$_} = qq{<div class="dropdown history $_">$html{$_}</div>} for keys %html;
  
  $html{'location'} ||= '
    <div class="dropdown history location">
      <h4>Recent locations</h4>
      <ul class="recent"><li><a class="constant clear_history bold" href="/Account/ClearHistory?object=Location">Clear history</a></li></ul>
    </div>';
  
  return join '', values %html;
}

1;
