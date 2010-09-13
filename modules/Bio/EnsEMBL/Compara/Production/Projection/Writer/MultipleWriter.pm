#
# You may distribute this module under the same terms as perl itself
#

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Production::Projection::Writer::MultipleWriter

=head1 DESCRIPTION

A decorator which delegates to the writers given at construction time
and loops through each writer handing off a Projection.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: dev@ensembl.org

=cut

package Bio::EnsEMBL::Compara::Production::Projection::Writer::MultipleWriter;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base qw(Bio::EnsEMBL::Compara::Production::Projection::Writer::BaseWriter);

=head2 new()

  Arg[-writers] : required; ARRAY of the writers to delegate to 1 by 1
  Description : New method used for a new instance of the given object. 
                Required fields are indicated accordingly. Fields are specified
                using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $writers, ) = rearrange( [qw(writers )], @args );

  assert_ref( $writers, 'ARRAY' );
  confess(
'The attribute writers must be specified during construction or provide a builder subroutine'
  ) if !defined $writers;
  $self->{writers} = $writers if defined $writers;

  return $self;
}

=head2 writers()

  Description : Getter. 

=cut

sub writers {
  my ($self) = @_;
  return $self->{writers};
}

=head2 write_projection() 

Loops through the writers given at construction and will run the 
write_projection() method for each of those.

=cut

sub write_projection {
  my ($self, $p) = @_;
  foreach my $w (@{$self->writers()}) {
    $w->write_projection($p);
  }
  return;
}

1;
