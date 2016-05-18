=head1 LICENSE

Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Bio::EnsEMBL::Compara::Utils::Preloader

=head1 DESCRIPTION

Most of the objects do lazy-loading of related objects via queries to the
database. This system is sub-optimal when there are a lot of objects to
fetch.

This module provides several methods to do a bulk-loading of objects in a
minimum number of queries.

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded by a _.

=cut

package Bio::EnsEMBL::Compara::Utils::Preloader;

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Scalar qw(wrap_array);
use Bio::EnsEMBL::Utils::Exception qw(throw);


=head2 _load_and_attach_all

  Arg[1]      : String $id_internal_key. Name of the key in the objects that contains the dbID of the objects to load
  Arg[2]      : String $object_internal_key. Name of the key in the objects to attach the new objects
  Arg[3]      : Bio::EnsEMBL::DBSQL::BaseAdaptor $adaptor. The adaptor that is used to retrieve the objects.
  Arg[4..n]   : Objects or arrays
  Example     : _load_and_attach_all('dnafrag_id', 'dnafrag', $dnafrag_adaptor, $gene_tree->get_all_leaves);
  Description : Generic method to fetch all the objects from the database in a minimum number of queries.
  Returntype  : Arrayref: the objects loaded from the database
  Exceptions  : none
  Caller      : general
  Status      : Stable

=cut

sub _load_and_attach_all {
    my ($id_internal_key, $object_internal_key, $adaptor, @args) = @_;

    my %key2iniobject = ();
    my %key2newobject = ();
    foreach my $a (@args) {
        foreach my $o (@{wrap_array($a)}) {
            next if !ref($o);                   # We need a ref to an object
            next if ref($o) !~ /::/;            # but not one of the basic types
            next if !$o->{$id_internal_key};    # It needs to have the dbID key

            # Check if the target object has already been loaded
            if ($o->{$object_internal_key}) {
                $key2newobject{$o->{$id_internal_key}} = $o->{$object_internal_key};
            } else {
                push @{$key2iniobject{$o->{$id_internal_key}}}, $o;
            }
        }
    }

    my @keys_to_fetch = grep {!$key2newobject{$_}} keys %key2iniobject;
    my $all_new_objects = $adaptor->fetch_all_by_dbID_list(\@keys_to_fetch);
    foreach my $o (@$all_new_objects, values %key2newobject) {
        $_->{$object_internal_key} = $o for @{$key2iniobject{$o->dbID}};
    }
    return $all_new_objects;
}


1;
