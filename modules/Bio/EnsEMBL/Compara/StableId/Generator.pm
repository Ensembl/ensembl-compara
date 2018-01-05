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

Bio::EnsEMBL::Compara::StableId::Generator

=head1 DESCRIPTION

A name generator object (maintains the counter and knows the format of stable_ids).

=cut

package Bio::EnsEMBL::Compara::StableId::Generator;

use strict;
use warnings;
use Bio::EnsEMBL::Utils::Argument;  # import 'rearrange()'
use Bio::EnsEMBL::Compara::StableId::Map;
use Bio::EnsEMBL::Compara::StableId::NamedClusterSet;

sub new {
    my $class = shift @_;

    my $self = bless { }, $class;

    my ($type, $release, $counter, $prefix, $map, $default_version) =
         rearrange([qw(type release counter prefix map default_version)], @_);

    $self->counter($counter || 0);

    $self->type($type)         if(defined($type));
    $self->release($release)   if(defined($release));
    $self->prefix($prefix)     if(defined($prefix));
    $self->init_from_map($map) if(defined($map));

    $self->default_version(defined($default_version) ? $default_version : 1);  # can be 0 or anything you would like to start with. But it must be set once and forever.

    return $self;
}

sub prefix {
    my $self = shift @_;

    if(@_) {
        $self->{'_prefix'} = shift @_;
    }
    return ($self->{'_prefix'} ||= { 'f' => 'ENSFM', 't' => 'ENSGT' }->{$self->type} || 'UnkType');
}

sub init_from_map {     # actually, we can initialize either from a Map or from a NamedClusterSet (they both have get_all_clids() & clid2clname() methods)
    my $self = shift @_;
    my $map  = shift @_;
    
    my $highest_counter = 0;

    foreach my $clid (@{ $map->get_all_clids }) {
        my $clname = $map->clid2clname($clid);

        if($clname=~/^(\w+)\d{4}(\d{10})\.\d+$/) {
            if(defined($self->{_prefix}) ? ($1 eq $self->prefix()) : $self->prefix($1)) { # make sure you completely understand this line if you're itching to change it :)
                if($2 > $highest_counter) {
                    $highest_counter = $2;
                }
            }
        }
    }
    $self->counter($highest_counter);
}

sub generate_new_name {
    my $self = shift @_;

    $self->counter($self->counter+1);

    return sprintf("%s%04d%010d.%d",$self->prefix, $self->release, $self->counter, $self->default_version);
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

sub counter {
    my $self = shift @_;

    if(@_) {
        $self->{'_counter'} = shift @_;
    }
    return $self->{'_counter'};
}

sub default_version {
    my $self = shift @_;

    if(@_) {
        $self->{'_default_version'} = shift @_;
    }
    return $self->{'_default_version'};
}

1;

