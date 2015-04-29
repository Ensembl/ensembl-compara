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


=head1 NAME - Sanger::Graphics::Root

=head1 SYNOPSIS

use base qw( Sanger::Graphics::Root );

=head1 DESCRIPTION

You shouldn't create a Sanger::Graphics::Root object,
but should inherit it in other modules - it is really
just a container for support functions.

=head1 CONTACT

Post questions to the EnsEMBL developer mailing list: <dev@ensembl.org>

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Sanger::Graphics::Root;
use strict;
use warnings;
no warnings 'uninitialized';

use Data::Dumper;

=head2 new

  Arg [1]    : string $classname
               The name of the class to "use"
  Example    : $myobject->dynamic_use( 'Sanger::Graphics::GlyphSet::das' );
  Description: Requires, and imports the methods for the classname provided,
               checks the symbol table so that it doesn't re-require modules
               that have already been required.
  Returntype : Integer - 1 if successful, 0 if failure
  Exceptions : Warns to standard error if module fails to compile
  Caller     : general

=cut

sub dynamic_use {
  my( $self, $classname ) = @_;
  if( $self->{'failed_tracks'}{$classname} ) {
    warn "Sanger Graphics Root: tried to use $classname again - this has already failed";
    return 0;
  }
  my( $parent_namespace, $module ) = $classname =~/^(.*::)(.*)$/ ? ($1,$2) : ('::',$classname);
  no strict 'refs';
  return 1 if $parent_namespace->{$module.'::'}; # return if already used
  eval "require $classname";
  if($@) {
    warn "Sanger Graphics Root: failed to use $classname\nSanger Graphics Root: $@";
    delete( $parent_namespace->{$module.'::'} );
    $self->{'failed_tracks'}{$classname} = 1;
    return 0;
  }
  $classname->import();
  return 1;
}

sub datadump {
  my $self = shift;
  my $i=0;
  warn Data::Dumper::Dumper( @_ ? [@_] : $self );
  while( my @Q = caller(++$i) ) {
    warn "  at $Q[3] (file $Q[1] line $Q[2])\n"; 
  }
}
1;
