=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=cut

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::MethodAdaptor

=head1 SYNOPSIS

    my $method_adaptor  = $db_adaptor->get_MethodAdaptor();

    my $all_methods     = $method_adaptor->fetch_all();             # inherited method

    my $method_by_id    = $method_adaptor->fetch_by_dbID( 301 );    # inherited method

    my $bzn_method      = $method_adaptor->fetch_by_type('BLASTZ_NET');
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

use Bio::EnsEMBL::Compara::Method;
use base ('Bio::EnsEMBL::Compara::DBSQL::BaseAdaptor');


sub object_class {
    return 'Bio::EnsEMBL::Compara::Method';
}


sub _tables {

    return (['method_link','m'])
}


sub _columns {

        #warning _objs_from_sth implementation depends on ordering
    return qw (
        m.method_link_id
        m.type
        m.class
    );
}


sub _objs_from_sth {
    my ($self, $sth) = @_;

    my @methods = ();

    while ( my ($dbID, $type, $class) = $sth->fetchrow() ) {
        push @methods, Bio::EnsEMBL::Compara::Method->new(
            -dbID => $dbID,
            -type => $type,
            -class => $class,
            -adaptor => $self,
        );
    }

    return \@methods;
}


=head2 fetch_by_type

  Arg [1]     : string $type
  Example     : my $bzn_method = $method_adaptor->fetch_by_type('BLASTZ_NET');
  Description : Fetches the Method object(s) with a given type
  Returntype  : Bio::EnsEMBL::Compara::Method arrayref

=cut

sub fetch_by_type {
    my ($self, $type) = @_;

    my ($method) = @{ $self->generic_fetch( "m.type = '$type'" ) };
    return $method;
}


=head2 fetch_all_by_class_pattern

  Arg [1]     : string $class_pattern
  Example     : my @tree_methods = @{ $method_adaptor->fetch_by_class_pattern('%tree_node') };
  Description : Fetches the Method object(s) with a class matching the given pattern
  Returntype  : Bio::EnsEMBL::Compara::Method arrayref

=cut

sub fetch_all_by_class_pattern {
    my ($self, $class_pattern) = @_;

    return $self->generic_fetch( "m.class LIKE '$class_pattern'" );
}


sub synchronise {    # return autoinc_id/undef
    my ( $self, $method ) = @_;

    unless(defined $method && ref $method && $method->isa('Bio::EnsEMBL::Compara::Method') ) {
        throw("The argument to synchronise() must be a Method, not [$method]");
    }

    my $dbID            = $method->dbID();

    my $dbid_check      = $dbID ? "method_link_id=$dbID" : 0;
    my $unique_data_check   = "( type = '".$method->type."' )";

    my $sth = $self->prepare( "SELECT method_link_id, $unique_data_check FROM method_link WHERE $dbid_check OR $unique_data_check" );
    $sth->execute();

    my $vectors = $sth->fetchall_arrayref();
    $sth->finish();

    if( scalar(@$vectors) >= 2 ) {
        die "Attempting to store an object with dbID=$dbID experienced partial collisions on both dbID and data in the db";
    } elsif( scalar(@$vectors) == 1 ) {
        my ($stored_dbID, $unique_key_check) = @{$vectors->[0]};

        if(!$unique_key_check) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same dbID but different data";
        } elsif($dbID and ($dbID!=$stored_dbID)) {
            die "Attempting to store an object with dbID=$dbID experienced a collision with same data but different dbID ($stored_dbID)";
        } else {
            return $self->attach( $method, $stored_dbID);
        }
    } else {
        return undef;   # not found, safe to insert
    }
}

    
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

    unless($self->synchronise($method)) {
        my $sql = 'INSERT INTO method_link (method_link_id, type, class) VALUES (?, ?, ?)';
        my $sth = $self->prepare( $sql ) or die "Could not prepare $sql";

        my $return_code = $sth->execute( $method->dbID(), $method->type(), $method->class() )
                # using $return_code in boolean context allows to skip the value '0E0' ('no rows affected') that Perl treats as zero but regards as true:
            or die "Could not store ".$method->toString;

        if($return_code > 0) {     # <--- for the same reason we have to be explicitly numeric here
            $self->attach($method, $self->dbc->db_handle->last_insert_id(undef, undef, 'method_link', 'method_link_id') );
            $sth->finish();
        }
    }
    return $method;
}


1;
