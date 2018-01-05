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

Bio::EnsEMBL::Compara::Production::Projection::Writer::MultipleWriter

=head1 DESCRIPTION

A decorator which delegates to the writers given at construction time
and loops through each writer handing off a Projection.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

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
