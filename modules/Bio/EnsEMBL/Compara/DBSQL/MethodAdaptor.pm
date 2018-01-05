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

Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor

=head1 SYNOPSIS

    my $method_adaptor  = $db_adaptor->get_MethodAdaptor();

    my $all_methods     = $method_adaptor->fetch_all();             # inherited method

    my $method_by_id    = $method_adaptor->fetch_by_dbID( 301 );    # inherited method

    my $bzn_method      = $method_adaptor->fetch_by_type('LASTZ_NET');
    my $fam_method      = $method_adaptor->fetch_by_type('FAMILY');

    foreach my $tree_method (@{ $method_adaptor->fetch_by_class_pattern('%tree_node')}) {
        print $tree_method->toString."\n";
    }

    $method_adaptor->store( $my_method );

=head1 DESCRIPTION

Database adaptor to store and fetch Method objects

=head1 METHODS

=cut


package Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor;

use strict;
use warnings;

use Bio::EnsEMBL::Compara::Method;
use base ('Bio::EnsEMBL::Compara::DBSQL::BaseFullCacheAdaptor');



#############################################################
# Implements Bio::EnsEMBL::Compara::RunnableDB::ObjectStore #
#############################################################

sub object_class {
    return 'Bio::EnsEMBL::Compara::Method';
}




########################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor #
########################################################

sub _tables {
    return (['method_link','m'])
}


sub _columns {
    # warning _objs_from_sth implementation depends on ordering
    return qw (
        m.method_link_id
        m.type
        m.class
    );
}

sub _unique_attributes {
    return qw(
        type
    );
}


sub _objs_from_sth {
    my ($self, $sth) = @_;

    return $self->generic_objs_from_sth($sth, 'Bio::EnsEMBL::Compara::Method', [
            'dbID',
            '_type',
            '_class',
        ] );
}



###################
# fetch_* methods #
###################

=head2 fetch_by_type

  Arg [1]     : string $type
  Example     : my $bzn_method = $method_adaptor->fetch_by_type('LASTZ_NET');
  Description : Fetches the Method object(s) with a given type
  Returntype  : Bio::EnsEMBL::Compara::Method

=cut

sub fetch_by_type {
    my ($self, $type) = @_;

    return $self->_id_cache->get_by_additional_lookup('type', uc $type);
}


=head2 fetch_all_by_class_pattern

  Arg [1]     : string $class_pattern
  Example     : my @tree_methods = @{ $method_adaptor->fetch_by_class_pattern('.*tree_node') };
  Description : Fetches the Method object(s) with a class matching the given pattern
  Returntype  : Bio::EnsEMBL::Compara::Method arrayref

=cut

# TODO used ??

sub fetch_all_by_class_pattern {
    my ($self, $class_pattern) = @_;

    my @matched_methods;
    foreach my $method (@{$self->fetch_all}) {
        push @matched_methods, $method if $method->class =~ m/$class_pattern/;
    }
    return \@matched_methods
}



##################
# store* methods #
##################

=head2 store

  Arg [1]     : Bio::EnsEMBL::Compara::Method $method
  Example     : $method_adaptor->store( $my_method );
  Description : Stores the Method object in the database unless it has been stored already; updates the dbID of the object.
  Returntype  : Bio::EnsEMBL::Compara::Method

=cut

sub store {
    my ($self, $method) = @_;

    if(my $reference_dba = $self->db->reference_dba()) {
        $reference_dba->get_MethodAdaptor->store( $method );
    }
    if (my $other_method = $self->_synchronise($method)) {

        $self->generic_update('method_link',
            {
                'type'              => $method->type,
                'class'             => $method->class,
            }, {
                'method_link_id'    => $method->dbID,
            } );

        $self->_id_cache->remove($method->dbID);

    } else {

        my $dbID = $self->generic_insert('method_link', {
                'method_link_id'    => $method->dbID,
                'type'              => $method->type,
                'class'             => $method->class,
            }, 'method_link_id');
        $self->attach($method, $dbID);
    }
    
    $self->_id_cache->put($method->dbID, $method);
    return $method;
}


############################################################
# Implements Bio::EnsEMBL::Compara::DBSQL::BaseFullAdaptor #
############################################################


sub _build_id_cache {
    my $self = shift;
    return Bio::EnsEMBL::Compara::DBSQL::Cache::Method->new($self);
}


package Bio::EnsEMBL::Compara::DBSQL::Cache::Method;


use base qw/Bio::EnsEMBL::DBSQL::Support::FullIdCache/;
use strict;
use warnings;

sub support_additional_lookups {
    return 1;
}

sub compute_keys {
    my ($self, $method) = @_;
    return {
        type => uc $method->type(),
    }
}


1;
