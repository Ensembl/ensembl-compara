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
    $self->{'_hc_profile'} = shift if (@_);
    return $self->{'_hc_profile'};
}

sub consensus {
    my $self = shift;
    $self->{'_consensus'} = shift if (@_);
    return $self->{'_consensus'};
}


1;
