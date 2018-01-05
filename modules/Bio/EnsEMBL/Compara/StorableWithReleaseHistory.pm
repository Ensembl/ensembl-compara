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

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::StorableWithReleaseHistory

=head1 DESCRIPTION

This is a base-class for Compara objects that sits on top of Ensembl's
Storable. It is used for objects that have a "first_release" and a
"last_release", which allows to list the objects that existed at any
given release.

=head1 SYNOPSIS

Getter/setters are:
 - first_release()
 - last_release()

Other methods:
 - is_current()
 - is_in_release()
 - has_been_released()

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::StorableWithReleaseHistory;

use strict;
use warnings;

use Scalar::Util qw(looks_like_number);

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Storable');


=head2 new

  Description: Partial constructor: read "FIRST_RELEASE" and "LAST_RELEASE"
  Exceptions : none
  Caller     : internal
  Status     : Stable

=cut

sub new {
    my $caller = shift @_;
    my $class = ref($caller) || $caller;

    my $self = $class->SUPER::new(@_);       # deal with Storable stuff

    my($first_release, $last_release) =
        rearrange([qw(FIRST_RELEASE LAST_RELEASE)], @_);

    $self->first_release($first_release);
    $self->last_release($last_release);

    return $self;
}


=head2 first_release

  Arg[1]      : Integer (optional)
  Example     : my $first_release = $genome_db->first_release();
  Example     : $genome_db->first_release($first_release);
  Description : Getter/Setter for the first release this object was present in.
                undef means that this object never made it to a release database
  Returntype  : Integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub first_release {
    my $self = shift;
    $self->{'_first_release'} = shift if @_;
    return $self->{'_first_release'};
}


=head2 last_release

  Arg[1]      : Integer (optional)
  Example     : my $last_release = $genome_db->last_release();
  Example     : $genome_db->last_release($last_release);
  Description : Getter/Setter for the last release this GenomeDB was present in.
                undef means that there is no last release known for this object.
  Returntype  : Integer
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub last_release {
    my $self = shift;
    $self->{'_last_release'} = shift if @_;
    return $self->{'_last_release'};
}


=head2 has_been_released

  Example     : my $has_been_released = $object->has_been_released();
  Description : Tells whether the object has ever been released.
  Returntype  : Boolean
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub has_been_released {
    my $self = shift;
    return $self->first_release ? 1 : 0;
}


=head2 is_in_release

  Arg[1]      : Integer: the release number to check this object against
  Example     : my $is_in_release_73 = $gdb->is_in_release(73);
  Description : Tells whether the object existed in that release
  Returntype  : Boolean
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub is_in_release {
    my $self = shift;
    my $release_number = shift;
    looks_like_number($release_number) || throw("A release number must be given (got '$release_number')");
    if ($self->has_been_released) {
        if ($self->first_release > $release_number) {
            return 0;
        } elsif ($self->last_release) {
            return $self->last_release >= $release_number;
        } else {
            return 1;
        }
    } else {
        return 0;
    }
}


=head2 is_current

  Example     : my $is_current = $gdb->is_current();
  Description : Tells whether the object exists in the current version (given by Bio::EnsEMBL::ApiVersion)
  Returntype  : Boolean
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub is_current {
    my $self = shift;
    return $self->is_in_release(software_version());
}


=head2 toString

  Args       : (none)
  Example    : print $species_set->toString()."\n";
  Description: returns a stringified representation of the object
  Returntype : string

=cut

sub toString {
    my $self = shift;

    if ($self->is_current) {
        return '[current]';
    } elsif ($self->has_been_released) {
        return '[retired]';
    } else {
        return '[unreleased]';
    }
}


1;
