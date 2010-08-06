package EnsEMBL::Web::Filter::Spam;

use strict;

use base qw(EnsEMBL::Web::Filter);

### Checks if a form's fields are spam-free. Use 'catch' to check an entire form,
### or 'check' to check an individual field. 
### 'Honeypots' are fields intended to trap spambots, by tricking them into filling
### in fields that are hidden from the legitimate user

sub threshold :lvalue { $_[0]->{'threshold'}; }

sub init {
  my $self = shift;

  $self->threshold = 60;
  $self->messages = {
    ip    => 'Unable to send message.',
    spam  => 'Sorry, one of your form entries was identified as spam. Please remove excess URLs and try again.', 
    empty => 'Sorry, one of the required fields was empty. Please try again.'
  };
}

sub catch {
  my $self   = shift;
  my $hub = $self->hub;
  
  ## Check honeypot fields for content - they should be empty!
  foreach my $field (@{$hub->interface->honeypots}) {
    if ($hub->param($field)) {
      $self->error_code = 'spam';
      warn "@@@ FILTERED DUE TO CONTENT IN HONEYPOT $field.....";
    }
  }

  ## Check legitimate fields for bogus content
  foreach my $field ($hub->param) {
    $self->check($hub->param($field), 1);
  }
}

sub check {
  my ($self, $content, $threshold) = @_;
  $threshold = $self->threshold unless $threshold;
  
  return 0 if !$content && $threshold == 1; ## Only way to OK optional fields as spam-free!

  # Strip out links
  (my $check = $content) =~ s/<a\s+href=.*?>.*?<\/a>//smg;
  $check =~ s/\[url=.*?\].*?\[\/url\]//smg;
  $check =~ s/\[link=.*?\].*?\[\/link\]//smg;
  $check =~ s/https?:\/\/\S+//smg;
  
  # If insufficient legit content left after link removal, it's probably spam!
  if (length $check < length($content) / $threshold) {
    $self->error_code = 'spam';
    warn '@@@ FILTERED DUE TO BLOG SPAM.....';
    return 1;
  }
  
  $check =~ s/\s+//gsm;
  
  if ($check eq '') {
    $self->error_code = 'empty';
    warn '@@@ FILTERED DUE TO ZERO CONTENT!';
    return 1;
  }
  
  return 0;
}

1;
