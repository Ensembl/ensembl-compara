=head1 LICENSE

Copyright [1999-2014] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

use Bio::EnsEMBL::Utils::Exception qw(throw warning); ## All needed?

use Bio::EnsEMBL::Utils::IO qw/:slurp/;

use Compress::Zlib;

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

=head2 fetch_all_model_ids

  Arg [1]     : (arrayref) Column names to retrieve
  Arg [2]     : (string) (optional) Optional type for the model_ids
  Example     : $model_ids = $hmmProfileAdaptor->fetch_all_model_ids($type)
  Description : Returns an array ref with all the model_ids present in the database
                (possibly pertaining to a defined $type)
  ReturnType  : hashref with the column names and values
  Exceptions  :
  Caller      : General

=cut

sub fetch_all_by_column_names {
    my ($self, $columns_ref, $type) = @_;

    throw ("columns is undefined") unless (defined $columns_ref);
    throw ("columns have to be passed as an array ref") unless (ref $columns_ref eq "ARRAY");

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
    my $node_list = [];

    while (my $rowhash = $sth->fetchrow_hashref) {
        my $node = $self->create_instance_from_rowhash($rowhash);
        push @$node_list, $node;
    }
    return $node_list;
}

sub create_instance_from_rowhash {
    my ($self, $rowhash) = @_;

    my $obj = Bio::EnsEMBL::Compara::HMMProfile->new();
    $self->init_instance_from_rowhash($obj,$rowhash);

    return $obj;
}

sub init_instance_from_rowhash() {
    my ($self, $obj, $rowhash) = @_;

    $obj->model_id($rowhash->{model_id});
    $obj->name($rowhash->{name});
    $obj->type($rowhash->{type});
    # MySQL-style compression -UNCOMPRESS()-
    # The first 4 bytes are the length of the text in little-endian
    $obj->profile( Compress::Zlib::uncompress( substr($rowhash->{compressed_profile},4) ) );
    $obj->consensus($rowhash->{consensus});

    return $obj;
}

sub store {
    my ($self, $obj) = @_;

    unless(UNIVERSAL::isa($obj, 'Bio::EnsEMBL::Compara::HMMProfile')) {
        throw("set arg must be a [Bio::EnsEMBL::Compara::HMMProfile] not a $obj");
    }



    # MySQL-style compression -COMPRESS()-
    # The first 4 bytes are the length of the text in little-endian
    my $compressed_profile = pack('V', length($obj->profile())).Compress::Zlib::compress($obj->profile(), Z_BEST_COMPRESSION);

    my $sql = "REPLACE INTO hmm_profile(model_id, name, type, compressed_profile, consensus) VALUES (?,?,?,?,?)";
    my $sth = $self->prepare($sql);

    $sth->execute($obj->model_id(), $obj->name(), $obj->type(), $compressed_profile, $obj->consensus());

    return;
}


1;
