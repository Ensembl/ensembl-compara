package EnsEMBL::Web::Component::Messages;

### Module to output messages from session, etc

use strict;
use warnings;
no warnings "uninitialized";
use base qw(EnsEMBL::Web::Component);

use EnsEMBL::Web::Constants;

sub _init {
  my $self = shift;
  $self->cacheable(0);
  $self->ajaxable(0);
}

sub caption {
  my $self = shift;
  return undef;
}

sub content {
  my $self = shift;
  my $object = $self->object;
  
  return unless $object->can('get_session');
  
  my $session = $object->get_session;
  
  my @priority = EnsEMBL::Web::Constants::MESSAGE_PRIORITY;
  
  my %messages;
  my $html;
  
  # Group messages by type
  push @{$messages{$_->{'function'}||'_info'}}, $_->{'message'} for $session->get_data(type => 'message');
  
  $session->purge_data(type => 'message');
  
  foreach (@priority) {
    next unless $messages{$_};
    
    my $func = $self->can($_) ? $_ : '_info';
    my $caption = $func eq '_info' ? 'Information' : ucfirst substr $func, 1, length $func;   
    my $msg = join '</li><li>', @{$messages{$_}};
    
    $msg = "<ul><li>$msg</li></ul>" if scalar @{$messages{$_}} > 1;
    
    $html .= $self->$func($caption, $msg);
    $html .= '<br />';
  }
  
  return $html;
}

1;
