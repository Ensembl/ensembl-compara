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
  
  if ($content) {
    $content = qq{<ul class="tabs">$content</ul>};
    return qq{'tabs':'$content','activeTab':'$active'};
  }
}

sub render {
  my $self = shift;
  
  my ($content) = $self->_content('dd');
  
  if ($content) {
    $self->print(qq{
      <div id="tabs">
        <dl class="tabs">
          $content
          <dt class="hidden">.</dt>
        </dl>
      </div>
    });
  }
}

sub _content {
  my ($self, $node) = @_;
  
  return '' unless scalar @{$self->entries};
  
  my $content;
  my $active;
  
  foreach my $entry (@{$self->entries}) {
    my $name = $entry->{'caption'};
    my $id = lc('tab_' . ($entry->{'id'} || $entry->{'type'}));
    
    if ($name eq '-') {
      $name =  qq{<span title="$entry->{'disabled'}">$entry->{'type'}</span>};
    } else { 
      $name =~ s/<\\\w+>//g;
      $name =~ s/<[^>]+>/ /g;
      $name =~ s/\s+/ /g;
      $name = encode_entities($name);
      $name = qq{<a href="$entry->{'url'}">$name</a>} if $entry->{'url'};
    }
    
    $content .= qq{<$node id="$id" class="$entry->{'class'}">$name</$node>};

    $active = $name if $entry->{'class'} =~ /\bactive\b/;
  }
    
  return ($content, $active);
}

1;
