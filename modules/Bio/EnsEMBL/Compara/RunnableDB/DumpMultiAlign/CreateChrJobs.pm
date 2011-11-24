=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

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
use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

use POSIX qw(ceil);

=head2 strict_hash_format

    Description : Implements strict_hash_format() interface method of Bio::EnsEMBL::Hive::Process that is used to set the strictness level of the parameters' parser.
                  Here we return 0 in order to indicate that neither input_id() nor parameters() is required to contain a hash.

=cut

sub strict_hash_format {
    return 0;
}

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

    my $compara_dba = $self->go_figure_compara_dba($self->param('compara_db'));

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
