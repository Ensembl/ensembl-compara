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

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 DESCRIPTION

This modules contains a few additional methods to test the type of
of scalars

=head1 METHODS

=cut

package Bio::EnsEMBL::Compara::Utils::Scalar;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Utils::Scalar;

use Scalar::Util qw(blessed looks_like_number);

use base qw(Exporter);

our %EXPORT_TAGS;
our @EXPORT_OK;

@EXPORT_OK = qw(
    assert_ref_or_dbID
    split_list
);
%EXPORT_TAGS = (
  assert  => [qw(assert_ref_or_dbID)],
  argument => [qw(split_list)],
  all     => [@EXPORT_OK]
);



=head2 assert_ref_or_dbID

  Arg [1]     : The reference to check
  Arg [2]     : The type we expect
  Arg [3]     : The attribute name you are asserting; not required but allows
                for more useful error messages to be generated. Defaults to
                C<-Unknown->.
  Description : A subroutine which checks to see if the given object/ref is
                what you expect or a potential dbID. This behaves in an
                identical manner as C<check_ref()> does except this will raise
                exceptions when the values do not match rather than returning
                a boolean indicating the situation.

                Undefs cause exception circumstances.
                
                You can turn assertions off by using the global variable
                $Bio::EnsEMBL::Utils::Scalar::ASSERTIONS = 0
  Returntype  : Boolean; true if we managed to get to the return
  Example     : assert_ref_or_dbID(90, 'Bio::EnsEMBL::Compara::GenomeDB');
  Exceptions  : If the expected type was not set and if the given reference
                was not assignable to the expected value
  Status      : Stable

=cut


sub assert_ref_or_dbID {
    my ($ref, $expected, $attribute_name) = @_;

    return 1 unless $Bio::EnsEMBL::Utils::Scalar::ASSERTIONS;
    $attribute_name ||= '-Unknown-';

    throw('No expected type given') if ! defined $expected;
    throw("The given reference for attribute $attribute_name was undef. Expected '$expected'") unless defined $ref;

    my $class = ref($ref);
    if ($class) {
        if (blessed($ref)) {
            throw("${attribute_name}'s type '${class}' is not an ISA of '${expected}'") if ! $ref->isa($expected);
        } else {
            throw("$attribute_name was expected to be '${expected}' but was '${class}'") if $expected ne $class;
        }
    } elsif (looks_like_number($ref)) {
        if($ref != int($ref)) {
            throw "Attribute $attribute_name was a number ($ref) but not an Integer";
        }
    } else {
        throw("Asking for the type of the attribute $attribute_name produced no type; check it is a reference. Expected '$expected'");
    }
    return 1;
}


=head2 split_list

  Arg[1]      : Arrayref $list
  Arg[2]      : Integer $max_size
  Example     : split_list($node_ids, 300);
  Description : Split a list into lists that are not longer than $max_size elements
  Returntype  : Arrayref of arrayrefs
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub split_list {
    my ($id_list, $max_size) = @_;
    my @id_list = @$id_list;
    my @list_of_lists;
    while (@id_list) {
        my @ids;
        if (scalar(@id_list) > $max_size) {
            @ids = splice( @id_list, 0, $max_size );
        } else {
            @ids     = @id_list;
            @id_list = ();
        }
        push @list_of_lists, \@ids;
    }
    return \@list_of_lists;
}


1;
