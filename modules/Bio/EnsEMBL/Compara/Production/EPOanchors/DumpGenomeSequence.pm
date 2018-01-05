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

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence

=head1 DESCRIPTION

Module to dump the genome sequences of a given genome.

Input parameters

=over

=item genome_db_id

dbID of the GenomeDB to dump

=back

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence;

use strict;
use warnings;

use Data::Dumper;
use File::Basename;
use File::Path qw(make_path);

use Bio::EnsEMBL::Utils::IO::FASTASerializer;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub param_defaults {
    my $self = shift;
    return {
        %{ $self->SUPER::param_defaults },

        # Output location (only one of these two parameters has to be defined)
        'genome_dump_file'  => undef,   # Requested output file
        'seq_dump_loc'      => undef,   # Requested output directory

        # DnaFrag filtering
        'cellular_components_exclude'   => [],
        'cellular_components_only'      => [],

        # Parameters of Bio::EnsEMBL::Utils::IO::FASTASerializer
        # They have a default value in the serializer itself, but can be redefined here
        'seq_width'     => undef,   # Characters per line in the FASTA file. Defaults to 60
        'chunk_factor'  => undef,   # Number of lines to be buffered by the serializer. Defauls to 1,000
    }
}


sub fetch_input {
    my $self = shift;

    my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID( $self->param_required('genome_db_id') )
                     || die "Cannot find a GenomeDB with dbID=".$self->param('genome_db_id');

    my $genome_dump_file = $self->param('genome_dump_file');
    unless ($genome_dump_file) {
        my $seq_dump_loc = $self->param_required('seq_dump_loc');
        $genome_dump_file = $seq_dump_loc . "/" . $genome_db->name . "_" . $genome_db->assembly . ".fa";
        $self->param('genome_dump_file', $genome_dump_file);
    }
    make_path(dirname($genome_dump_file), {verbose => 1,});

    open(my $filehandle, '>', $genome_dump_file) or die "can't open $genome_dump_file for writing\n";
    my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($filehandle,
		  sub{
			my $slice = shift;
			return join(":", $slice->coord_system_name(), $slice->coord_system->version(), 
					$slice->seq_region_name(), 1, $slice->length, 1); 
		}); 
    $serializer->chunk_factor($self->param('chunk_factor'));
    $serializer->line_width($self->param('seq_width'));

    my $dnafrags = $self->compara_dba->get_DnaFragAdaptor->fetch_all_by_GenomeDB_region($genome_db, undef, undef, 1);
    $self->compara_dba->dbc->disconnect_if_idle();

    # Cellular-component filtering
    if (@{$self->param('cellular_components_only')}) {
        my %incl = map {$_ => 1} @{$self->param('cellular_components_only')};
        $dnafrags = [grep {$incl{$_->cellular_component}} @$dnafrags];
    }
    if (@{$self->param('cellular_components_exclude')}) {
        my %excl = map {$_ => 1} @{$self->param('cellular_components_exclude')};
        $dnafrags = [grep {!excl{$_->cellular_component}} @$dnafrags];
    }

    $genome_db->db_adaptor->dbc->prevent_disconnect( sub {
            foreach my $ref_dnafrag( @$dnafrags ) {
                $serializer->print_Seq($ref_dnafrag->slice);
            }
        });
	close($filehandle);
}

sub write_output {
    my ($self) = @_;
    $self->dataflow_output_id( {'genome_dump_file' => $self->param('genome_dump_file')} );
}

1;

