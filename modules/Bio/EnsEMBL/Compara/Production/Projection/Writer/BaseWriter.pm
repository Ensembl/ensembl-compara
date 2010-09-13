#
# You may distribute this module under the same terms as perl itself
#

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter

=head1 DESCRIPTION

Base class for working with writers

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: dev@ensembl.org

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
