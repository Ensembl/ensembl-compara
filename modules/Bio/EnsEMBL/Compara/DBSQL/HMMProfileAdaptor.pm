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

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::HMMProfileAdaptor

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::DBSQL::HMMProfileAdaptor;

use strict;
use warnings;

use Data::Dumper;

use Bio::EnsEMBL::Compara::HMMProfile;
use Bio::EnsEMBL::Compara::Utils::Compress;

use Bio::EnsEMBL::Utils::Exception qw(throw warning); ## All needed?
use Bio::EnsEMBL::Utils::Scalar qw(assert_ref);

use DBI qw(:sql_types);
use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


=head2 fetch_all_by_type

  Arg [1]       : (string) The database type for a series of hmm_profiles
  Example       : $profiles = $hmmProfileAdaptor->fetch_all_by_type($type);
  Description   : Returns a HMMProfile object for the given name
  ReturnType    : Bio::EnsEMBL::Compara::HMMProfile
  Exceptions    : If $type is not defined
  Caller        : General

=cut

sub fetch_all_by_type {
    my ($self, $type) = @_;

    throw ("type is undefined") unless (defined $type);

    my $constraint = 'h.type = ?';
    $self->bind_param_generic_fetch($type, SQL_VARCHAR);
    return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_model_id_type

  Arg [1]       : The database model_id for the hmm_profile/s
  Arg [2]       : (optional) The type of the hmm_profile to retrieve
  Example       : $profiles = $hmmProfileAdaptor->fetch_all_by_model_id_type($model_id);
  Description   : Returns the HMMProfile/s object/s for the given model_id
  ReturnType    : Arrayref of Bio::EnsEMBL::Compara::HMMProfile's
  Exceptions    : If $model_id is not defined
  Caller        : General

=cut

sub fetch_all_by_model_id_type {
    my ($self, $model_id, $type) = @_;

    throw ("model_id is undefined") unless (defined $model_id);

    my $constraint = 'h.model_id = ?';
    $self->bind_param_generic_fetch($model_id, SQL_VARCHAR);

    if (defined $type) {
        $constraint .= ' AND h.type = ?';
        $self->bind_param_generic_fetch($type, SQL_VARCHAR);
    }

    return $self->generic_fetch($constraint);
}


=head2 fetch_all_by_name_type

  Arg [1]       : The database name for the hmm_profile/s
  Arg [2]       : (optional) The type of the hmm_profile to retrieve
  Example       : $profiles = $hmmProfileAdaptor->fetch_all_by_name($name);
  Description   : Returns the HMMProfile/s object/s for the given name
  ReturnType    : Arrayref of Bio::EnsEMBL::Compara::HMMProfile's
  Exceptions    : If $name is not defined
  Caller        : General

=cut

sub fetch_all_by_name_type {
    my ($self, $name, $type) = @_;

    throw ("name is undefined") unless (defined $name);

    my $constraint = 'h.name = ?';
    $self->bind_param_generic_fetch($name, SQL_VARCHAR);

    if (defined $type) {
        $constraint .= ' AND h.type = ?';
        $self->bind_param_generic_fetch($type, SQL_VARCHAR);
    }

    return $self->generic_fetch($constraint);
}

=head2 fetch_all_by_column_names

  Arg [1]     : (arrayref) Column names to retrieve
  Arg [2]     : (string) (optional) Optional type for the model_ids
  Example     : $model_ids = $hmmProfileAdaptor->fetch_all_by_column_names(['model_id', 'name'],'infernal');
  Description : Returns an array ref with all the model_ids present in the database
                (possibly pertaining to a defined $type)
  ReturnType  : hashref with the column names and values
  Exceptions  :
  Caller      : General

=cut

sub fetch_all_by_column_names {
    my ($self, $columns_ref, $type) = @_;

    throw ("columns is undefined") unless (defined $columns_ref);
    assert_ref($columns_ref, 'ARRAY', 'columns_ref');

    my $columns = join ",", @$columns_ref;

    my $constraint = "";
    if (defined $type) {
        $constraint = " WHERE type = '$type'";
    }

    my $sth = $self->prepare("SELECT $columns FROM hmm_profile" . $constraint);
    $sth->execute();
    my $id_list = $sth->fetchall_arrayref();
    $sth->finish;

    return $id_list;
}

###############################
#
# Subclass override methods
#
###############################

sub _tables {
    return (['hmm_profile', 'h']);
}

sub _columns {
    return ( 'h.model_id',
             'h.name',
             'type',
             'compressed_profile',
             'consensus',
           );
}

sub _objs_from_sth {
    my ($self, $sth) = @_;

    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::HMMProfile', [
            '_model_id',
            '_name',
            '_type',
            undef,
            '_consensus',
        ], sub {
            my $a = shift;
            return {
                '_profile'  => Bio::EnsEMBL::Compara::Utils::Compress::uncompress_from_mysql($a->[3]),
            };
        });
}


sub store {
    my ($self, $obj) = @_;

    assert_ref($obj, 'Bio::EnsEMBL::Compara::HMMProfile', 'obj');

    my $compressed_profile = Bio::EnsEMBL::Compara::Utils::Compress::compress_to_mysql($obj->profile());

    my $sql = "REPLACE INTO hmm_profile(model_id, name, type, compressed_profile, consensus) VALUES (?,?,?,?,?)";
    my $sth = $self->prepare($sql);

    $sth->execute($obj->model_id(), $obj->name(), $obj->type(), $compressed_profile, $obj->consensus());

    return;
}


1;
