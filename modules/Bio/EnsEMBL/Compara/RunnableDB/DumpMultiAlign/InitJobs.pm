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

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::InitJobs.pm

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module creates 3 jobs: 1) gabs on chromosomes 2) gabs on 
supercontigs 3) gabs without $species (others)

=cut


package Bio::EnsEMBL::Compara::RunnableDB::DumpMultiAlign::InitJobs;

use strict;
use Bio::EnsEMBL::Hive::DBSQL::AnalysisDataAdaptor;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);

=head2 strict_hash_format

    Description : Implements strict_hash_format() interface method of Bio::EnsEMBL::Hive::Process that is used to set the strictness level of the parameters' parser.
                  Here we return 0 in order to indicate that neither input_id() nor parameters() is required to contain a hash.

=cut

sub strict_hash_format {
    return 0;
}

sub fetch_input {
    my $self = shift;

    my $file_prefix = "Compara";
    my $reg = "Bio::EnsEMBL::Registry";

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

    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor;
    my $genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('species'));
    $self->param('genome_db_id', $genome_db->dbID);

    #
    #If want to dump alignments and scores, need to find the alignment mlss
    #and store in param('mlss_id')
    #
    my $mlss_adaptor = $compara_dba->get_adaptor("MethodLinkSpeciesSet");
    $self->param('mlss_id', $self->param('dump_mlss_id'));
    my $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
    my $mlss_id = $self->param('mlss_id');
    if ($mlss->method_link_type eq "GERP_CONSERVATION_SCORE") {
	#Get meta_container adaptor
	my $meta_container = $compara_dba->get_MetaContainer;
	my $key = "gerp_$mlss_id";
	$self->param('mlss_id', $meta_container->list_value_by_key($key)->[0]);
    }

    $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
    my $filename = $mlss->name;
    $filename =~ tr/ /_/;
    $filename = $file_prefix . "." . $filename;
    $self->param('filename', $filename);
}

sub run {
    my $self = shift;

}

sub write_output {
    my $self = shift @_;

    #
    #Pass on input_id and add on new parameters: multi-align mlss_id, filename,
    #emf2maf
    #
    #my $output_ids = $self->input_id;
    my $output_ids;
    #my $extra_args = ",\"mlss_id\" => \"". $self->param('mlss_id') . "\"";
    my $extra_args = "\"mlss_id\" => \"". $self->param('mlss_id') . "\"";
    $extra_args .= ",\"genome_db_id\" => \"". $self->param('genome_db_id') . "\"";
    $extra_args .= ",\"filename\" => \"". $self->param('filename') ."\"";

    #$output_ids =~ s/}$/$extra_args}/;
    $output_ids = "{$extra_args}";

    #Set up chromosome job
    $self->dataflow_output_id($output_ids, 2);

    #Set up supercontig job
    $self->dataflow_output_id($output_ids, 3);

    #Set up other job
    $self->dataflow_output_id($output_ids, 4);

    #Automatic flow through to md5sum for emf files on branch 1
    #Needs to be here and not after Compress because need one md5sum per
    #directory NOT per file

    #Set up md5sum for emf2maf if necessary
    if ($self->param('maf_output_dir') ne "") {
	my $md5sum_output_ids = "{\"output_dir\"=>\"" . $self->param('maf_output_dir') . "\"}";
	$self->dataflow_output_id($md5sum_output_ids, 5);
    }

}

1;
