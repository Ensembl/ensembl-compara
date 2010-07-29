# $Id$

package EnsEMBL::Web::Document::HTML::GlobalContext;

# Generates the global context navigation menu, used in dynamic pages

use strict;

use HTML::Entities qw(encode_entities);

use base qw(EnsEMBL::Web::Document::HTML);

sub add_entry {
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub active {
  my $self = shift;
  $self->{'_active'} = shift if @_;
  return $self->{'_active'};
}

sub entries {
  my $self = shift;
  return $self->{'_entries'} || [];
}

sub get_json {
  my $self = shift;
  my ($content, $active) = $self->_content('li');
  return $content ? { tabs => qq{<ul class="tabs">$content</ul>}, activeTab => $active } : {};
}

sub render {
  my $self = shift;
  
  my ($content) = $self->_content('li');
  
  if ($content) {
    $self->print(qq{
      <ul class="tabs">
        $content
      </ul>
    });
  }
}

sub _content {
  my ($self, $node) = @_;
  
  my $count = scalar @{$self->entries};
  
  return '' unless $count;
  
  my ($content, $active, $short_tabs, $long_tabs);
  my @style = $count > 4 ? () : (' style="display:none"', ' style="display:block"');
  
  foreach my $entry (@{$self->entries}) {
    $entry->{'url'} ||= '#';
    
    my $name = $entry->{'caption'};
    $name =~ s/<\\\w+>//g;
    $name =~ s/<[^>]+>/ /g;
    $name =~ s/\s+/ /g;
    $name = encode_entities($name);
    
    my ($short_name) = split /\b/, $name;
    
    $short_tabs .= qq{<$node class="$entry->{'class'} short_tab"$style[0]><a href="$entry->{'url'}" title="$name">$short_name</a></$node>};
    $long_tabs  .= qq{<$node class="$entry->{'class'} long_tab"$style[1]><a href="$entry->{'url'}">$name</a></$node>};

    $active = $name if $entry->{'class'} =~ /\bactive\b/;
  }
  
  $content = $short_tabs . $long_tabs;
    
  return ($content, $active);
}

1;
