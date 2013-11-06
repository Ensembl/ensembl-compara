package previous;

### Provides the PREV psudo-class for calling a method from the
### core web code (or a previous plugin) from  inside a plugin that
### is overrdding the method
###
### Usage:
###
### package EnsEMBL::Web::SomeClass; # inside plugins
### use strict;
### use previous qw(new);
### sub new {
###   my $self = shift->PREV::new(@_);
###   $self->do_something;
###   return $self;
### }
###
### If PREV::method is called on an object in a file (possibly
### not the object's class file itself) inside a plugin, it  will
### transfer the call to a method with the given name that is
### found first declared in the list of previous plugins or the
### core web code in the same class or any of it's parents.
###

use strict;
use warnings;

use Digest::MD5 qw(md5_hex);

sub import {
  my ($self, @methods) = @_;
  my @caller = caller;

  if (@methods) {

    # For all the methods that are intended to be used
    # with PREV keyword, we need to make a copy of them so
    # that they don't get overwritten by the new methods
    # which will be declared further in the plugin file (the
    # one that is calling 'use previous qw(methods)').
    # Since we need to remember these old methods' names to
    # call them in future, each method is renamed by giving
    # it a prefix that corresponds to the plugin it's being
    # modified in. Thus all the methods in all the packages
    # that are being renamed in one plugin will have a same
    # prefix, but different from methods being renamed in
    # some other plugin.

    my $target_package = $caller[0];
    my $method_prefix  = _method_prefix(@caller);
    
    no strict qw(refs);
    
    for (@methods) {
    
      # If the method being renamed is not defined in the package,
      # we won't create an empty method to avoid causing any other
      # problems.
    
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