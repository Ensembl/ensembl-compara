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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::CreateSuperJobs

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module generates DumpMultiAlign jobs from genomic_align_blocks
on the species supercontigs. The jobs are split into $split_size chunks

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::CreateSuperJobs;

use strict;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use POSIX qw(ceil);

=head2 strict_hash_format

    Description : Implements strict_hash_format() interface method of Bio::EnsEMBL::Hive::Process that is used to set the strictness level of the parameters' parser.
                  Here we return 0 in order to indicate that neither input_id() nor parameters() is required to contain a hash.

=cut

#sub strict_hash_format {
#    return 0;
#}

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
    #Find supercontigs and number of genomic_align_blocks
    #
    my $sql = "
    SELECT count(*) 
    FROM genomic_align 
    LEFT JOIN dnafrag 
    USING (dnafrag_id) 
    WHERE coord_system_name = ? 
    AND genome_db_id= ? 
    AND method_link_species_set_id=?";

    my $sth = $compara_dba->dbc->prepare($sql);
    $sth->execute($self->param('coord_system_name'),$self->param('genome_db_id'), $self->param('mlss_id'));
    my ($total_blocks) = $sth->fetchrow_array;
    
    my $tag = $self->param('coord_system_name');
    #my $output_file = $self->param('output_dir') ."/" . $self->param('filename') . "." . $tag . "." . $self->param('format');
    my $output_file = $self->param('filename') . "." . $tag . "." . $self->param('format');
    
    my $format = $self->param('format');
    my $coord_system_name = $self->param('coord_system_name');
    #This doesn't work because DumpMultiAlignment adds _1 to the output file and can create more if there are lots of supercontigs.
    #Since I create only one job, the compress will only start when all the chunks have been produced (if more than one) so I can use "*"
    #my $this_suffix = "." . $format;
    my $this_suffix = "*" . "." . $format;
    my $dump_output_file = $output_file;
    $dump_output_file =~ s/\.$format/$this_suffix/;
	
    #Write out cmd for DumpMultiAlign and a few other parameters 
    #used in downstream analyses 
    $output_ids = "{\"coord_system\"=> \"$coord_system_name\", \"output_file\"=> \"$output_file\", \"num_blocks\"=> $total_blocks, \"dumped_output_file\"=> \"$dump_output_file\", \"format\"=> \"$format\"}";

    $self->dataflow_output_id($output_ids, 2);
}

1;
