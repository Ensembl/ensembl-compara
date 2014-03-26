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

=head1 NAME

PantherAnnot

=head1 DESCRIPTION

=head1 AUTHOR

ChuangKee Ong

=head1 CONTACT

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal methods are usually preceded with a _.

=cut
package Bio::EnsEMBL::Compara::Runnable::ComparaHMM::PantherAnnot;

use strict;
use warnings;
use Data::Dumper;

sub new {
    my ($class) = @_;

    my $self = bless {}, $class;

return $self;
}

##############################
# Getters / Setters
##############################
sub upi {
    my $self = shift;
    $self->{'_upi'} = shift if (@_);
    return $self->{'_upi'};
}

sub ensembl_id {
    my $self = shift;
    $self->{'_ensembl_id'} = shift if (@_);
    return $self->{'_ensembl_id'};
}

sub ensembl_div {
    my $self = shift;
    $self->{'_ensembl_div'} = shift if (@_);
    return $self->{'_ensembl_div'};
}

sub panther_family_id {
    my $self = shift;
    $self->{'_panther_family_id'} = shift if (@_);
    return $self->{'_panther_family_id'};
}

sub start {
    my $self = shift;
    $self->{'_start'} = shift if (@_);
    return $self->{'_start'};
}

sub end {
    my $self = shift;
    $self->{'_end'} = shift if (@_);
    return $self->{'_end'};
}

sub score {
    my $self = shift;
    $self->{'_score'} = shift if (@_);
    return $self->{'_score'};
}

sub evalue {
    my $self = shift;
    $self->{'_evalue'} = shift if (@_);
    return $self->{'_evalue'};
}



1;
