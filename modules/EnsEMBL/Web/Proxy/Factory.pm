package EnsEMBL::Web::Proxy::Factory;

=head1 NAME

EnsEMBL::Web::Proxy::Factory

=head1 SYNOPSIS
To allow for Plugins you no longer create individual objects of type
"EnsEMBL::Web::Factory::Gene" e.g., but instead create a Proxy::Factory
with type "Gene"

=head1 DESCRIPTION

 my $gene  = EnsEMBL::Web::Proxy::Factory->new(
               'Gene', $ensembl_object, 
               { '_databases' => $dbs, '_input' => $input } );

This object is a wrapper round real objects which allows functions
to be distributed about a number of plugins.

An instance of a Proxy::Object is a blessed array ref with 3 elements:

 [0] The type of the object (e.g. Gene)
 [1] The "data" hash containing information pertaining to the Gene

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

James Smith - js5@sanger.ac.uk

=cut

use strict;
use EnsEMBL::Web::Proxy;
our @ISA = qw( EnsEMBL::Web::Proxy );

=head2 new

 Arg[1]      : object type
 Arg[2]      : data
 Example     : EnsEMBL::Web::Proxy::Factory( 'Gene', $data );
 Description : Instantiates the Proxy::Factory, add all it's child
               factories
 Return type : the Proxy::Factory if any of the child objects can
               instantiate.
=cut

sub new {
  my( $class, $type, $data ) = @_;
  my $self = $class->SUPER::new(
    'Factory', $type, $data,
    '_feature_IDs'=>[], '_dataObjects' => [] 
  );
  return $self;
}

1;
