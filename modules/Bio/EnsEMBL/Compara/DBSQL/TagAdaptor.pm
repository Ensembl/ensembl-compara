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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::DBSQL::TagAdaptor

=head1 DESCRIPTION

Generic adaptor that gives a database backend for tags / attributes (to
use with Bio::EnsEMBL::Compara::Taggable). There can be any number of
values for tags, but at most one for each attribute.

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::DBSQL::TagAdaptor;

use strict;
use warnings;


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
        $sth = $self->prepare("SELECT * FROM $db_attrtable WHERE $db_keyname=? LIMIT 1");
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


=head2 _load_tagvalues_multiple

  Description: similar to _load_tagvalues, but applies on a whole list
               of objects (assumed to be all of the same type)
  Arg [1]    : $objs: Array ref to the list of object
  Arg [2]    : (optional) Boolean: does $objs contain all the objects from the db ?
  Example    : $genetreenode_adaptor->_load_tagvalues_multiples( [$node1, $node2] );
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _load_tagvalues_multiple {
    my ($self, $objs, $all_objects) = @_;

    return unless scalar(@{$objs});

    # Assumes that all the objects have the same type
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities($objs->[0]);

    my %perl_keys = ();
    foreach my $val (@{$objs}) {
        $val->{'_tags'} = {} unless exists $val->{'_tags'};
        $perl_keys{$val->$perl_keyname} = $val;
    };

    my $where_constraint = '';
    if (not $all_objects) {
        $where_constraint = "WHERE $db_keyname IN (".join(',', keys %perl_keys).")";
    }

    # Tags (multiple values are allowed)
    my $sth = $self->prepare("SELECT $db_keyname, tag, value FROM $db_tagtable $where_constraint");
    $sth->execute();
    while (my ($obj_id, $tag, $value) = $sth->fetchrow_array()) {
        next if $all_objects and not exists $perl_keys{$obj_id};
        $perl_keys{$obj_id}->add_tag($tag, $value, 1);
        #warn "adding $value to $tag of $obj_id";
    }
    $sth->finish;
   
    # Attributes ?
    if (defined $db_attrtable) {
        $sth = $self->prepare("SELECT * FROM $db_attrtable $where_constraint");
        $sth->execute();
        # Retrieve data
        while (my $attrs = $sth->fetchrow_hashref()) {
            my $object = $perl_keys{$attrs->{$db_keyname}};
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
    #print STDERR "CALL _store_tagvalue $self/$object/$tag/$value/$allow_overloading: attr=", join("/", keys %{$self->{"_attr_list_$db_attrtable"}}), "\n";
  
    if (defined $db_attrtable && exists $self->{"_attr_list_$db_attrtable"}->{$tag}) {
        #print STDERR "attr\n";
        warn "Trying to overload the value of an attribute ($tag) ! This is not allowed for $self. The new value will replace the old one.\n" if $allow_overloading;
        # It is an attribute
        my $sth = $self->prepare("UPDATE $db_attrtable SET $tag=? WHERE $db_keyname=?");
        my $nrows = $sth->execute($value, $object->$perl_keyname);
        $sth->finish;
        if ($nrows == 0) {
            # We assume that all the columns have a "DEFAULT NULL" in their definition
            $sth = $self->prepare("INSERT IGNORE INTO $db_attrtable ($db_keyname, $tag) VALUES (?, ?)");
            $sth->execute($object->$perl_keyname, $value);
            $sth->finish;
        }

    } elsif ($allow_overloading) {
        #print STDERR "tag+\n";
        # It is a tag with multiple values allowed
        my $sth = $self->prepare("INSERT IGNORE INTO $db_tagtable ($db_keyname, tag, value) VALUES (?, ?, ?)");
        # Tests whether there is a UNIQUE key in the schema
        if ($sth->execute($object->$perl_keyname, $tag, $value) == 0) {
            die "The value '$value' has not been added to the tag '$tag' because it has another value and the SQL schema enforces '1 value per tag'.\n";
        }
        $sth->finish;
    } else {
        #print STDERR "tag\n";
        # It is a tag with only one value allowed
        my $sth = $self->prepare("UPDATE $db_tagtable SET value = ? WHERE $db_keyname=? AND tag=?");
        my $nrows = $sth->execute($value, $object->$perl_keyname, $tag);
        $sth->finish;

        if ($nrows == 0) {
            # INSERT
            $sth = $self->prepare("INSERT INTO $db_tagtable ($db_keyname, tag, value) VALUES (?, ?, ?)");
            $sth->execute($object->$perl_keyname, $tag, $value);
            $sth->finish;

        } elsif ($nrows > 1) {
            $nrows = $nrows-1;
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND tag=? LIMIT $nrows");
            $sth->execute($object->$perl_keyname, $tag);
            $sth->finish;
        }

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
    #print STDERR "CALL _delete_tagvalue $self/$object/$tag/$value: attr=", join("/", keys %{$self->{"_attr_list_$db_attrtable"}}), "\n";
  
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


=head2 sync_tags_to_database

  Description: rewrites all the tags from memory to the database
  Arg [1]    : <scalar> object
  Example    : $speciesset_adaptor->sync_tags_to_database($species_set);
  Returntype : none
  Exceptions : none
  Caller     : general

=cut

sub sync_tags_to_database {
    my $self = shift;
    my $object = shift;

    # No tags = nothing to write in the database
    return unless exists $object->{'_tags'};

    # memtags contains the tags that were in memory before the call
    my $memtags = $object->{'_tags'};
    # the object will load all the tags from the database
    delete $object->{'_tags'};
    # dbtags now contains the tags fetched from the database
    my $dbtags = $object->get_tagvalue_hash();

    # Whenever a tag has two values, we give priority to the memory
    foreach my $tag (keys %$dbtags) {

        # This bit would do "next" if the values are the same
        if (exists $memtags->{$tag}) {
            #print STDERR "Tag both in db and in memory: $tag=", $dbtags->{$tag}, "|", $memtags->{$tag}, "\n";
            if ((ref($dbtags->{$tag}) eq 'ARRAY') and (ref($memtags->{$tag}) eq 'ARRAY')) {
                #print STDERR "Comparing arrays: DB=", join("/", @{$dbtags->{$tag}}), " MEM=", join("/", @{$memtags->{$tag}}),"\n";
                my %seen;
                $seen{$_}++ for @{$dbtags->{$tag}};
                $seen{$_}-- for @{$memtags->{$tag}};
                next if not scalar(grep {$_} (values %seen));

            } elsif ((ref($dbtags->{$tag}) eq 'ARRAY') or (ref($memtags->{$tag}) eq 'ARRAY')) {
                # Different number of values
            } else {
                next if $dbtags->{$tag} eq $memtags->{$tag};
            }
        }
            
        # Wipe out any previous value
        $self->_delete_tagvalue($object, $tag);
        delete $dbtags->{$tag};
    }

    # All the tags that are in memory and not in the database
    foreach my $tag (keys %$memtags) {
        next if exists $dbtags->{$tag};

        # Copy the values to the new hash
        my $val = $dbtags->{$tag} = $memtags->{$tag};

        # Store the value in the database
        if (ref($val) eq 'ARRAY') {
            foreach my $value (@$val) {
                $self->_store_tagvalue($object, $tag, $value, 1);
            }
        } else {
            $self->_store_tagvalue($object, $tag, $val, 0);
        }
    }
}

1;
