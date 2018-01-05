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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CreateCompleteChunkedJobs

=head1 SYNOPSIS

This RunnableDB module is part of the AncestralAllelesForIndels pipeline.

=head1 DESCRIPTION

This RunnableDB module splits the seq_region into regions of chunk_size and creates a create_sub_chunk_job. 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::AncestralAllelesForIndels::CreateCompleteChunkedJobs;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Variation::DBSQL::DBAdaptor;
use File::Path qw(make_path);

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;

}

sub write_output {
    my $self = shift @_;

    my $compara_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-url=>$self->param('compara_url'));

    my $ref_species = $self->param('ref_species');

    my $genome_db_adaptor = $self->compara_dba->get_genomeDBAdaptor;
    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly($ref_species);
    my $slice_adaptor = $genome_db->db_adaptor->get_SliceAdaptor;

    my $sql = qq {
    SELECT
       dnafrag.name,
       length,
       min(dnafrag_start),
       max(dnafrag_end)
    FROM
       dnafrag JOIN genomic_align USING (dnafrag_id) JOIN genome_db USING (genome_db_id) WHERE method_link_species_set_id=? AND genome_db.name=? };


    if ($self->param('seq_region')) {
	$sql .= " AND dnafrag.name = " . $self->param('seq_region');
    }

    $sql .= " GROUP BY dnafrag_id";

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('mlss_id'), $self->param('ref_species'));

    my $length = $self->param('length');

    my ($seq_region, $length, $min_dnafrag_start, $max_dnafrag_end);
    $sth->bind_columns(\$seq_region,\$length,\$min_dnafrag_start,\$max_dnafrag_end);

    my $chunk_size = $self->param('chunk_size');

    while (my $row = $sth->fetchrow_arrayref) {
        #skip the first part of the chr if there are no alignments. Round down
        my $this_start = int($min_dnafrag_start/$chunk_size) * $chunk_size;

        #quick sanity check!
        if ($this_start > $min_dnafrag_start) {
            die "Something has gone wrong! Start ($this_start) should be smaller than the min(dnafrag_start) ($min_dnafrag_start)";
        }

        #Need to add to statistics table
        $self->update_statistics_table($this_start, $seq_region);

	my $chunk = $this_start+1;
	while ($chunk <= $length) {
	    my $seq_region_start = $chunk;

	    $chunk += $chunk_size;
	    my $seq_region_end = $chunk - 1;
	    if ($seq_region_end > $length) {
		$seq_region_end = $length;
	    }

            #mkdir to put sub-chunks into
            my $dirname = $self->param('work_dir') . "/" . $seq_region . "/" . $seq_region_start . "_" . $seq_region_end;
            #mkdir $dirname;
            make_path($dirname);
            die "Cannot create directory $dirname : $!\n" unless -d $dirname;

            #Create ancestral_alleles_for_indels jobs
            my $output_ids = {'seq_region'=> $seq_region,
			      'seq_region_start' => $seq_region_start,
                              'seq_region_end' => $seq_region_end};
            
            $self->dataflow_output_id($output_ids, 2);
	}
    }
}

sub update_statistics_table {
    my ($self, $length, $seq_region) = @_;

    
    my $sql = "INSERT INTO statistics (seq_region, seq_region_start, seq_region_end, total_bases, no_gat) VALUES (?,?,?,?,?)";

    my $sth = $self->compara_dba->dbc->prepare($sql);
    $sth->execute($seq_region, 1, $length, $length, $length);
}

1;
