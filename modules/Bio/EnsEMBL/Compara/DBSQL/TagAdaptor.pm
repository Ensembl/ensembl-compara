=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

   http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::TagAdaptor

=head1 DESCRIPTION

Generic adaptor that gives a database backend for tags / attributes (to
use with Bio::EnsEMBL::Compara::Taggable). There can be any number of
values for tags, but at most one for each attribute.

=head1 MAINTAINER

$Author$

=head VERSION

$Revision$

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::TagAdaptor;

use strict;

#use Data::Dumper;

=head2 _tag_capabilities

  Description: returns the tag/attributes capabilities for the object. The
               return value is an array with 4 entries:
                - the name of the table to store tag
                - the name of the table to store attribute
                - the name of the key column in the tables
                - the name of the perl method to have the key value
  Arg [1]    : <scalar> reference object
  Example    : return ("species_set_tag", undef, "species_set_id", "dbID");
  Returntype : Array of 4 entries
  Exceptions : none
  Caller     : internal

=cut

sub _tag_capabilities {
    my ($self, $object) = @_;

    die "_tag_capabilities for $object must be redefined in $self (or a subclass)\n";
    #return ("protein_tree_tag", "protein_tree_attr", "node_id", "node_id");
}


=head2 _load_tagvalues

  Description: retrieves all the tags and attributes from the database and
               calls add_tag to store them in the PERL hash
  Arg [1]    : <scalar> reference object
  Example    : $genetree_adaptor->_load_tagvalues($tree);
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _load_tagvalues {
    my $self = shift;
    my $object = shift;

    #print STDERR "CALL _load_tagvalues $self/$object\n";
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities($object);
    #print STDERR "_load_tagvalues = $db_tagtable/$db_attrtable\n";
 
    # Tags (multiple values are allowed)
    my $sth = $self->prepare("SELECT tag, value FROM $db_tagtable WHERE $db_keyname=?");
    $sth->execute($object->$perl_keyname);
    while (my ($tag, $value) = $sth->fetchrow_array()) {
        $object->add_tag($tag, $value, 1);
    }
    $sth->finish;
   
    # Attributes ?
    if (defined $db_attrtable) {
        # Attributes (multiple values are forbidden)
        $sth = $self->prepare("SELECT * FROM $db_attrtable WHERE $db_keyname=?");
        $sth->execute($object->$perl_keyname);
        # Retrieve data
        my $attrs = $sth->fetchrow_hashref();
        if (defined $attrs) {
            foreach my $key (keys %$attrs) {
                if (($key ne $db_keyname) and defined(${$attrs}{$key})) {
                    $object->add_tag($key, ${$attrs}{$key});
                }
            }
        }
        $sth->finish;
    }
}


=head2 _read_attr_list

  Description: retrieves the column names of an attribute table
  Arg [1]    : <scalar> table name
  Example    : $genetree_adaptor->_read_attr_list('protein_tree_node_attr');
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _read_attr_list {
    my $self = shift;
    my $db_attrtable = shift;

    # No table provided
    return if not defined $db_attrtable;
    # Column names already loaded
    return if exists $self->{"_attr_list_$db_attrtable"};

    $self->{"_attr_list_$db_attrtable"} = {};
    eval {
        my $sth = $self->dbc->db_handle->column_info(undef, undef, $db_attrtable, '%');
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref()) {
            ${$self->{"_attr_list_$db_attrtable"}}{${$row}{'COLUMN_NAME'}} = 1;
            #print STDERR "adding ", ${$row}{'COLUMN_NAME'}, " to the attribute list $db_attrtable of adaptor $self\n";
        }
        $sth->finish;
    };
    if ($@) {
        warn "$db_attrtable not available in this database\n";
    }
    #print STDERR "adaptor $self: ", Dumper($self);
}


=head2 _store_tagvalue

  Arg [1]    : <scalar> object
  Arg [2]    : <string> tag
  Arg [3]    : <string> value
  Arg [4]    : (optional) <int> allows overloading the tag with different values
               default is 0 (no overloading allowed, one tag points to one value)
  Example    : $speciesset_adaptor->_store_tagvalue($species_set, "colour", "red");
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _store_tagvalue {
    my $self = shift;
    my $object = shift;
    my $tag = shift;
    my $value = shift;
    my $allow_overloading = shift;
    
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities($object);
    $self->_read_attr_list($db_attrtable);
    #print STDERR "CALL _store_tagvalue $self/$object/$tag: ", Dumper($self->{"_attr_list_$db_attrtable"});
  
    if (exists $self->{"_attr_list_$db_attrtable"}->{$tag}) {
        #print STDERR "attr\n";
        warn "Trying to overload the value of attribute '$tag' ! This is not allowed for $self\n" if $allow_overloading;
        # It is an attribute
        my $sth = $self->prepare("INSERT IGNORE INTO $db_attrtable ($db_keyname) VALUES (?)");
        $sth->execute($object->$perl_keyname);
        $sth->finish;
        $sth = $self->prepare("UPDATE $db_attrtable SET $tag=? WHERE $db_keyname=?");
        $sth->execute($value, $object->$perl_keyname);
        $sth->finish;

    } elsif ($allow_overloading) {
        #print STDERR "tag+\n";
        # It is a tag with multiple values allowed
        my $sth = $self->prepare("INSERT IGNORE INTO $db_tagtable ($db_keyname, tag, value) VALUES (?, ?, ?)");
        $sth->execute($object->$perl_keyname, $tag, $value);
        $sth->finish;
    } else {
        #print STDERR "tag\n";
        # It is a tag with only one value allowed
        my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=?");
        $sth->execute($object->$perl_keyname, $tag);
        $sth->finish;
        $sth = $self->prepare("INSERT INTO $db_tagtable ($db_keyname, tag, value) VALUES (?, ?, ?)");
        $sth->execute($object->$perl_keyname, $tag, $value);
        $sth->finish;
    }
}


=head2 _delete_tagvalue

  Description: removes a tag from the database
  Arg [1]    : <scalar> object
  Arg [2]    : <string> tag
  Arg [3]    : (optional) <string> value
  Example    : $speciesset_adaptor->_delete_tagvalue($species_set, "colour");
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _delete_tagvalue {
    my $self = shift;
    my $object = shift;
    my $tag = shift;
    my $value = shift;
    
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities($object);
    $self->_read_attr_list($db_attrtable);
  
    if (exists $self->{"_attr_list_$db_attrtable"}->{$tag}) {
        # It is an attribute
        my $sth = $self->prepare("UPDATE $db_attrtable SET $tag=NULL WHERE $db_keyname=?");
        $sth->execute($object->$perl_keyname);
        $sth->finish;

    } else {
        # It is a tag
        if (defined $value) {
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=? AND value=?");
            $sth->execute($object->$perl_keyname, $tag, $value);
            $sth->finish;
        } else {
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=?");
            $sth->execute($object->$perl_keyname, $tag);
            $sth->finish;
        }
    }
}

1;
