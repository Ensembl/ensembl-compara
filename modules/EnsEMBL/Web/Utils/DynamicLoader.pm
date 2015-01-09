=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Utils::DynamicLoader;

use strict;
use warnings;

use EnsEMBL::Web::Exceptions;

use Exporter qw(import);
our @EXPORT_OK = qw(dynamic_require dynamic_require_fallback dynamic_use dynamic_use_fallback);
my %FAILED_INC;

sub dynamic_require {
  ## @function
  ## Dynamically requires a package (but does not call import)
  ## @param Class name to be required
  ## @param Flag if on, will not throw an exception, but will return false if failed to load the class
  ## @return Class name if the loaded successfully, or 0 if no_exception flag is on.
  ## @exception DynamicLoaderException if class not loaded successfully
  my ($classname, $no_exception) = @_;

  if (my $error_message = _dynamic_require($classname)) {
    return 0 if $no_exception;
    throw exception('DynamicLoaderException', $error_message);
  }

  return $classname;
}

sub dynamic_require_fallback {
  ## @function
  ## Tries to dynamically require the first possible module out of a list of given classes
  ## @params List of classnames (Array, not ArrayRef)
  ## @return First successfully required class' name
  ## @exception None
  dynamic_require($_, 1) and return $_ for @_;
}

sub dynamic_use {
  ## @function
  ## Dynamically requires a package and calls new package's import method
  ## @param Class name to be used
  ## @param Flag if on, will not throw an exception, but will return false if failed to load the class
  ## @return Class name if the loaded successfully, or 0 if no_exception flag is on.
  ## @exception DynamicLoaderException if class not loaded successfully
  my $classname = dynamic_require(@_);

  $classname->import if $classname;

  return $classname;
}

sub dynamic_use_fallback {
  ## @function
  ## Tries to dynamically use the first possible module out of a list of given classes
  ## @params List of classnames (Array, not ArrayRef)
  ## @return First successfully used class' name
  ## @exception None
  dynamic_use($_, 1) and return $_ for @_;
}

sub _dynamic_require {
  ## @private
  my $classname = shift;

  return 'Classname parameter missing' unless $classname;

  unless (exists $FAILED_INC{$classname}) { # if not already failed
    eval "require $classname";
    if ($@) {
      $FAILED_INC{$classname} = "Module '$classname' could not be loaded: $@";
      $@ = undef; # otherwise this will get printed to logs afterwards if we warn an empty string
    }
  }

  return $FAILED_INC{$classname} if exists $FAILED_INC{$classname};
}

1;