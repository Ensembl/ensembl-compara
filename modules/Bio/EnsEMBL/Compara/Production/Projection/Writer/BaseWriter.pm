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

Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter

=head1 DESCRIPTION

Base class for working with writers

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);


=head2 new()

  Arg[-projections] : required; 
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = bless( {}, ref($class) || $class );
  my ( $projections, ) = rearrange( [qw(projections )], @args );

  assert_ref( $projections, 'ARRAY' );
  confess(
'The attribute projections must be specified during construction or provide a builder subroutine'
  ) if !defined $projections;
  $self->{projections} = $projections if defined $projections;

  return $self;
}

=head2 projections()

  Description : Getter. 

=cut

sub projections {
  my ($self) = @_;
  return $self->{projections};
}

=head2 write()

The subroutine we call in order to write projection data out

=cut

sub write {
  my ($self) = @_;
  foreach my $p (@{$self->projections()}) {
    $self->write_projection($p);
  }
}

=head2 write_projection()

The subroutine we call in order to write a single projection out 

=cut

sub write_projection {
  my ($self, $projection) = @_;
  throw('Not overriden in the implementing class');
}

1;
