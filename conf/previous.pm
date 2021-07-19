=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2021] EMBL-European Bioinformatics Institute

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

package previous;

### Provides the PREV psudo-class syntax for calling a method,
### a class function or a sub-routine from the core web code (or
### a previous plugin) from  inside a plugin that is overrdding
### the method/sub-routine.
###
### Working depends on the way plugins are loaded, see LoadPlugins
###
### Usage:
### package EnsEMBL::Web::SomeClass; # core webcode
### use strict;
### sub new {
###   return bless {}, shift;
### }
### 1;
###
### package EnsEMBL::Web::SomeClass; # inside plugins
### use strict;
### use previous qw(new);
### sub new {
###   my $self = shift->PREV::new(@_);
###   // do something to the object before returning it
###   return $self;
### }
###
### Just like SUPER, PREV is resolved from the package where the
### call is made. It is not resolved based on the object's class.
###
### Unlike SUPER, PREV can also be used on a class function or
### a sub-routine, and usage is like below:
###
### package EnsEMBL::Web::SomeUtility; # inside plugins
### use strict;
### use previous qw(my_sub);
### sub my_sub {
###   my $result = PREV::my_sub(); # use the core webcode function
###   // do something else
###   return $result;
### }
###
### The call to the method gets transfered to a method with the
### given name that is found first declared in the list of
### previous plugins or the core web code in the same class or
### any of it's parents.
###

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

sub import {
  my $self = shift;

  if (@_) {

    # For all the methods that are intended to be used
    # with PREV keyword, we need to make a copy of them so
    # that they don't get overwritten by the new methods
    # which will be declared further in the plugin file (the
    # one that is calling 'use previous qw(methods)').
    # Since we need to remember these old methods' names to
    # call them in future, the copied method is given
    # a prefix that corresponds to the plugin it's being
    # modified in. Thus all the methods in all the packages
    # that are being renamed in one plugin will have a same
    # prefix, but different from methods being renamed in
    # some other plugin.

    my @caller          = caller;
    my $target_package  = $caller[0];
    my $method_prefix   = _method_prefix(@caller);

    no strict qw(refs);

    for (@_) {

      # If the requesting class, or one of its parents has the
      # method defined in their packages, it gets copied with
      # the prefix to the requesting class. If none of them has
      # the method defined, an empty method won't get created.
      # This is to avoid causing any other problems.

      if (my $coderef = $target_package->can($_)) {
        *{"${target_package}::${method_prefix}_$_"} = $coderef;
      } else {
        warn qq(Method "$_" exists neither in the core web code nor in the already loaded plugins at $caller[1] line $caller[2].\n);
      }
    }
  }
}

sub _method_prefix {
  my ($package, $filename) = @_;
  my $package_path = "$package.pm" =~ s/::/\//gr;
  return md5_hex($filename =~ s/\/+/\//gr =~ s/$package_path$//r);
}

# Secret package

package PREV;

our $AUTOLOAD;

sub AUTOLOAD {
  my $method  = $AUTOLOAD =~ s/^PREV:://r;
  my @caller  = caller;
  my $coderef = $caller[0]->can(join '_', previous::_method_prefix(@caller), $method) || die qq(No PREV method for "$method" via package "$caller[0]" at $caller[1] line $caller[2].\n);
  
  goto &$coderef;
}

sub DESTROY {}

1;
