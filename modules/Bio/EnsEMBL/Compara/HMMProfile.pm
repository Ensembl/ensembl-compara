=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

HMMProfile

=head1 DESCRIPTION

An object that holds the full description of an HMM profile stored in the database.

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _.

=cut


package Bio::EnsEMBL::Compara::HMMProfile;

use strict;
use warnings;

use Data::Dumper;

sub new {
    my ($class) = @_;

    my $self = bless {}, $class;

    return $self;
}




##############################
#
# Getters / Setters
#
##############################

sub model_id {
    my $self = shift;
    $self->{'_model_id'} = shift if (@_);
    return $self->{'_model_id'};
}

sub name {
    my $self = shift;
    $self->{'_name'} = shift if (@_);
    return $self->{'_name'};
}

sub type {
    my $self = shift;
    $self->{'_type'} = shift if (@_);
    return $self->{'_type'};
}

sub profile {
    my $self = shift;
    $self->{'_profile'} = shift if (@_);
    return $self->{'_profile'};
}

sub consensus {
    my $self = shift;
    $self->{'_consensus'} = shift if (@_);
    return $self->{'_consensus'};
}


1;
