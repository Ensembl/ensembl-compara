
=pod 

=head1 NAME

Bio::EnsEMBL::Hive::RunnableDB::DumpMultiAlign::InitJobs.pm

=head1 SYNOPSIS

This RunnableDB module is part of the DumpMultiAlign pipeline.

=head1 DESCRIPTION

This RunnableDB module creates 3 jobs: 1) gabs on chromosomes 2) gabs on 
supercontigs 3) gabs without $species (others)

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk

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
    my $compara_dba;

    #
    #Load registry and get compara database adaptor
    #
    if ($self->param('reg_conf')) {
	Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'),1);
	$compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('compara_dbname'), "compara");
    } elsif ($self->param('compara_url')) {
	#If define compara_url, must also define core_url(s)
	Bio::EnsEMBL::Registry->load_registry_from_url($self->param('compara_url'));
	if (!defined($self->param('core_url'))) {
	    throw("Must define core_url if define compara_url");
	}
	my @core_urls = split ",", $self->param('core_url');

	foreach my $core_url (@core_urls) {
	    Bio::EnsEMBL::Registry->load_registry_from_url($self->param('core_url'));
	}
	$compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$self->param('compara_url'));
    } else {
	Bio::EnsEMBL::Registry->load_all();
	$compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($self->param('compara_dbname'), "compara");
    }

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
    my $output_ids = $self->input_id;
    my $extra_args = ",\"mlss_id\" => \"". $self->param('mlss_id') . "\"";
    $extra_args .= ",\"genome_db_id\" => \"". $self->param('genome_db_id') . "\"";
    $extra_args .= ",\"filename\" => \"". $self->param('filename') ."\"";

    #Check if defined maf_output_dir to see if need to pass these parameters
    if ($self->param('maf_output_dir') ne "") {
	$extra_args .= ",\"emf2maf_program\" => \"". $self->param('emf2maf_program') ."\"";
	$extra_args .= ",\"maf_output_dir\" => \"". $self->param('maf_output_dir') ."\"";
    }

    $output_ids =~ s/}$/$extra_args}/;

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
