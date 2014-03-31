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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::CreateChrJobs

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the species chromosomes. The jobs are split into $split_size chunks

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateChrJobs;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

use POSIX qw(ceil);

sub fetch_input {
    my $self = shift;
}

sub run {
    my $self = shift;


}

sub write_output {
    my $self = shift @_;

    my $output_ids;

    #
    #Load registry and get compara database adaptor
    #
    if ($self->param('reg_conf')) {
	Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'),1);
    } elsif ($self->param('db_url')) {
	my $db_urls = $self->param('db_url');
	foreach my $db_url (@$db_urls) {
	    Bio::EnsEMBL::Registry->load_registry_from_url($db_url);
	}
    } else {
	Bio::EnsEMBL::Registry->load_all();
    }

    #Note this is using the database set in $self->param('compara_db') rather than the underlying compara database.
    my $compara_dba = $self->compara_dba;

    #
    #Find chromosome names and numbers of genomic_align_blocks
    #
    my $sql = qq {
    SELECT
       name,
       count(*)
    FROM
       dnafrag,
       genomic_align
    WHERE 
       dnafrag.dnafrag_id = genomic_align.dnafrag_id 
    AND 
       genome_db_id = ? 
    AND 
       coord_system_name = ? 
    AND 
       method_link_species_set_id = ? 
    GROUP BY name};

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('genome_db_id'), 
		  $self->param('coord_system_name'),
		  $self->param('mlss_id'));
    my ($name, $total_blocks);
    $sth->bind_columns(\$name,\$total_blocks);

    my $chr_blocks; 
    my $tag;
    if ($self->param('coord_system_name') eq "chromosome") {
	$tag = "chr";
    }

    my $compara_url = $self->param('compara_url');
    my $split_size = $self->param('split_size');
    my $format = $self->param('format');
    my $coord_system_name = $self->param('coord_system_name');

    if (defined($compara_url)) {
	#need to protect the @
	$compara_url =~ s/@/\\\\@/;
    }

    while (my $row = $sth->fetchrow_arrayref) {
	my $output_file = $self->param('filename') . "." . $tag . $name . "." . $self->param('format');
        $output_file=~s/[\(\)]+//g;
        $output_file=~s/-/_/g;


	my $num_chunks = ceil($total_blocks/$self->param('split_size'));

	#store chromosome name and number of chunks
	$chr_blocks->{$name} = $num_chunks;
	for (my $chunk = 1; $chunk <= $num_chunks; $chunk++) {

	    #Number of gabs in this chunk (used for healthcheck)
	    my $this_num_blocks = $split_size;
	    if ($chunk == $num_chunks) {
		$this_num_blocks = ($total_blocks - (($chunk-1)*$split_size));
	    }

	    my $this_suffix = "_" . $chunk . "." . $format;
	    my $dump_output_file = $output_file;
	    $dump_output_file =~ s/\.$format$/$this_suffix/;

	    #Write out cmd for DumpMultiAlign and a few other parameters 
	    #used in downstream analyses 
	    my $output_ids = "{\"coord_system\"=> \"$coord_system_name\", \"output_file\"=> \"$output_file\", \"extra_args\"=> \"--seq_region $name --chunk_num $chunk\", \"num_blocks\"=> $this_num_blocks, \"dumped_output_file\"=> \"$dump_output_file\", \"format\"=> \"$format\"}";

	    #print "$output_ids\n";
	    
	    $self->dataflow_output_id($output_ids, 2);
	}
    }



}

1;
