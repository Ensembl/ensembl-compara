
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

Bio::EnsEMBL::Compara::RunnableDB::GetSpeciesList

=head1 DESCRIPTION

Used to retrieve all the species available in E!-like sites, via the REST API

=cut

package Bio::EnsEMBL::Compara::RunnableDB::GetSpeciesList;

use strict;
use warnings;
use HTTP::Tiny;
use JSON;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub run {
    my ($self) = @_;

    my %all_genomes;
    $self->param( 'all_genomes', \%all_genomes );

    foreach my $division ( @{ $self->param_required('divisions') } ) {
        $self->_get_species($division);
    }

    #---------------------
    #Printing debugs
    #---------------------
    #my $species_count = scalar( keys( %{ $self->param('all_genomes') } ) );
    #print "Total species:$species_count\n" if ($self->debug);
    # ---------------------
}

=head2 write_output

    Title   :   write_output
    Usage   :   $self->write_output
    Function:   
    Returns :   none
    Args    :   none

=cut

sub write_output {
    my $self = shift @_;

    foreach my $species ( keys %{ $self->param('all_genomes') } ) {
        my $output_id = { 'species_name' => $species, 'reg_conf' => $self->param('all_genomes')->{$species}};
        $self->dataflow_output_id( $output_id, 2 );
    }
    my @genome_list = keys(%{$self->param('all_genomes')});
    $self->dataflow_output_id( {'species_list' => \@genome_list}, 1 );
}

##########################################
#
# internal methods
#
##########################################

sub _get_species {
    my ( $self, $division ) = @_;

    #print ">>>>|$division|\n" if ($self->debug);
    my $http = HTTP::Tiny->new();

    # -----------------------[ Ensembl ]-----------------------------
    if ( $division eq "Ensembl" ) {
        my $server   = 'http://rest.ensembl.org';
        my $ext      = '/info/species?';
        my $response = $http->get( $server . $ext, { headers => { 'Content-type' => 'application/json' } } );
        die "Failed!\n" unless $response->{success};
        if ( length $response->{content} ) {
            my $hash = decode_json( $response->{content} );

            foreach my $genome_count ( keys %{$hash->{'species'}} ) {
                $self->param('all_genomes')->{ $hash->{'species'}->[$genome_count]->{'name'} } = "production_reg_conf_ensembl.pl";
            }
        }
    }

    # -----------------------[ Ensembl Genomes ]-----------------------------
    elsif ( $division =~ m/(Fungi|Metazoa|Plants|Protists)/ ) {
        my $server   = 'http://rest.ensemblgenomes.org';
        my $ext      = "/info/genomes/division/$division?";
        my $response = $http->get( $server . $ext, { headers => { 'Content-type' => 'application/json' } } );

        die "Failed!\n" unless $response->{success};

        my $hash;
        if ( length $response->{content} ) {
            $hash = decode_json( $response->{content} );

            foreach my $genome_count ( keys %$hash ) {
                if ( !$self->param('all_genomes')->{ $hash->[$genome_count]->{'species'} } ) {
                    $self->param('all_genomes')->{ $hash->[$genome_count]->{'species'} } = "production_reg_conf_EG.pl";
                }
            }
        }
    }

    # -----------------------[ WormBase ]-----------------------------
    elsif ( $division eq "wormbase_parasite" ) {
        my $server   = 'https://parasite.wormbase.org';
        my $ext      = '/rest-9/info/genomes/?';
        my $response = $http->get( $server . $ext, { headers => { 'Content-type' => 'application/json' } } );

        die "Failed!\n" unless $response->{success};

        if ( length $response->{content} ) {
            my $hash = decode_json( $response->{content} );

            foreach my $genome (@$hash) {
                if ( !exists( $self->param('all_genomes')->{ $genome->{'species'} } ) ) {
                    $self->param('all_genomes')->{ $genome->{'species'} } = "production_reg_conf_wormbase.pl";
                }
            }
        }
    }

} ## end sub _get_species

1;
