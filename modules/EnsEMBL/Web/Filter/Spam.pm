package EnsEMBL::Web::Filter::Spam;

use strict;
use warnings;
use Class::Std;

use base qw(EnsEMBL::Web::Filter);

### Checks if a form's fields are spam-free. Use 'catch' to check an entire form,
### or 'check' to check an individual field. 
### 'Honeypots' are fields intended to trap spambots, by tricking them into filling
### in fields that are hidden from the legitimate user

{

my %Threshold :ATTR(:set<threshold> :get<threshold>);
my %Honeypots :ATTR(:set<honeypots> :get<honeypots>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  $Threshold{$ident}  = $args->{threshold} || 60;
  ## Set the messages hash here
  $self->set_messages({
    'spam' => 'Sorry, one of your form entries was identified as spam. Please remove excess URLs and try again.', 
    'empty' => 'Sorry, one of the required fields was empty. Please try again.', 
  });
}

sub catch {
  my $self = shift;

  ## Check honeypot fields for content - they should be empty!
  foreach my $field (@{$self->object->interface->honeypots}) {
    if ($self->object->param($field)) {
      $self->set_error_code('spam');
      warn "@@@ FILTERED DUE TO CONTENT IN HONEYPOT $field.....";
    }
  }

  ## Check legitimate fields for bogus content
  foreach my $field ($self->object->param) {
    $self->check($self->object->param($field), 1);
  }
}

sub check {
  my ($self, $content, $threshold) = @_;
  $threshold = $self->get_threshold unless $threshold;
  return 0 if !$content && $threshold == 1; ## Only way to OK optional fields as spam-free!

  ## Strip out links
  (my $check = $content) =~ s/<a\s+href=.*?>.*?<\/a>//smg;
  $check =~ s/\[url=.*?\].*?\[\/url\]//smg;
  $check =~ s/\[link=.*?\].*?\[\/link\]//smg;
  $check =~ s/https?:\/\/\S+//smg;
  ## If insufficient legit content left after link removal, it's probably spam!
  if( length($check)<length($content)/$threshold ) {
    $self->set_error_code('spam');
    warn "@@@ FILTERED DUE TO BLOG SPAM.....";
    return 1;
  }
  $check =~ s/\s+//gsm;
  if( $check eq '' ) {
    $self->set_error_code('empty');
    warn "@@@ FILTERED DUE TO ZERO CONTENT!";
    return 1;
  }
  return 0;

}


}

1;
