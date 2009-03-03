package EnsEMBL::Web::Filter;

### Parent for filters that control access to web pages.
 
### Note that in child modules you *must* set one or more error codes
### and corresponding messages, but it is not always necessary to set 
### a redirect URL as this will default to the originating page

use strict;
use warnings;

use Class::Std;

{

my %Object        :ATTR(:get<object> :set<object>);
my %Redirect      :ATTR(:get<redirect> :set<redirect>);
my %ErrorCode     :ATTR(:get<error_code> :set<error_code>);
my %Messages      :ATTR(:get<messages> :set<messages>);
my %Exceptions    :ATTR(:get<exceptions> :set<exceptions>);

sub BUILD {
  my ($self, $ident, $args) = @_;
  ## Set the messages hash here
  $self->set_messages({});
  $self->set_object($args->{object});
}

sub object {
  my $self = shift;
  return $self->get_object;
}

sub error_code {
  my $self = shift;
  return $self->get_error_code;
}

sub catch {
  ## Function to catch any errors and set the code to be used in the URL
  ## N.B. this is a stub: set your error codes in the child module
  my $self = shift;
  warn "!!! No error codes set in filter $self";
}

sub name {
  ## Returns the name of the filter, i.e. the final section of the namespace
  ## N.B. because we do not pass the full filter namespace, filters are not pluggable,
  ## though they can be overridden in the normal Perl way
  my $self = shift;
  my @namespace = split('::', ref($self));
  return $namespace[-1];
}

sub error_message {
## Returns an error message, based on the filter_code parameter

## Note that we set a default message in case there is no match. 
## The default message has to be very vague because filters are used for 
## data validation as well as access control. Ideally the user should never 
## see this message - if it appears on a web page, you know you are 
## missing a message in your filter!
  my ($self, $code) = @_;
  my $message;
  if ($code) {
    ## Check for temporary messages stored in session
    ## Or return a preset message
    $message = $self->get_messages->{$code};
  }
  else {
    $message = 'Sorry, validation failed.';
  }
  return $message;
}

sub set_tmp_message {
## Stores a dynamically-generated message in the session
## Added primarily for use with DAS servers
  my ($self, $code, $message) = @_;
}

sub redirect {
## Defaults to returning the originating URL, unless already set 
## within the individual Filter's catch method.
  my $self = shift;
  my $url = $self->get_redirect;
  my @ok_params;
  if ($url && ($url !~ /_referer/ || $url !~ /x_directed_with/)) {
    ## Automatically add in _referer and x_directed_with, if not present
    foreach my $p ($self->object->input_param) {
      next unless $p eq '_referer' || $p eq 'x_directed_with';
      push @ok_params, $p.'='.$self->object->param($p);
    }
    if (@ok_params) {
      $url .= ($url=~/\?/?';':'?').join(';', @ok_params);
    }
  }
  else {
    $url = '/'.$ENV{'ENSEMBL_TYPE'}.'/'.$ENV{'ENSEMBL_ACTION'};
    foreach my $p ($self->object->input_param) {
      push @ok_params, $p.'='.$self->object->param($p);
    }
    if (@ok_params) {
      $url .= '?'.join(';', @ok_params);
    }
  }
  return $url;
}

}

1;
