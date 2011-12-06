=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
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

=head1 SYNOPSIS

=head1 DESCRIPTION

TagAdaptor - Generic adaptor that gives a database backend for tags / attributes

=head1 INHERITANCE TREE

  Bio::EnsEMBL::Compara::DBSQL::TagAdaptor

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::TagAdaptor;

use strict;


sub _tag_capabilities {
    die "_tag_capabilities must be redefined in the subclass\n";
    #return ("protein_tree_tag", "protein_tree_attr", "node_id", "node_id");
}


###################################
#
# tagging
#
###################################

sub _load_tagvalues {
    my $self = shift;
    my $object = shift;

    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities();
    
    # Updates the list of attribute names
    if (not exists $self->{'_attr_list'}) {
        $self->{'_attr_list'} = {};
        eval {
            my $sth = $self->dbc->db_handle->column_info(undef, undef, $db_attrtable, '%');
            $sth->execute();
            while (my $row = $sth->fetchrow_hashref()) {
                ${$self->{'_attr_list'}}{${$row}{'COLUMN_NAME'}} = 1;
            }
            $sth->finish;
        };
        if ($@) {
            warn "$db_attrtable not available in this database\n";
        }
    }

    # Tags (multiple values are allowed)
    my $sth = $self->prepare("SELECT tag, value FROM $db_tagtable WHERE $db_keyname=?");
    $sth->execute($object->$perl_keyname);
    while (my ($tag, $value) = $sth->fetchrow_array()) {
        $object->add_tag($tag, $value, 1);
    }
    $sth->finish;

    # Attributes (multiple values are forbidden)
    if (%{$self->{'_attr_list'}}) {  # Only if some attributes are defined
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

sub _store_tagvalue {
    my $self = shift;
    my $object_id = shift;
    my $tag = shift;
    my $value = shift;
    my $allow_overloading = shift;
    
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities();
  
    if (exists $self->{'_attr_list'}->{$tag}) {
        # It is an attribute
        my $sth = $self->prepare("INSERT IGNORE INTO $db_attrtable ($db_keyname) VALUES (?)");
        $sth->execute($object_id);
        $sth->finish;
        $sth = $self->prepare("UPDATE $db_attrtable SET $tag=? WHERE $db_keyname=?");
        $sth->execute($value, $object_id);
        $sth->finish;

    } elsif ($allow_overloading) {
        # It is a tag with multiple values allowed
        my $sth = $self->prepare("INSERT IGNORE INTO $db_tagtable ($db_keyname, tag, value) VALUES (?, ?, ?)");
        $sth->execute($object_id, $tag, $value);
        $sth->finish;
    } else {
        # It is a tag with only one value allowed
        my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=?");
        $sth->execute($object_id, $tag);
        $sth->finish;
        $sth = $self->prepare("INSERT INTO $db_tagtable ($db_keyname, tag, value) VALUES (?, ?, ?)");
        $sth->execute($object_id, $tag, $value);
        $sth->finish;
    }
}

sub _delete_tagvalue {
    my $self = shift;
    my $object_id = shift;
    my $tag = shift;
    my $value = shift;
    
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities();
  
    if (exists $self->{'_attr_list'}->{$tag}) {
        # It is an attribute
        my $sth = $self->prepare("UPDATE $db_attrtable SET $tag=NULL WHERE $db_keyname=?");
        $sth->execute($object_id);
        $sth->finish;

    } else {
        # It is a tag
        if (defined $value) {
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=? AND value=?");
            $sth->execute($object_id, $tag, $value);
            $sth->finish;
        } else {
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=?");
            $sth->execute($object_id, $tag);
            $sth->finish;
        }
    }
}

1;
