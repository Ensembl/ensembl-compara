=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Taggable

=head1 DESCRIPTION

Base class for objects supporting tags / attributes

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Taggable;

use strict;
use warnings;


=head2 add_tag

  Description: adds metadata tags to a node.  Both tag and value are added
               as metdata with the added ability to retreive the value given
               the tag (like a perl hash). In case of one to many relation i.e.
               one tag and different values associated with it, the values are
               returned in a array reference.
  Arg [1]    : <string> tag
  Arg [2]    : <string> value
  Arg [3]    : (optional) <int> allows overloading the tag with different values
               default is 0 (no overloading allowed, one tag points to one value)
  Example    : $ns_node->add_tag('scientific name', 'Mammalia');
               $ns_node->add_tag('lost_taxon_id', 9593, 1);
  Returntype : Boolean indicating if the tag has been added
  Exceptions : none
  Caller     : general

=cut

sub add_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;
    my $allow_overloading = shift;
    #print STDERR "CALL add_tag $self/$tag/$value/$allow_overloading\n";

    # Argument check
    unless (defined $tag)   {warn "add_tag called on $self with an undef \$tag\n"; return 0};
    unless (defined $value) {warn "add_tag called on $self with an undef value for tag '$tag'\n"; return 0};
    $allow_overloading = 0 unless (defined $allow_overloading);
    
    $self->_load_tags;
    $tag = lc($tag);

    # Stores the value in the PERL object
    if ( ! exists($self->{'_tags'}->{$tag}) || ! $allow_overloading ) {
        # No overloading or new tag: store the value
        $self->{'_tags'}->{$tag} = $value;

    } elsif ( ref($self->{'_tags'}->{$tag}) eq 'ARRAY' ) {
        # Several values were there: we add a new one
        push @{$self->{'_tags'}->{$tag}}, $value;

    } else {
        # One value was there, we make an array
        $self->{'_tags'}->{$tag} = [ $self->{'_tags'}->{$tag}, $value ];
    }
    return 1;
}


=head2 store_tag

  Description: calls add_tag and then stores the tag in the database. Has the
               exact same arguments as add_tag
  Arg [1]    : <string> tag
  Arg [2]    : <string> value
  Arg [3]    : (optional) <int> allows overloading the tag with different values
               default is 0 (no overloading allowed, one tag points to one value)
  Example    : $ns_node->store_tag('scientific name', 'Mammalia');
               $ns_node->store_tag('lost_taxon_id', 9593, 1);
  Returntype : Boolean indicating if the tag has been stored
  Exceptions : none
  Caller     : general

=cut

sub store_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;
    my $allow_overloading = shift;
    #print STDERR "CALL store_tag $self/$tag/$value/$allow_overloading\n";

    if ($self->add_tag($tag, $value, $allow_overloading)) {
        if($self->adaptor and $self->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::TagAdaptor")) {
            $self->adaptor->_store_tagvalue($self, lc($tag), $value, $allow_overloading);
            return 1;
        } else {
            warn "Calling store_tag on $self but the adaptor ", $self->adaptor, " doesn't have such capabilities\n";
            return 0;
        }
    } else {
        warn "add_tag has failed, store_tag is now skipped\n";
        return 0;
    }
}


=head2 remove_tag

  Description: removes a tag from the metadata (in memory). If the value is provided,
               it will only delete it (all its occurrences). Otherwise, it just clears
               ell the values associated with the tag.
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <string> value
  Example    : $ns_node->remove_tag('scientific name', 'Mammalia');
               $ns_node->remove_tag('lost_taxon_id');
  Returntype : Boolean -- 1 if something has been deleted, 0 otherwise
  Exceptions : none
  Caller     : general

=cut

sub remove_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;

    # Arguments check
    unless (defined $tag)   {warn "remove_tag called on $self with an undef \$tag\n"; return 0};
    $tag = lc($tag);

    $self->_load_tags;
    return 0 unless exists($self->{'_tags'}->{$tag});

    # Updates the PERL object
    my $found = 0;
    if (defined $value) {
        if ( ref($self->{'_tags'}->{$tag}) eq 'ARRAY' ) {
            my $arr = $self->{'_tags'}->{$tag};
            my $index = scalar(@$arr)-1;
            until ($index < 0) {
                $index-- until ($index < 0) or ($arr->[$index] eq $value);
                if ($index >= 0) {
                    splice(@$arr, $index, 1);
                    $found = 1;
                }
            }
            if (scalar(@$arr) == 0) {
                delete $self->{'_tags'}->{$tag};
            } elsif (scalar(@$arr) == 1) {
                $self->{'_tags'}->{$tag} = $arr->[0];
            }
        } else {
            if ($self->{'_tags'}->{$tag} eq $value) {
                delete $self->{'_tags'}->{$tag};
                $found = 1;
            }
        }
    } else {
        delete $self->{'_tags'}->{$tag};
        $found = 1;
    }

    return $found;
}


=head2 delete_tag

  Description: removes a tag from the metadata (both from memory and the database).
               If the value is provided, it tries to delete only it (if present).
               Otherwise, it just clears the tag, whatever value it was containing.
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <string> value
  Example    : $ns_node->remove_tag('scientific name', 'Mammalia');
               $ns_node->remove_tag('lost_taxon_id', 9593);
  Returntype : Boolean -- 1 in case of success, 0 otherwise
  Exceptions : none
  Caller     : general

=cut

sub delete_tag {
    my $self = shift;
    my $tag = shift;
    my $value = shift;

    # Update the database
    if ($self->remove_tag($tag, $value)) {
        if($self->adaptor and $self->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::TagAdaptor")) {
            $self->adaptor->_delete_tagvalue($self, $tag, $value);
            return 1;
        } else {
            return 0;
        }
    } else {
        return 1;
    }
}


=head2 has_tag

  Description: indicates whether the tag exists in the metadata
  Arg [1]    : <string> tag
  Example    : $ns_node->has_tag('scientific name');
  Returntype : Boolean
  Exceptions : none
  Caller     : general

=cut

sub has_tag {
    my $self = shift;
    my $tag = shift;

    return 0 unless defined $tag;

    $self->_load_tags;
    return exists($self->{'_tags'}->{lc($tag)});
}


=head2 get_tagvalue

  Description: returns the value(s) of the tag, or $default (undef
               if not provided) if the tag doesn't exist.
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <scalar> default
  Example    : $ns_node->get_tagvalue('scientific name');
  Returntype : Scalar or ArrayRef
  Exceptions : none
  Caller     : general

=cut

sub get_tagvalue {
    my $self = shift;
    my $tag = shift;
    my $default = shift;

    return $default unless defined $tag;

    $tag = lc($tag);
    $self->_load_tags;
    return $default unless exists($self->{'_tags'}->{$tag});
    return $self->{'_tags'}->{$tag};
}


=head2 get_value_for_tag

  Description: returns the value of the tag, or $default (undef
               if not provided) if the tag doesn't exist. In case
               of multiple values, the first one is returned.
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <scalar> default
  Example    : $ns_node->get_tagvalue('scientific name');
  Returntype : Scalar
  Exceptions : none
  Caller     : general

=cut

sub get_value_for_tag {
    my $self = shift;
    my $tag = shift;
    my $default = shift;

    my $ret = $self->get_tagvalue($tag, $default);
    if ((defined $ret) and (ref($ret) eq 'ARRAY')) {
        return $ret->[0];
    } else {
        return $ret;
    }
}


=head2 get_all_values_for_tag

  Description: returns all the values of the tag, or $default (undef
               if not provided) if the tag doesn't exist. In case of
               a single value, it is wrapped with an array
  Arg [1]    : <string> tag
  Arg [2]    : (optional) <scalar> default
  Example    : $ns_node->get_tagvalue('scientific name');
  Returntype : ArrayRef
  Exceptions : none
  Caller     : general

=cut

sub get_all_values_for_tag {
    my $self = shift;
    my $tag = shift;
    my $default = shift || [];

    my $ret = $self->get_tagvalue($tag);
    return $default if not defined $ret;
    if (ref($ret) eq 'ARRAY') {
        return $ret;
    } else {
        return [$ret];
    }
}

=head2 get_all_tags

  Description: returns an array of all the available tags
  Example    : $ns_node->get_all_tags();
  Returntype : Array
  Exceptions : none
  Caller     : general

=cut

sub get_all_tags {
    my $self = shift;

    $self->_load_tags;
    return keys(%{$self->{'_tags'}});
}


=head2 get_tagvalue_hash

  Description: returns the underlying hash that contains all
               the tags
  Example    : $ns_node->get_tagvalue_hash();
  Returntype : Hashref
  Exceptions : none
  Caller     : general

=cut

sub get_tagvalue_hash {
    my $self = shift;

    $self->_load_tags;
    return $self->{'_tags'};
}

=head2 _load_tags

  Description: loads all the tags (from the database) if possible.
               Otherwise, an empty hash is created
  Example    : $ns_node->_load_tags();
  Returntype : none
  Exceptions : none
  Caller     : internal

=cut

sub _load_tags {
    my $self = shift;
    #print STDERR "CALL _load_tags $self\n";

    return if exists $self->{'_tags'};
    $self->{'_tags'} = {};
    if($self->can('adaptor') and $self->adaptor and $self->adaptor->isa("Bio::EnsEMBL::Compara::DBSQL::TagAdaptor")) {
        $self->adaptor->_load_tagvalues($self);
    }
}


=head2 AUTOLOAD

  Description: matches the get_value_for_XXX calls to get_value_for_tag('XXX') and other calls
  Returntype : none
  Exceptions : none
  Caller     : system

=cut

our $AUTOLOAD;

sub AUTOLOAD {
    my $self = shift;
    #print "AUTOLOAD $AUTOLOAD\n";
    if ( $AUTOLOAD =~ m/::get_value_for_(\w+)$/ ) {
        #print "MATCHED $1\n";
        return $self->get_value_for_tag($1);
    } elsif ( $AUTOLOAD =~ m/::get_all_values_for_(\w+)$/ ) {
        return $self->get_all_values_for_tag($1);
    } elsif ( $AUTOLOAD =~ m/::get_(\w+)_value$/ ) {
        return $self->get_tagvalue($1);
    } elsif( $AUTOLOAD !~ /::DESTROY$/) {
        use Carp;
        croak "$self does not understand method $AUTOLOAD\n";
    }
}


1;

