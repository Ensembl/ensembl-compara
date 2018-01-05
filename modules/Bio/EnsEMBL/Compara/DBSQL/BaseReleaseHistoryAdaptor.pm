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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor

=head1 DESCRIPTION

Base class for the adaptors that have the "first_release" and "last_release" columns.


=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::BaseRelationAdaptor
  +- Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor

=head1 AUTHORSHIP

Ensembl Team. Individual contributions can be found in the GIT log.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with an underscore (_)

=cut

package Bio::EnsEMBL::Compara::DBSQL::BaseReleaseHistoryAdaptor;

use strict;
use warnings;

use DBI qw(:sql_types);
use List::Util qw(max);

use Bio::EnsEMBL::ApiVersion;
use Bio::EnsEMBL::Utils::Exception;

use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor');


=head2 fetch_all_current

  Example     : $object_name->fetch_all_current();
  Description : Returns all the objects that are in the current release
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::StorableWithReleaseHistory
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_current {
    my $self = shift;
    return $self->fetch_all_by_release(software_version());    
}


=head2 fetch_all_by_release

  Arg[0]      : integer $release_number
  Example     : $object_name->fetch_all_by_release(76);
  Description : Returns all the objects present in this release of Ensembl
  Returntype  : Arrayref of Bio::EnsEMBL::Compara::StorableWithReleaseHistory
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub fetch_all_by_release {
    my $self = shift;
    my $release_number = shift || throw("A release number must be given");
    return [grep {$_->is_in_release($release_number)} $self->_id_cache->cached_values()];
}


=head2 update_first_last_release

  Arg[1]      : Bio::EnsEMBL::Compara::StorableWithReleaseHistory
  Example     : $mlss_adaptor->update_first_last_release($mlss);
  Description : Generic method to update first/last_release in the database given the current values of the object
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub update_first_last_release {
    my ($self, $object) = @_;
    my $table= join(" ", @{($self->_tables)[0]});
    my $column = ($self->_columns)[0];
    my $sql = sprintf('UPDATE %s SET first_release = ?, last_release = ? WHERE %s = ?', $table, $column);
    $self->dbc->do($sql, undef, $object->first_release, $object->last_release, $object->dbID);
    $self->_id_cache->put($object->dbID, $object);
}


=head2 retire_object

  Arg[1]      : Bio::EnsEMBL::Compara::StorableWithReleaseHistory
  Example     : $genome_db_adaptor->retire_object($mlss);
  Description : Mark the object as retired, i.e. with a last_release older than the current version
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub retire_object {
    my ($self, $object) = @_;
    return if not $object->is_current;
    if ($object->first_release >= software_version()) {
        # The object was scheduled for release but is now cancelled
        $object->first_release(undef);
    } else {
        $object->last_release(software_version() - 1);
    }
    return $self->update_first_last_release($object);
}


=head2 make_object_current

  Arg[1]      : Bio::EnsEMBL::Compara::StorableWithReleaseHistory
  Example     : $genome_db_adaptor->make_object_current($mlss);
  Description : Mark the object as current, i.e. with a defined first_release and an undefined last_release
  Returntype  : none
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub make_object_current {
    my ($self, $object) = @_;
    return if $object->is_current;
    $object->first_release(software_version()) unless $object->first_release;   # The object may already be current
    $object->last_release(undef);
    return $self->update_first_last_release($object);
}

=head2 _find_most_recent

  Example     : my $latest_gdb = $self->_find_most_recent($many_human_gdbs);
  Description : Sorts all the given objects according to their age (current and most recent first), and returns the most revent one
  Returntype  : StorableWithReleaseHistory
  Exceptions  : If there are ties
  Caller      : subclasses of BaseReleaseHistoryAdaptor
  Status      : Stable

=cut

sub _find_most_recent {
    my ($self, $object) = @_;

    return undef unless scalar(@$object);

    my $score = sub {
        my $g = shift;
        # Sort criteria
        #  1. is_current
        #  2. highest last_release
        #  3. highest first_release
        # NOTE: this formula works as long as the release number is < 10000
        my $unit = 10000;
        return ((($g->is_current ? 1 : 0) * $unit + ($g->last_release || 0)) * $unit + ($g->first_release || 0));
    };

    my $best_score = max map {$score->($_)} @$object;
    my @ties = grep {$score->($_) == $best_score} @$object;

    if (scalar(@ties) == 1) {
        return $ties[0];
    }
    # NOTE: Assume the objects have a "name" attribute, which is not defined in StorableWithReleaseHistory
    throw(sprintf("Could not find the best %s named '%s'. There are several objects equally recent: %s\n", ref($ties[0]), $ties[0]->name, join(",", map {$_->dbID} @ties)));
}


1;
