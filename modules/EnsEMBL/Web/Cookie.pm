=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2022] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut

package EnsEMBL::Web::Cookie;

### Ensembl specific cookie class to make it easy to access/modify cookie information for all scenarios, including encrypted cookies

use strict;
use warnings;

use URI::Escape qw(uri_escape uri_unescape);

use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Exceptions qw(WebException);
use EnsEMBL::Web::Utils::Encryption qw(encrypt_value decrypt_value);

sub name      :AccessorMutator; ## Name of the cookie
sub domain    :AccessorMutator; ## Domain name for the cookie - defaults to current domain (including any sub domains if any)
sub expires   :AccessorMutator; ## Expiry for the cookie
sub path      :AccessorMutator; ## Path for the cookie - defaults to '/'
sub httponly  :AccessorMutator; ## Flag to tell if this cookie can only be accessed via HTTP, ie. JS can't read it
sub retrieved :Accessor;        ## Returns true if the cookie has been retrieved from http headers

sub new {
  ## @constructor
  ## @param Apache2::RequestRec for sending the cookie header
  ## @param Hashref with following keys
  ##  - name (required)
  ##  - value
  ##  - domain
  ##  - expires
  ##  - path
  ##  - httponly
  ##  - encrypted
  my ($class, $r, $params) = @_;

  throw WebException('Apache2::RequestRec object is needed to set or access cookies.')  unless ref $r && UNIVERSAL::isa($r, 'Apache2::RequestRec');
  throw WebException('Can not create or read a cookie without having a name.')          unless $params->{'name'};

  my $self = bless { '_r' => $r }, $class;

  for (qw(name domain expires path httponly encrypted)) {
    $self->{$_} = $params->{$_} if exists $params->{$_};
  }

  $self->value($params->{'value'}) if exists $params->{'value'};

  return bless $self, $class;
}

sub new_from_header {
  ## @constructor
  ## @param Apache2::RequestRec for reading the cookie header
  ## @return (scalar context) Hashref of cookies with name as keys and corresponding EnsEMBL::Web::Cookie object as value
  ## @return (list context) List of all the EnsEMBL::Web::Cookie objects created
  ## @note If a cookie is encrypted, it's returned as it is without decrypted value (call $cookie->encryption(1) before getting the value to decrypted it)
  my ($class, $r) = @_;

  throw WebException('Apache2::RequestRec object is needed to set or access cookies.') unless ref $r && UNIVERSAL::isa($r, 'Apache2::RequestRec');

  my $cookie_header = _parse_cookie_header($r);
  my $cookies       = {};

  for (keys %$cookie_header) {
    $cookies->{$_} = $class->new($r, {'name' => $_});
    $cookies->{$_}{'_real_value'} = $cookie_header->{$_}; # save the raw value as retrieved from header in the '_real_value' key
    $cookies->{$_}{'retrieved'}   = 1;
  }

  return wantarray ? values %$cookies : $cookies;
}

sub retrieve {
  ## Retrieves value of the cookie from Cookie header
  ## @return The cookie object itself
  my $self = shift;

  # remove any existing value
  delete $self->{'value'};
  delete $self->{'_real_value'};

  my $cookie_header = _parse_cookie_header($self->{'_r'});

  # save the real value only if cookie found in headers
  my $name = $self->name;
  if (exists $cookie_header->{$name}) {
    $self->{'_real_value'}  = $cookie_header->{$name};
    $self->{'retrieved'}    = 1;
  }

  return $self;
}

sub value {
  ## @accessor
  ## @param (Optional) New value to set
  my $self = shift;

  # if setting the value
  $self->{'value'} = shift if @_;

  # if raw value from headers is known but 'value' key is not set yet
  if ($self->{'_real_value'} && !exists $self->{'value'}) {

    # if it's an encrypted cookie, save the decrypted value in 'value' key
    if ($self->{'encrypted'}) {

      my ($value, $flag) = decrypt_value($self->{'_real_value'});

      if ($flag eq 'expired') {
        $self->clear; # clear the existing cookie from the browser

      } elsif ($flag eq 'refresh') {
        $self->bake($value); # encrypt the value, embed the new expiry time in it and then send it again to the browser

      } else { # $flag eq 'ok'
        $self->{'value'} = $value;
      }

    # if it isn't encrypted, 'value' key is same as raw '_real_value'
    } else {
      $self->{'value'} = $self->{'_real_value'};
    }
  }

  return $self->{'value'};
}

sub encrypted {
  ## @accessor
  ## @param (Optional) Flag to turn on/off the encryption
  my $self = shift;

  if (@_) {
    $self->{'encrypted'} = shift;

    # '_real_value' stays the same as it was retrieved from (or sent to) the header,
    # but 'value' will get affected since it is subject to encryption
    delete $self->{'value'} if exists $self->{'_real_value'};
  }

  return $self->{'encrypted'};
}

sub bake {
  ## Sends a Set-Cookie header to the browser corresponding to this object
  ## @param (optional) New string value for the cookie OR a hasref with following keys if changing any existing values
  ##  - value
  ##  - domain
  ##  - expires
  ##  - path
  ##  - httponly
  ##  - encrypted
  ## @return The cookie object itself
  my $self  = shift;
  my $r     = $self->{'_r'};

  # set parameters if needed
  if (@_) {
    my $params = shift // '';
    $params = {'value' => $params} unless ref $params;

    $self->encrypted($params->{'encrypted'} || 0) if exists $params->{'encrypted'};

    for (qw(domain expires path httponly value)) {
      $self->$_($params->{$_}) if exists $params->{$_};
    }
  }

  # get the value after any decryption
  my $value = $self->value;

  # if encryption is on, encrypt the cookie again to embedd the new expiry time in the value
  $self->{'_real_value'} = $self->{'encrypted'} ? encrypt_value($value) : $value;

  # String representation
  my $str = $self->_to_string;

  $r->headers_out->add('Set-cookie' => $str);
  $r->err_headers_out->add('Set-cookie' => $str);

  return $self;
}

sub clear {
  ## Clears a cookie by setting its expiry time to past
  ## @return The cookie object itself
  my $self = shift;
  $self->value('');
  $self->expires('Mon, 01-Jan-2001 00:00:01 GMT');
  return $self->bake();
}

sub _parse_cookie_header {
  ## @private
  my $r = shift;

  my $cookie_string = ($r->headers_in->{'Cookie'} || '') =~ s/^\s+|\s+$//gr;
  my $cookies       = {};

  for (grep $_, split /\s*[;,]\s*/, $cookie_string) { # each key-value pair

    my ($key, $val) = split '=', $_, 2;

    next unless defined $val;

    $cookies->{uri_unescape($key)} = uri_unescape($val);
  }

  return $cookies;
}

sub _to_string {
  ## @private
  my $self = shift;

  my $name      = uri_escape($self->{'name'});
  my $value     = uri_escape($self->{'_real_value'} // ''); # since this is called by 'bake', '_real_value' should be set
  my $domain    = $self->{'domain'} || $SiteDefs::ENSEMBL_COOKIEHOST;
  my $path      = $self->{'path'} || '/';
  my $expires   = exists $self->{'expires'} ? _expires($self->{'expires'}) : 'Thu, 31-Dec-2037 23:59:59 GMT';
  my $httponly  = $self->{'httponly'} || $self->{'encrypted'};

  my @str;

  push @str, sprintf('%s=%s', $name, $value);
  push @str, sprintf('domain=%s', $domain)    if $domain;
  push @str, sprintf('path=%s', $path)        if $path;
  push @str, sprintf('expires=%s', $expires)  if $expires;
  push @str, 'HttpOnly'                       if $httponly;

  return join '; ', @str;
}

###### Utility methods copied from CGI/Util.pm ######

# This internal routine creates date strings suitable for use in
# cookies and HTTP headers.  (They differ, unfortunately.)
# Thanks to Mark Fisher for this.
sub _expires {
  my($time,$format) = @_;
  $format ||= 'http';

  my(@MON)=qw/Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec/;
  my(@WDAY) = qw/Sun Mon Tue Wed Thu Fri Sat/;

  # pass through preformatted dates for the sake of expire_calc()
  $time = _expire_calc($time);
  return $time unless $time =~ /^\d+$/;

  # make HTTP/cookie date string from GMT'ed time
  # (cookies use '-' as date separator, HTTP uses ' ')
  my($sc) = ' ';
  $sc = '-' if $format eq "cookie";
  my($sec,$min,$hour,$mday,$mon,$year,$wday) = gmtime($time);
  $year += 1900;
  return sprintf("%s, %02d$sc%s$sc%04d %02d:%02d:%02d GMT",
                 $WDAY[$wday],$mday,$MON[$mon],$year,$hour,$min,$sec);
}

# This internal routine creates an expires time exactly some number of
# hours from the current time.  It incorporates modifications from 
# Mark Fisher.
sub _expire_calc {
  my($time) = @_;
  my(%mult) = ('s'=>1,
               'm'=>60,
               'h'=>60*60,
               'd'=>60*60*24,
               'M'=>60*60*24*30,
               'y'=>60*60*24*365);
  # format for time can be in any of the forms...
  # "now" -- expire immediately
  # "+180s" -- in 180 seconds
  # "+2m" -- in 2 minutes
  # "+12h" -- in 12 hours
  # "+1d"  -- in 1 day
  # "+3M"  -- in 3 months
  # "+2y"  -- in 2 years
  # "-3m"  -- 3 minutes ago(!)
  # If you don't supply one of these forms, we assume you are
  # specifying the date yourself
  my($offset);
  if (!$time || (lc($time) eq 'now')) {
    $offset = 0;
  } elsif ($time=~/^\d+/) {
    return $time;
  } elsif ($time=~/^([+-]?(?:\d+|\d*\.\d*))([smhdMy])/) {
    $offset = ($mult{$2} || 1)*$1;
  } else {
    return $time;
  }
  my $cur_time = time; 
  return ($cur_time+$offset);
}

1;
