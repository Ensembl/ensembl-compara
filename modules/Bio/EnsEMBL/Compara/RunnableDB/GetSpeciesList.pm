
=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

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

    # ---------------[ Vertebrates / Non-Vertebrates ]----------------
    if ( $division =~ m/^(?:Ensembl)?(?<division>Fungi|Metazoa|Plants|Protists|Vertebrates)$/i ) {
        my $compara_division = lc $+{'division'};
        my $server           = 'https://rest.ensembl.org';
        my $ext              = '/info/species?';

        my %param_hash   = (
            'content-type' => 'application/json',
            'division' => 'Ensembl' . ucfirst($compara_division),
        );
        my @param_kv_pairs = map { $_ . '=' . $param_hash{$_} } sort keys %param_hash;
        my $params = join('&', @param_kv_pairs);

        my $response = $http->get( $server . $ext . $params );
        die "Failed!\n" unless $response->{'success'};
        if ( length $response->{'content'} ) {
            my $hash = decode_json( $response->{'content'} );

            foreach my $genome_count (keys %{$hash->{'species'}}) {
                $self->param('all_genomes')->{ $hash->{'species'}->[$genome_count]->{'name'} } = sprintf(
                    'production_reg_%s_conf.pl',
                    $compara_division,
                );
            }
        }
    }

    # -----------------------[ WormBase ]-----------------------------
    elsif ( $division eq "wormbase_parasite" ) {
        my $server     = 'https://parasite.wormbase.org';
        my $ext        = '/rest/info/genomes/?';
        my %param_hash = ( 'content-type' => 'application/json' );
        my $response   = $http->get( $server . $ext, \%param_hash );

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
