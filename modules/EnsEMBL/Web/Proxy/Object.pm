package EnsEMBL::Web::Proxy::Object;

=head1 NAME

EnsEMBL::Web::Proxy::Object

=head1 SYNOPSIS
To allow for Plugins you no longer create individual objects of type
"EnsEMBL::Web::Data::Gene" e.g., but instead create a Proxy::Object
with type "Gene"

=head1 DESCRIPTION

 my $gene  = EnsEMBL::Web::Proxy::Object->new(
               'Gene', $ensembl_object, 
               { '_databases' => $dbs, '_input' => $input } );


This object is a wrapper round real objects which allows functions
to be distributed about a number of plugins.

An instance of a Proxy::Object is a blessed array ref with 3 elements:

 [0] The type of the object (e.g. Gene)
 [1] Common store of information required by the Gene/Factory, e.g.
     database information, input, configurations, ....
 [2] The "data" hash containing information pertaining to the Gene

=head1 LICENCE

This code is distributed under an Apache style licence:
Please see http://www.ensembl.org/code_licence.html for details

=head1 CONTACT

James Smith - js5@sanger.ac.uk

=cut

use strict;
use EnsEMBL::Web::Proxy;
our @ISA = qw( EnsEMBL::Web::Proxy );

# Usage my $gene = EnsEMBL::Web::Proxy::Object( 'Gene', @_ );

=head2 new

 Arg[1]      : object type
 Arg[2]      : ensembl object
 Arg[3]      : data hash ref
 Example     : EnsEMBL::Web::Proxy::Object( 'Gene', $gene, $data );
 Description : Instantiates the Proxy::Object, add all it's child
               objects
 Return type : the Proxy::Object if any of the child objects can
               instantiate.
=cut

sub new {
  my( $class, $type, $object, $data ) = @_;
  my $self = $class->SUPER::new(
    'Object', $type, $data,
    '_object'=> $object
  );
  return $self;
}

1;
