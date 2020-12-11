=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesFactory

=head1 DESCRIPTION

Wrapper factory to surround Productions SpeciesFactory. Take either a newline separated
file of species_list_file or species_list parameter passed through the command line

=cut

package Bio::EnsEMBL::Compara::RunnableDB::HomologyAnnotation::SpeciesFactory;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Data::Dumper;

use base ('Bio::EnsEMBL::Production::Pipeline::Common::SpeciesFactory');


sub fetch_input {
    my $self = shift;

    my $species_list = $self->param('species_list');
    my $species_file = $self->param('species_list_file');

    throw "Cannot have both species_list and a species_list_file specified" if $species_list && $species_file;
    if ( $species_list ) {
        $self->param( 'species' => \@$species_list );
        print Dumper $species_list;
    }
    elsif ( $species_file ) {
        open ( my $f, "<", $species_file ) or die "Cannot open production list of species $!";
        chomp( my @species_list  = <$f> );
        close($f);
        $self->param( 'species' => \@species_list );
    }
}

sub write_output {
    my $self = shift;

    $self->SUPER::write_output();
    
}

1;
