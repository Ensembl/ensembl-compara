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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::Method

=head1 SYNOPSIS

Attributes:
  - dbID()
  - type()
  - class()

I/O:
  - toString()

=head1 DESCRIPTION

Method is a data object that roughly represents the type of pipeline run and the corresponding type of data generated.

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::Method;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);

use base ('Bio::EnsEMBL::Storable');        # inherit dbID(), adaptor() and new() methods


# Used to name the MLSSs and for Web
our %PLAIN_TEXT_DESCRIPTIONS = (
    'BLASTZ_NET'            => 'BlastZ',
    'LASTZ_NET'             => 'LastZ',
    'TRANSLATED_BLAT_NET'   => 'Translated Blat',
    'EPO'                   => 'EPO',
    'EPO_LOW_COVERAGE'      => 'EPO-LOW-COVERAGE',
    'PECAN'                 => 'Mercator-Pecan',
    'CACTUS_HAL'            => 'Cactus',
    'SYNTENY'               => 'Synteny',
);


=head2 new

  Arg [..]   : Takes a set of named arguments
  Example    : my $my_method = Bio::EnsEMBL::Compara::Method->new(
                                -dbID            => $dbID,
                                -type            => 'SYNTENY',
                                -class           => 'SyntenyRegion.synteny',
                                -adaptor         => $method_adaptor );
  Description: Creates a new Method object
  Returntype : Bio::EnsEMBL::Compara::Method

=cut


sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);

    my ($type, $mclass) =
        rearrange([qw(TYPE CLASS)], @_);

    $self->type($type)        if (defined ($type));
    $self->class($mclass)     if (defined ($mclass));

    return $self;
}


=head2 type

  Arg [1]    : (opt.) string type
  Example    : my $type = $method->type();
  Example    : $method->type('LASTZ_NET');
  Description: Getter/Setter for the type of this method
  Returntype : string type

=cut

sub type {
    my $self = shift;
    my $type = shift;

    $self->{'_type'} = $type if ($type);

    return $self->{'_type'};
}


=head2 class

  Arg [1]    : (opt.) string class
  Example    : my $class = $method->class();
  Example    : $method->class('GenomicAlignBlock.pairwise_alignment');
  Description: Getter/Setter for the class of this method
  Returntype : string class

=cut

sub class {
    my $self = shift;
    my $class = shift;

    $self->{'_class'} = $class if ($class);

    return $self->{'_class'};
}


=head2 toString

  Args       : (none)
  Example    : print $method->toString()."\n";
  Description: returns a stringified representation of the method
  Returntype : string

=cut

sub toString {
    my $self = shift;

    return "Method dbID=".($self->dbID || '?')." '".$self->type."', class='".$self->class."'";
}

1;

