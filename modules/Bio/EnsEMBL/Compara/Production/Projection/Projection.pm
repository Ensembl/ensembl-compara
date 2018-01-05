=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

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


=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::Projection

=head1 DESCRIPTION

Data transfer object for holding the results of a projection.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::Projection;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

=head2 new()

  Arg[-entry]         : required; DBEntry object which was projected
  Arg[-to]            : required; Member from which we projected to
  Arg[-to_identity]   : required; Percentage identity in the target
  Arg[-from]          : required; Member from which we projected from
  Arg[-from_identity] : required; Percentage identity in the source
  Arg[-type]          : required; The type of homology which we detected (
                        populated from homology.description)
  Description         : New method used for a new instance of the given object. 
                        Required fields are indicated accordingly. Fields are 
                        specified using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $entry, $to, $to_identity, $from, $from_identity, $type, ) =
    rearrange( [qw(entry to to_identity from from_identity type )], @args );

  assert_ref( $entry, 'Bio::EnsEMBL::DBEntry' );
  confess(
'The attribute entry must be specified during construction or provide a builder subroutine'
  ) if !defined $entry;
  $self->{entry} = $entry;

  assert_ref( $to, 'Bio::EnsEMBL::Compara::Member' );
  confess(
'The attribute to must be specified during construction or provide a builder subroutine'
  ) if !defined $to;
  $self->{to} = $to;

  confess(
'The attribute to_identity must be specified during construction or provide a builder subroutine'
  ) if !defined $to_identity;
  $self->{to_identity} = $to_identity;

  assert_ref( $from, 'Bio::EnsEMBL::Compara::Member' );
  confess(
'The attribute from must be specified during construction or provide a builder subroutine'
  ) if !defined $from;
  $self->{from} = $from;

  confess(
'The attribute from_identity must be specified during construction or provide a builder subroutine'
  ) if !defined $from_identity;
  $self->{from_identity} = $from_identity;

  confess(
'The attribute type must be specified during construction or provide a builder subroutine'
  ) if !defined $type;
  $self->{type} = $type;

  return $self;
}

=head2 entry()

  Description : Getter. DBEntry object which was projected

=cut

sub entry {
  my ($self) = @_;
  return $self->{entry};
}

=head2 to()

  Description : Getter. The object instance from which we projected to (normally a Member)

=cut

sub to {
  my ($self) = @_;
  return $self->{to};
}

=head2 to_identity()

  Description : Getter. Percentage identity in the target

=cut

sub to_identity {
  my ($self) = @_;
  return $self->{to_identity};
}

=head2 from()

  Description : Getter. The object instance from which we projected from (normally a Member)

=cut

sub from {
  my ($self) = @_;
  return $self->{from};
}

=head2 from_identity()

  Description : Getter. Percentage identity in the source

=cut

sub from_identity {
  my ($self) = @_;
  return $self->{from_identity};
}

=head2 type()

  Description : Getter. The type of homology which we detected (populated from homology.description)

=cut

sub type {
  my ($self) = @_;
  return $self->{type};
}

1;
