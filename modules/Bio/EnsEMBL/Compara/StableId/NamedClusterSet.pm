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

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::StableId::NamedClusterSet

=head1 DESCRIPTION

A data container object (the only methods are getters/setters)
that maintains membername-2-clusterid and clusterid-2-clustername relationships

=cut

package Bio::EnsEMBL::Compara::StableId::NamedClusterSet;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument;  # import 'rearrange()'
use Bio::EnsEMBL::Compara::StableId::Map;

sub new {
    my $class = shift @_;

    my $self = bless { }, $class;

    my ($type, $release) =
         rearrange([qw(type release) ], @_);

    $self->type($type)       if(defined($type));
    $self->release($release) if(defined($release));

    return $self;
}

sub apply_map {
    my $self = shift @_;
    my $map  = shift @_;

    foreach my $clid (@{$self->get_all_clids}) {
        if(my $new_name = $map->clid2clname($clid)) {
            $self->clid2clname($clid, $new_name);
        } else {
            my $old_name = $self->clid2clname($clid);
            die "Map does not contain mapping for '$old_name' (id=$clid)";
        }
    }
}

sub type {
    my $self = shift @_;

    if(@_) {
        $self->{'_type'} = shift @_;
    }
    return $self->{'_type'};
}

sub release {
    my $self = shift @_;

    if(@_) {
        $self->{'_release'} = shift @_;
    }
    return $self->{'_release'};
}

sub mname2clid {    # member_name -> class_id mapping (many-to-1)
    my $self       = shift @_;
    my $mname = shift @_;

    my $hash = $self->{'_mname2clid'} ||= {};

    if(@_) {
        $hash->{$mname} = shift @_;
    }
    return $hash->{$mname};
}

sub clid2clname {   # class_id -> class_name (1-to-1)
    my $self       = shift @_;
    my $clid  = shift @_;

    my $hash = $self->{'_clid2clname'} ||= {};

    if(@_) {
        $hash->{$clid} = shift @_;
    }
    return $hash->{$clid};
}

sub get_all_members {
    my $self       = shift @_;

    return [ keys %{ $self->{'_mname2clid'} ||= {} } ];
}

sub get_all_clids {
    my $self       = shift @_;

    return [ sort {$a<=>$b} keys %{ $self->{'_clid2clname'} ||= {} } ];
}

1;

