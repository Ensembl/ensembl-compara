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

use DBI qw(:sql_types);

use Bio::EnsEMBL::Compara::Utils::Scalar qw(:argument);


=head2 _tag_capabilities

  Description: returns the tag/attributes capabilities for the object. The
               return value is an array with 4 entries:
                - the name of the table to store tag
                - the name of the table to store attribute
                - the name of the key column in the tables
                - the name of the perl method to have the key value
                - the name of the "tag" column in the tag table
                - the name of the "value" column in the tag table
  Arg [1]    : <scalar> reference object
  Example    : return ('species_set_tag', undef, 'species_set_id', 'dbID', 'tag', 'value');
  Returntype : Array of 6 entries
  Exceptions : none
  Caller     : internal

=cut

sub _tag_capabilities {
    my ($self, $object) = @_;

    die "_tag_capabilities for $object must be redefined in $self (or a subclass)\n";
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
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname, $col_tag, $col_value) = $self->_tag_capabilities($object);
    #print STDERR "_load_tagvalues = $db_tagtable/$db_attrtable\n";

    my $obj_tags = $object->{'_tags'};

    # Tags (multiple values are allowed)
    my $sth = $self->prepare("SELECT $col_tag, $col_value FROM $db_tagtable WHERE $db_keyname=?");
    $sth->execute($object->$perl_keyname);
    my ($tag, $value);
    $sth->bind_columns(\$tag, \$value);
    while ($sth->fetch()) {
        $tag = lc $tag;
        # Optimized version of Taggable::add_tag()
        if ( ! exists($obj_tags->{$tag}) ) {
            $obj_tags->{$tag} = $value;
        } elsif ( ref($obj_tags->{$tag}) eq 'ARRAY' ) {
            push @{$obj_tags->{$tag}}, $value;
        } else {
            $obj_tags->{$tag} = [ $obj_tags->{$tag}, $value ];
        }
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
                    $obj_tags->{$key} = ${$attrs}{$key};
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
  Example    : $genetreenode_adaptor->_load_tagvalues_multiple( [$node1, $node2] );
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _load_tagvalues_multiple {
    my ($self, $objs, $all_objects) = @_;

    return unless scalar(@{$objs});

    # Assumes that all the objects have the same type
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname, $col_tag, $col_value) = $self->_tag_capabilities($objs->[0]);

    my %perl_keys = ();
    foreach my $val (@{$objs}) {
        next if exists $val->{'_tags'};
        $val->{'_tags'} = {};
        $perl_keys{$val->$perl_keyname} = $val;
    };
    return unless scalar(keys %perl_keys);

    # This closure can process a set of objects
my $load_some_tags = sub {
    my $where_constraint = shift;
    $where_constraint = " WHERE ".$where_constraint if $where_constraint;

    # Tags (multiple values are allowed)
    my $sth = $self->prepare("SELECT $db_keyname, $col_tag, $col_value FROM $db_tagtable $where_constraint");
    $sth->execute();
    my ($obj_id, $tag, $value);
    $sth->bind_columns(\$obj_id, \$tag, \$value);
    while ($sth->fetch()) {
        next if $all_objects and not exists $perl_keys{$obj_id};
        my $obj_tags = $perl_keys{$obj_id}->{'_tags'};
        $tag = lc $tag;

        # Optimized version of Taggable::add_tag()
        if ( ! exists($obj_tags->{$tag}) ) {
            $obj_tags->{$tag} = $value;
        } elsif ( ref($obj_tags->{$tag}) eq 'ARRAY' ) {
            push @{$obj_tags->{$tag}}, $value;
        } else {
            $obj_tags->{$tag} = [ $obj_tags->{$tag}, $value ];
        }

        #warn "adding $value to $tag of $obj_id";
    }
    $sth->finish;
   
    # Attributes ?
    if (defined $db_attrtable) {
        $sth = $self->prepare("SELECT * FROM $db_attrtable $where_constraint");
        $sth->execute();
        # Retrieve data
        while (my $attrs = $sth->fetchrow_hashref()) {
            my $obj_tags = $perl_keys{$attrs->{$db_keyname}}->{'_tags'};
            foreach my $key (keys %$attrs) {
                if (($key ne $db_keyname) and defined(${$attrs}{$key})) {
                    $obj_tags->{$key} = ${$attrs}{$key};
                }
            }
        }
        $sth->finish;
    }
};
    if ($all_objects) {
        $load_some_tags->('');
    } else {
        # This assumes that the class also inherits from BaseAdaptor
        $self->split_and_callback([keys %perl_keys], $db_keyname, SQL_INTEGER, $load_some_tags);
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
    my $db_keyname = shift;

    # No table provided
    return if not defined $db_attrtable;
    # Column names already loaded
    return if exists $self->{"_attr_list_$db_attrtable"};

    $self->{"_attr_list_$db_attrtable"} = {};
    eval {
        my $sth = $self->dbc->db_handle->column_info(undef, undef, $db_attrtable, '%');
        $sth->execute();
        while (my $row = $sth->fetchrow_hashref()) {
            my $this_column = ${$row}{'COLUMN_NAME'};
            next if $this_column eq $db_keyname;
            ${$self->{"_attr_list_$db_attrtable"}}{$this_column} = 1;
            #print STDERR "adding $this_column to the attribute list $db_attrtable of adaptor $self\n";
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
    
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname, $col_tag, $col_value) = $self->_tag_capabilities($object);
    $self->_read_attr_list($db_attrtable, $db_keyname);
    #print STDERR "CALL _store_tagvalue $self/$object/$tag/$value attr=", join("/", keys %{$self->{"_attr_list_$db_attrtable"}}), "\n";
  
    if (defined $db_attrtable && exists $self->{"_attr_list_$db_attrtable"}->{$tag}) {
        #print STDERR "attr\n";
        # It is an attribute
        if (ref($value)) {
            die "TagAdaptor cannot store structures (".ref($value).") in the attribute table.\n";
        }
        my $sth = $self->prepare("UPDATE $db_attrtable SET $tag=? WHERE $db_keyname=?");
        my $nrows = $sth->execute($value, $object->$perl_keyname);
        $sth->finish;
        if ($nrows == 0) {
            # We assume that all the columns have a "DEFAULT NULL" in their definition
            $sth = $self->prepare("INSERT IGNORE INTO $db_attrtable ($db_keyname, $tag) VALUES (?, ?)");
            $sth->execute($object->$perl_keyname, $value);
            $sth->finish;
        }

    } elsif (ref($value) and (ref($value) eq 'ARRAY')) {
        #print STDERR "tag+array\n";
        # Each value will be stored independently
        # We first clear the table and then insert the values one by one
        my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND $col_tag=?");
        $sth->execute($object->$perl_keyname, $tag);
        $sth->finish;

        $sth = $self->prepare("INSERT IGNORE INTO $db_tagtable ($db_keyname, $col_tag, $col_value) VALUES (?, ?, ?)");
        foreach my $v (@$value) {
            die "Cannot store NULL in $db_tagtable for '$tag'\n" if not defined $v;
            # Tests whether there is a UNIQUE key in the schema
            if ($sth->execute($object->$perl_keyname, $tag, $v) == 0) {
                die "The value '$v' has not been added to the tag '$tag' (probably) because of a unique key constraint.\n";
            }
        }

    } elsif (ref($value)) {
        #print STDERR "tag+ref\n";
        die "TagAdaptor cannot store complex structures such as ".ref($value)."\n";

    } elsif (defined $value) {
        #print STDERR "tag+scalar\n";
        # It is a tag with only one value allowed
        my $sth = $self->prepare("UPDATE $db_tagtable SET $col_value = ? WHERE $db_keyname=? AND $col_tag=?");
        my $nrows = $sth->execute($value, $object->$perl_keyname, $tag);
        $sth->finish;

        if ($nrows == 0) {
            # INSERT
            $sth = $self->prepare("INSERT INTO $db_tagtable ($db_keyname, $col_tag, $col_value) VALUES (?, ?, ?)");
            $sth->execute($object->$perl_keyname, $tag, $value);
            $sth->finish;

        } elsif ($nrows > 1) {
            $nrows = $nrows-1;
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND $col_tag=? LIMIT $nrows");
            $sth->execute($object->$perl_keyname, $tag);
            $sth->finish;
        }

    } else {
        die "Cannot store NULL in $db_tagtable for '$tag'\n";
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
    
    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname, $col_tag, $col_value) = $self->_tag_capabilities($object);
    $self->_read_attr_list($db_attrtable, $db_keyname);
    #print STDERR "CALL _delete_tagvalue $self/$object/$tag/$value: attr=", join("/", keys %{$self->{"_attr_list_$db_attrtable"}}), "\n";
  
    if (defined $db_attrtable and exists $self->{"_attr_list_$db_attrtable"}->{$tag}) {
        # It is an attribute
        my $sth = $self->prepare("UPDATE $db_attrtable SET $tag=NULL WHERE $db_keyname=?");
        $sth->execute($object->$perl_keyname);
        $sth->finish;

    } else {
        # It is a tag
        if (defined $value) {
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND $col_tag=? AND $col_value=?");
            $sth->execute($object->$perl_keyname, $tag, $value);
            $sth->finish;
        } else {
            my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=? AND $col_tag=?");
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
                # Note: the order is not guaranteed in the database, so
                # we're just comparing the content as multisets
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
        $self->_store_tagvalue($object, $tag, $val);
    }
}


=head2 _wipe_all_tags

  Arg [1]     : <scalar or arrayref> object(s)
  Arg [2]     : <boolean> should attributes be excluded (i.e. not deleted) (default: 0)
  Arg [3]     : <boolean> should tags be excluded (i.e. not deleted) (default: 0)
  Example     : $gene_tree_node_adaptor->_wipe_all_tags($gene_tree->get_all_nodes);
  Description : Deletes all the tags from the database for those objects
  Returntype  : none
  Exceptions  : none
  Caller      : internal

=cut

sub _wipe_all_tags {
    my ($self, $objects, $exclude_attr, $exclude_tags) = @_;

    $objects = [$objects] if ref($objects) ne 'ARRAY';

    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname) = $self->_tag_capabilities($objects->[0]);
    $self->_read_attr_list($db_attrtable, $db_keyname);
    #print STDERR "CALL _wipe_all_tags $self/$exclude_attr/$exclude_tags: attr=", join("/", keys %{$self->{"_attr_list_$db_attrtable"}}), "\n";

    if (defined $db_attrtable and not $exclude_attr) {
        my $sth = $self->prepare("DELETE FROM $db_attrtable WHERE $db_keyname=?");
        foreach my $object (@$objects) {
            $sth->execute($object->$perl_keyname);
        }
        $sth->finish;

    }

    unless ($exclude_tags) {
        my $sth = $self->prepare("DELETE FROM $db_tagtable WHERE $db_keyname=?");
        foreach my $object (@$objects) {
            $sth->execute($object->$perl_keyname);
        }
        $sth->finish;
    }
}


=head2 _store_all_tags

  Arg [1]     : <scalar or arrayref> object(s)
  Example     : $gene_tree_node_attr->_store_all($gene_tree->get_all_nodes);
  Description : Store all the tags / attributes for all the objects. The
                method assumes that the database doesn't contain any data.
  Returntype  : none
  Exceptions  : Database errors like duplicated entries
  Caller      : internal

=cut

sub _store_all_tags {
    my ($self, $objects) = @_;

    $objects = [$objects] if ref($objects) ne 'ARRAY';

    my ($db_tagtable, $db_attrtable, $db_keyname, $perl_keyname, $col_tag, $col_value) = $self->_tag_capabilities($objects->[0]);
    $self->_read_attr_list($db_attrtable, $db_keyname);
    #print STDERR "CALL _store_all $self/$object/$tag/$value: attr=", join("/", keys %{$self->{"_attr_list_$db_attrtable"}}), "\n";

    # First the attributes
    if (defined $db_attrtable) {
        my @attr_names = keys %{$self->{"_attr_list_$db_attrtable"}};
        my $sql = "INSERT INTO $db_attrtable ($db_keyname, ".join(", ", @attr_names).") VALUES (?".(",?" x scalar(@attr_names)).")";
        my $sth = $self->prepare($sql);
        foreach my $object (@$objects) {
            my $tag_hash = $object->get_tagvalue_hash;
            my @defined_attrs = grep {$tag_hash->{$_}} @attr_names;
            if (scalar(@defined_attrs)) {
                if (grep {ref($tag_hash->{$_})} @attr_names) {
                    die "TagAdaptor cannot store structures in the attribute table.\n";
                }
                $sth->execute($object->$perl_keyname, map {$tag_hash->{$_}} @attr_names);
            }
        }
        $sth->finish;
    }

    # And then the tags
    my $sth = $self->prepare("INSERT INTO $db_tagtable ($db_keyname, $col_tag, $col_value) VALUES (?, ?, ?)");
    foreach my $object (@$objects) {
        my $tag_hash = $object->get_tagvalue_hash;
        my $object_key = $object->$perl_keyname;
        foreach my $tag (keys %$tag_hash) {
            next if defined $db_attrtable and exists $self->{"_attr_list_$db_attrtable"}->{$tag};
            if (ref($tag_hash->{$tag}) eq 'ARRAY') {
                foreach my $value (@{$tag_hash->{$tag}}) {
                    die "Cannot store NULL in $db_tagtable for '$tag'\n" if not defined $value;
                    $sth->execute($object_key, $tag, $value);
                }
            } elsif (ref($tag_hash->{$tag})) {
                die "TagAdaptor cannot store complex structures such as ".ref($tag_hash->{$tag})."\n";
            } else {
                die "Cannot store NULL in $db_tagtable for '$tag'\n" if not defined $tag_hash->{$tag};
                $sth->execute($object_key, $tag, $tag_hash->{$tag});
            }
        }
    }
    $sth->finish;
}


1;
