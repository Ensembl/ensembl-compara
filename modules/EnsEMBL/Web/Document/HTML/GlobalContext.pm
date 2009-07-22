# $Id$

package EnsEMBL::Web::Document::HTML::GlobalContext;

### Generates the global context navigation menu, used in dynamic pages

use strict;
use CGI qw(escapeHTML);
use EnsEMBL::Web::Document::HTML;

our @ISA = qw(EnsEMBL::Web::Document::HTML);


sub add_entry {
### a
  my $self = shift;
  push @{$self->{'_entries'}}, {@_};
}

sub active {
  my $self = shift;
  $self->{'_active'} = shift if @_;
  return $self->{'_active'};
}
sub entries {
### a
  my $self = shift;
  return $self->{'_entries'}||[];
}

sub render_modal {
  return;
  my $self = shift;
  my $T = $self->_content;
     $T =~ s/id="tabs"/id="modal_tabs"/;
     $T =~ s/class="link /class="/g;
     $T =~ s/ class=""//g;
  $self->print( $T );
}

sub get_json {
  my $self = shift;
  
  return unless scalar @{$self->entries};
  
  my $content = '<ul class="tabs">';
  my $i = 0;
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
      $name = CGI::escapeHTML($name);
      $name = qq{<a href="$entry->{'url'}">$name</a>} if $entry->{'url'};
    }
    
    $content .= qq{<li id="$id" class="$entry->{'class'}">$name</li>};
    
    $active = $i if $entry->{'class'} =~ /\bactive\b/;
    $i++;
  }
  
  $content .= '</ul>';
  
  return qq{'tabs':'$content','activeTab':'$active'};
}

sub render {
  my $self = shift;
  $self->print( $self->_content );
}

sub _content {
  my $self = shift;
  
  return '' unless scalar(@{$self->entries});
  my $content = '
    <div id="tabs">
      <dl class="tabs">';
  foreach my $entry ( @{$self->entries} ) {
    my $name = $entry->{caption};
    if ($name eq '-') {
      $name =  sprintf( '<span title="%s">%s</span>', $entry->{'disabled'}, $entry->{'type'});
    } else { 
      $name =~ s/<\\\w+>//g;
      $name =~ s/<[^>]+>/ /g;
      $name =~ s/\s+/ /g;
      $name = CGI::escapeHTML( $name );
      if( $entry->{'url'} ) {
        $name = sprintf( '<a href="%s">%s</a>', $entry->{'url'}, $name );
      }
    }
    $content .= sprintf( '
        <dd id="%s" class="link %s">%s</dd>', lc('tab_'.($entry->{'id'}||$entry->{'type'})), $entry->{class}, $name );
  }
  $content .= '
        <dt class="hidden">.</dt>
      </dl>
    </div>';
  return $content;
}

return 1;
