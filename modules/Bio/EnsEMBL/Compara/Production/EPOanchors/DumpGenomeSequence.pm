=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->write_output(); writes to disc and database

=head1 DESCRIPTION

Module to dump the genome sequences of a given set of species to disc.
It will also set up the jobs for mapping of anchors to those genomes if 
an anchor_batch_size is specified in the pipe-config file.  

=head1 AUTHOR - compara

This modules is part of the Ensembl project http://www.ensembl.org

Email http://lists.ensembl.org/mailman/listinfo/dev

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::DumpGenomeSequence;

use strict;
use Data::Dumper;
use File::Path qw(make_path remove_tree);
use Bio::EnsEMBL::Utils::IO::FASTASerializer;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my $seq_dump_loc = $self->param('seq_dump_loc');
	my $chunk_factor = $self->param('genome_chunk_size');
	my $seq_width = $self->param('seq_width');
	$seq_dump_loc = $seq_dump_loc . "/" . $self->param('genome_db_name') . "_" . $self->param('genome_db_assembly');
	make_path("$seq_dump_loc", {verbose => 1,});
	my $genome_db_adaptor = $self->compara_dba()->get_adaptor("GenomeDB");
	my $genome_db = $genome_db_adaptor->fetch_by_dbID( $self->param('genome_db_id') );
	my $dnafrag_adaptor = $self->compara_dba()->get_adaptor("DnaFrag");
	my $genome_dump_file = "$seq_dump_loc/genome_seq";
    $self->param('genome_dump_file', $genome_dump_file);
	open(my $filehandle, ">$genome_dump_file") or die "cant open $genome_dump_file\n";
    my $serializer = Bio::EnsEMBL::Utils::IO::FASTASerializer->new($filehandle,
		  sub{
			my $slice = shift;
			return join(":", $slice->coord_system_name(), $slice->coord_system->version(), 
					$slice->seq_region_name(), 1, $slice->length, 1); 
		}); 
    $serializer->chunk_factor($chunk_factor);
    $serializer->line_width($seq_width);
    $genome_db->db_adaptor->dbc->prevent_disconnect( sub {
            my $all_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db);
            foreach my $ref_dnafrag( @$all_dnafrags ) {
                next unless $ref_dnafrag->is_reference;
                next if ($ref_dnafrag->name=~/MT.*/i and $self->param('dont_dump_MT'));
                $serializer->print_Seq($ref_dnafrag->slice);
            }
        });
	close($filehandle);
}

sub run {
    my ($self) = @_;
    my $genome_dump_file = $self->param('genome_dump_file');
    my $batch_size = $self->param_required('anchor_batch_size');
    die "'anchor_batch_size' must be non-zero\n" unless $batch_size;
    # We only need a DBConnection here
    my $anchor_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param('compara_anchor_db') );
    my $sth = $anchor_dba->dbc->prepare("SELECT anchor_id, COUNT(*) ct FROM anchor_sequence GROUP BY anchor_id ORDER BY anchor_id");
    $sth->execute();
    my $count = 1;
    my @anchor_ids;
    my $min_anchor_id;
    my $max_anchor_id;
    while( my $ref = $sth->fetchrow_arrayref() ){
        next if($ref->[1] > $self->param('anc_seq_count_cut_off'));
        if (($count % $batch_size) == 1) {
            $min_anchor_id = $ref->[0];
            $max_anchor_id = $ref->[0];
        } else {
            $max_anchor_id = $ref->[0];
        }
        unless ($count % $batch_size) {
            push(@anchor_ids, { 'min_anchor_id' => $min_anchor_id, 'max_anchor_id' => $max_anchor_id, 'genome_db_file' => "$genome_dump_file",
                    'genome_db_id' => $self->param('genome_db_id'), });
            $min_anchor_id = undef;
        }
        $count++;
    }
    if (defined $min_anchor_id) {
        push(@anchor_ids, { 'min_anchor_id' => $min_anchor_id, 'max_anchor_id' => $max_anchor_id, 'genome_db_file' => "$genome_dump_file",
                'genome_db_id' => $self->param('genome_db_id'), });
    }
    $self->param('query_and_target', \@anchor_ids);
}

sub write_output {
	my ($self) = @_;
	return unless $self->param('query_and_target');
	$self->dataflow_output_id( $self->param('query_and_target'), 2) if $self->param('query_and_target');
}

1;

