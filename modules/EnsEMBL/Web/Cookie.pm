=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

### Class inherited from actual CGI cookie, to make it easy to access/modify cookie information for all scenarios, including encrypted cookies in Ensembl
### All the methods in CGI::Cookie that actually construct a CGI::Cookie object have been overridden to accept apache handle as first argument

use strict;
use warnings;

use EnsEMBL::Web::Exceptions;
use EnsEMBL::Web::Attributes;
use EnsEMBL::Web::Utils::Encryption qw(encrypt_value decrypt_value);

use base qw(CGI::Cookie);

sub new {
  ## @overrides
  ## @constructor
  ## Wrapper to the parent constructor, accepting parameters without a prefixed hyphen, and few extra parameters.
  ## @param Apache handle for setting and reading cookies
  ## @param Hashref with following keys
  ##  - name
  ##  - value
  ##  - domain
  ##  - expires
  ##  - path
  ##  - httponly
  ##  - env
  ##  - encrypted
  ## Overrides the CGI::Cookie constructor to make it mandatory to pass apache handle in arguments to the constructor
  my ($class, $apache_handle, $params) = @_;

  throw exception('CookieException', 'Apache Handle needs to be provided to set or access cookies.')    unless ref $apache_handle && UNIVERSAL::isa($apache_handle, 'Apache2::RequestRec');
  throw exception('CookieException', 'Can not create or read a cookie without being provided a name.')  unless $params->{'name'};

  my $self = $class->SUPER::new('-name' => $params->{'name'}, '-value' => $params->{'value'} || 0);

  $self->_init($apache_handle, $params);
  $self->value($params->{'value'} || 0) if $self->encrypted; # set encrypted value if 'encrypted' flag is on

  return $self;
}

sub apache_handle {
  ## @accessor
  my $self = shift;
  $self->{'_ens_apache_handle'} = shift if @_;
  return $self->{'_ens_apache_handle'};
}

sub value {
  ## @overrides
  ## Sets/Gets the value considering encryption if any
  my $self    = shift;
  my $caller  = caller;

  return $self->SUPER::value(@_) if $caller eq 'CGI::Cookie'; # Don't override for CGI::Cookie's usage

  if (@_) {
    my $value = $self->{'_ens_value'} = shift;
    $self->SUPER::value($self->encrypted ? encrypt_value($value) : $value);
    if (my $env = $self->env) {
      $self->apache_handle->subprocess_env->{$env} = $value;
      $ENV{$env} = $value;
    }
  }
  return exists $self->{'_ens_value'} ? $self->{'_ens_value'} : ($self->{'_ens_value'} = $self->SUPER::value);
}

sub get_value :Deprecated("Please use 'value' instead of 'get_value'") {
  ## @return Value of the cookie
  ## DEPRECATED: For backward compatibility only
  return shift->value;
}

sub encrypted {
  ## @accessor
  my $self = shift;
  $self->{'_ens_encrypted'} = shift if @_;
  return $self->{'_ens_encrypted'} ? 1 : 0;
}

sub expires {
  ## @accessor
  my $self = shift;
  return $self->SUPER::expires($_[0] && $_[0] ne 'now' ? $_[0] : 'Thu, 31-Dec-2037 23:59:59 GMT') if @_;
  return $self->SUPER::expires;
}

sub env {
  ## @accessor
  my $self = shift;
  $self->{'_ens_env'} = shift if @_;
  return $self->{'_ens_env'};
}

sub bake {
  ## @overrides We do baking in our own oven
  ## @static    If called on the class, it instantiates an object with given params and then sends the cookie to browser
  ## @nonstatic If called on the object, it sends the cookie header to browser
  ## Sends an actual cookie to the browser corresponding to this object
  ## @param  (Optional - required only if calling on the class) Apache handle as required by the constructor
  ## @param  (Optional - required only if calling on the class) Hashref as required by the constructor
  ## @param  (Optional - required only if value being changed) New value for the cookie
  ## @return this cookie object itself
  my $self = ref $_[0] ? shift : shift->new(splice @_, 0, 2);

  $self->value(shift) if @_;

  my $r   = $self->apache_handle;
  my $str = $self->as_string;

  $r->headers_out->add('Set-cookie' => $str);
  $r->err_headers_out->add('Set-cookie' => $str);

  return $self;
}

sub clear {
  ## @static    If called on the class, it instantiates an object with given params and then clears the actual cookie
  ## @nonstatic Clears the given cookie
  ## Clears a cookie by setting its expiry time to past
  ## @note This method can be called on the object or on the class (If called on the class, it instantiates an object with given params and then sends the cookie to browser)
  ## @params (Optional - required only if calling on the class) As required by the constructor
  ## @return this cookie object itself
  my $self = ref $_[0] ? shift : shift->new(splice @_, 0, 2);
  $self->expires('now');
  return $self->bake(0);
}

sub retrieve {
  ## Retrieves cookie(s) from apache cookie header
  ## @static
  ## @param  Apache Handle
  ## @param  (Optional) Cookie string if cookie saved externally
  ## @params Hashref as required by the constructor (list of hashrefs, one for each cookie for retrieving multiple cookies)
  ## @return the cookie object(s) (a list of cookie objects while retrieving multiple cookies)
  my ($class, $apache_handle) = splice @_, 0, 2;

  my $cookies = $class->parse($apache_handle, ref $_[0] ? '' : shift);
  my @cookies;

  for (@_) {
    my $cookie = $cookies->{$_->{'name'}} || undef;
    if ($cookie) {
      $cookie->_init($apache_handle, $_, 1) if keys %$_;
      if ($cookie->encrypted) {
        my ($value, $flag) = decrypt_value($cookie->value);
        $cookie->value($value);
        $cookie->clear if $flag eq 'expired';  ## Remove the cookie
        $cookie->bake  if $flag eq 'refresh';  ## Refresh the cookie
      }
    }
    push @cookies, $cookie;
  }

  return wantarray ? @cookies : $cookies[0];
}

sub parse {
  ## @overrides
  ## @static
  ## Parses a cookie string to a hash of cookie name and cookie object as key-value pairs
  ## @param Apache handle
  ## @param Raw cookie string
  ## @return In list context, hash of keys as cookie names and values as corresponding EnsEMBL::Web::Cookie objects, hashref of the same in case of scalar context
  my ($class, $apache_handle, $cookie_string) = @_;

  my $cookies = CGI::Cookie->parse($cookie_string || $apache_handle->headers_in->{'Cookie'});

  for (keys %$cookies) {
    $cookies->{$_} = bless $cookies->{$_}, $class;
    $cookies->{$_}->_init($apache_handle, {}, 1);
  }

  return wantarray ? %$cookies : $cookies;
}

sub fetch {
  ## @overrides
  ## @static
  ## Retrieves all the cookies from header
  ## @note This does not decrypt value of any encrypted cookie (for an encrypted cookie, use retrieve method)
  ## @param Apache handle
  ## @return In list context, returns a hash of name => web cookie object for all the retrieved cookies, hashref in case of scalar context
  return shift->parse(shift);
}

sub _init {
  ## @private
  my ($self, $apache_handle, $params, $retrieving) = @_;
  $self->httponly(1)                    if $params->{'httponly'} || $params->{'encrypted'};
  $self->encrypted(1)                   if $params->{'encrypted'};
  $self->env($params->{'env'})          if $params->{'env'};
  $self->expires($params->{'expires'})  unless $retrieving;
  $self->domain($params->{'domain'} || $SiteDefs::ENSEMBL_COOKIEHOST);
  $self->path($params->{'path'}     || '/');
  $self->apache_handle($apache_handle);
}

1;
