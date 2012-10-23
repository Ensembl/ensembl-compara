# $Id$

package EnsEMBL::Web::Component::Messages;

### Module to output messages from session, etc

use strict;

use EnsEMBL::Web::Constants;

use base qw(EnsEMBL::Web::Component);

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub content {
  my $self = shift;
  my $hub = $self->hub;
  
  return unless $hub->can('session');
  
  my $session  = $hub->session;
  my @priority = EnsEMBL::Web::Constants::MESSAGE_PRIORITY;
  my %messages;
  my $html;
  
  # Group messages by type
  # Set a default order of 100 - we probably aren't going to have 100 messages on the page at once, and this allows us to force certain messages to the bottom by giving order > 100
  push @{$messages{$_->{'function'} || '_info'}}, $_->{'message'} for sort { $a->{'order'} || 100 <=> $b->{'order'} || 100 } $session->get_data(type => 'message');
  
  $session->purge_data(type => 'message');
  
  foreach (@priority) {
    next unless $messages{$_};
    
    my $func    = $self->can($_) ? $_ : '_info';
    my $caption = $func eq '_info' ? 'Information' : ucfirst substr $func, 1, length $func;   
    my $msg     = join '</li><li>', @{$messages{$_}};
       $msg     = "<ul><li>$msg</li></ul>" if scalar @{$messages{$_}} > 1;
    
    $html .= $self->$func($caption, $msg);
    $html .= '<br />';
  }
  
  return qq{<div id="messages">$html</div>};
}

1;
