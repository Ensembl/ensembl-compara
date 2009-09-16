# $Id$

package EnsEMBL::Web::Document::Panel::AjaxMenu;

use strict;
use Data::Dumper qw(Dumper);
use CGI qw(escapeHTML);

use base qw(EnsEMBL::Web::Document::Panel);

sub _start {
  my $self = shift;
}

sub _end   { 
  my $self = shift;
}

sub add_entry {
  my( $self, $hashref ) = @_;
  $self->{'entries'} ||= [];
  foreach( 'label', 'label_html' ){
    unless( defined $hashref->{$_} ){$hashref->{$_} = '' }
  }
  push @{$self->{'entries'}}, {
    'code'       => $hashref->{'code'}      || 'entry_'.($self->{'counter'}++),
    'type'       => $hashref->{'type'}      || '',
    'label'      => $hashref->{'label'},
    'label_html' => $hashref->{'label_html'},
    'link'       => $hashref->{'link'}      || undef,
    'priority'   => $hashref->{'priority'}  || 100,
    'class'      => $hashref->{'class'}     || '',
    'extra'      => $hashref->{'extra'}     || {},
  };
}

sub add_subheader {
  my ($self, $label) = @_;
  
  return unless defined $label;
  
  push @{$self->{'entries'}}, {
    'type'       => 'subheader',
    'label_html' => $label,
    'priority'   => 100
  };
}

sub content {
  my $self = shift;
  
  my @entries;
  
  foreach (sort { $b->{'priority'} <=> $a->{'priority'} || $a->{'label'} cmp $b->{'label'} } @{$self->{'entries'}||[]}) {
    my $type = escapeHTML($_->{'type'});
    my $link;
    
    if ($_->{'link'}) {
      if ($_->{'extra'}->{'abs_url'}) {
        $link = $_->{'link'};
      } else {
        $link = sprintf(
          '<a href="%s"%s %s>%s</a>',
          escapeHTML($_->{'link'}),
          $_->{'extra'}{'external'} ? ' rel="external"' : '',
          $_->{'class'} ? qq{ class="$_->{'class'}"} : '',
          escapeHTML($_->{'label'} . $_->{'label_html'})
        );
      }
    } else {
      $link = escapeHTML($_->{'label'}) . $_->{'label_html'};
    }
    
    s/'/&#39;/g for $type, $link;
    $type = ", 'type': '$type'" if $type;
    
    push @entries, "{'link': '$link'$type}";
  }
  
  foreach ($self->{'caption'}, @entries) {
    s/\n/\\n/g;
    s/\r//g;
  }
  
  $self->printf("{'caption': '%s', 'entries': [%s]}", escapeHTML($self->{'caption'}), join ',', @entries);
}

sub render {
  my( $self, $first ) = @_;
  $self->content();
}

sub _error {
  my( $self, $caption, $body ) = @_;
  $self->add_entry( 
    "$caption: $body" 
  );
}

1;
