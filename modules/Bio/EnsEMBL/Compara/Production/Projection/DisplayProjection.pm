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

Bio::EnsEMBL::Compara::Production::Projection::DisplayProjection

=head1 DESCRIPTION

Data transfer object for holding the results of a projection.

=head1 AUTHOR

Andy Yates (ayatesatebiacuk)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the dev mailing list: http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::Projection::DisplayProjection;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use base qw(Bio::EnsEMBL::Compara::Production::Projection::Projection);

=head2 new()

  Arg[-total]         : required; Total number of genes the target projected to
  Arg[-current_index] : required; Current position in the total
  Arg[..]             : See parent object for more information about other params
  Description         : New method used for a new instance of the given object. 
                        Required fields are indicated accordingly. Fields are 
                        specified using the Arguments syntax (case insensitive).

=cut

sub new {
  my ( $class, @args ) = @_;
  my $self = $class->SUPER::new(@args);
  my ( $total, $current_index ) = rearrange( [qw(total current_index )], @args );

  confess(
'The attribute total must be specified during construction'
  ) if !defined $total;
  $self->{total} = $total;

  confess(
'The attribute type must be specified during construction or provide a builder subroutine'
  ) if !defined $current_index;
  $self->{current_index} = $current_index;

  return $self;
}

=head2 total()

The current total of genes the target was mapped to (applies to 1:m) 
relationships

=cut

sub total {
  my ($self) = @_;
  return $self->{total};
}

=head2 current_index()

Current position of our iteration through the total amount of genes this
target is related to

=cut

sub current_index {
  my ($self) = @_;
  return $self->{current_index};
}

=head2 ignore()

Attribute which can only be set after construction since it is used
to optionally allow us to ignore an existing projection during a post
filtering stage.

=cut

sub ignore {
  my ($self, $ignore) = @_;
  $self->{ignore} = $ignore if defined $ignore;
  return $self->{ignore};
}


1;