=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

package EnsEMBL::Web::Attributes;

### Attributes to declare accessor and abstract methods (more attributes can be added by just declaring a new method in this package with the same name)
### Consider this as an experimantal feature, may be changed, or removed in future
### Attributes only work for subroutines, not for variables

use strict;
use warnings;

use Exporter qw(import);
our @EXPORT = qw(MODIFY_CODE_ATTRIBUTES);

use EnsEMBL::Web::Exceptions;

my %SYMCACHE;

sub _findsym {
	my ($package, $ref) = @_;
	return $SYMCACHE{$package,$ref} if $SYMCACHE{$package, $ref};
	{
    no strict 'refs';
  	my $type = ref($ref);
    foreach my $sym (values %{$package."::"}) {
	    use strict;
	    next unless ref(\$sym) eq 'GLOB';
      return $SYMCACHE{$package,$ref} = \$sym if *{$sym}{$type} && *{$sym}{$type} == $ref;
    }
	}
}

sub Accessor {
  my (undef, $package, $code, $glob) = @_;
  *{$glob} = sub {
    my $object  = shift;
    my $key     = $code->();
    $object->{$key} = shift if @_;
    return $object->{$key};
  }
}

sub Abstract {
  my (undef, $package, $code, $glob) = @_;
  my $method = *{$glob} =~ s/.+\:\://r;
  *{$glob} = sub {
    my $ex = exception('AbstractMethodNotImplemented', "Abstract method '$method' called.");
    $ex->stack_trace_array->[0][3] = "${package}::${method}"; # replace EnsEMBL::Web::Attributes::__ANON__ with the actual method that was called
    throw $ex;
  };
}

sub MODIFY_CODE_ATTRIBUTES {
  ## This method gets injected into the caller's namespace and is the actual method that is called by perl attributes package
  ## Currently only one attribute is supported (although this method receives list of all attributes)
  my ($package, $code, $attr) = @_;

  if (__PACKAGE__->can($attr)) {
    __PACKAGE__->$attr($package, $code, _findsym($package, $code));
    return;
  }

  return $attr;
}

1;
