#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Registry;

my $conf_file;
my @speciesList = ();
my %hive_params;
my %nctree_params;

my %compara_conf = ();
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port);
my $verbose;

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'v' => \$verbose,
          );

if ($help) { usage(); }

Bio::EnsEMBL::Registry->no_version_check(1);

parse_conf($conf_file);

if($host)   { $compara_conf{'-host'}   = $host; }
if($port)   { $compara_conf{'-port'}   = $port; }
if($dbname) { $compara_conf{'-dbname'} = $dbname; }
if($user)   { $compara_conf{'-user'}   = $user; }
if($pass)   { $compara_conf{'-pass'}   = $pass; }


unless(defined($compara_conf{'-host'}) and defined($compara_conf{'-user'}) and defined($compara_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage();
}

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{gdba}   = $self->{'comparaDBA'}->get_GenomeDBAdaptor();
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}

$self->build_NCSystem();

exit(0);

#######################
#
# subroutines
#
#######################

sub usage {
  print "loadNCSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadNCSystem.pl v1.3\n";

  exit(1);
}

sub parse_conf {
  my($conf_file) = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      print("HANDLE type " . $confPtr->{TYPE} . "\n") if($verbose);
      if($confPtr->{TYPE} eq 'COMPARA') {
        %compara_conf = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'HIVE') {
        %hive_params = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @speciesList, $confPtr;
      }
      if($confPtr->{TYPE} eq 'NC_TREE') {
        %nctree_params = %{$confPtr};
      }
    }
  }
}
#
# need to make sure analysis 'SubmitGenome' is in database
# this is a generic analysis of type 'genome_db_id'
# the input_id for this analysis will be a genome_db_id
# the full information to access the genome will be in the compara database

sub build_NCSystem
{
  my $self = shift;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  my $analysisStatsDBA = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;
  my $analysisDBA = $self->{'hiveDBA'}->get_AnalysisAdaptor;
  my $stats;
  my $parameters = undef;

  #
  # SubmitGenome
  print STDERR "SubmitGenome\n";
  #
  my $submit_genome_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );

  $analysisDBA->store($submit_genome_analysis); # although it's stored in comparaLoadGenomes.pl
  $stats = $analysisStatsDBA->fetch_by_analysis_id($submit_genome_analysis->dbID);
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # GenomePrepareNCMembers
  print STDERR "GenomePrepareNCMembers\n";
  #
  my $genome_prepare_ncmembers_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomePrepareNCMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomePrepareNCMembers',
      -parameters      => "{type => 'ncRNA'}"
    );
  $analysisDBA->store($genome_prepare_ncmembers_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($genome_prepare_ncmembers_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(10);
  $stats->update();


  #
  # GeneStoreNCMembers
  print STDERR "GeneStoreNCMembers\n";
  #
  my $gene_store_ncmembers_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GeneStoreNCMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GeneStoreNCMembers',
      -parameters      => "{type => 'ncRNA'}"
    );
  $analysisDBA->store($gene_store_ncmembers_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($gene_store_ncmembers_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(20);
  $stats->update();


  #
  # RFAMLoadModels
  print STDERR "RFAMLoadModels\n";
  #
  my $rfam_load_models_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'RFAMLoadModels',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RFAMLoadModels'
    );
  $analysisDBA->store($rfam_load_models_analysis);
  $stats = $rfam_load_models_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # RFAMClassify
  print STDERR "RFAMClassify\n";
  #
  $parameters = "{";
  $parameters .= $nctree_params{'cluster_params'};
  $parameters .= "}";
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  my $rfam_classify_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'RFAMClassify',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RFAMClassify',
      -parameters      => $parameters
    );
  $analysisDBA->store($rfam_classify_analysis);
  $stats = $rfam_classify_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # NCRecoverEPO
  print STDERR "NCRecoverEPO\n";
  #
  $parameters = "{";
  $parameters .= $nctree_params{'recover_params'};
  $parameters .= "}";
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;

  my $ncrecover_epo_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCRecoverEPO',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCRecoverEPO',
      -parameters      => $parameters
    );
  $analysisDBA->store($ncrecover_epo_analysis);
  $stats = $ncrecover_epo_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # NCRecoverSearch
  print STDERR "NCRecoverSearch\n";
  #
  my $cmsearch_exe = $nctree_params{'cmsearch'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmsearch';
  my $ncrecover_search_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCRecoverSearch',
      -program_file    => $cmsearch_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCRecoverSearch',
    );
  $analysisDBA->store($ncrecover_search_analysis);
  $stats = $ncrecover_search_analysis->stats;
  $stats->batch_size(5);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(500);
  $stats->update();

  #
  # Infernal
  print STDERR "Infernal\n";
  #
  my $cmbuild_exe = $nctree_params{'cmbuild'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmbuild';
  $parameters = "{'cmbuild_exe'=>'$cmbuild_exe'";
  if (defined $nctree_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$nctree_params{'max_gene_count'};
  }
  if (defined $nctree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$nctree_params{'honeycomb_dir'}."'";
  }
  $parameters .= "}";

  my $infernal_exe = $nctree_params{'infernal'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmalign';

  my $infernal_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Infernal',
      -program_file    => $infernal_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Infernal',
      -parameters      => $parameters
    );
  $analysisDBA->store($infernal_analysis);
  $stats = $infernal_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # NCSecStructTree
  print STDERR "NCSecStructTree\n";
  #
  $parameters = "{'method'=>'ncsecstructtree1'";
  if (defined $nctree_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$nctree_params{'max_gene_count'};
  }
  if (defined $nctree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$nctree_params{'honeycomb_dir'}."'";
  }
  $parameters .= "}";

  my $ncsecstructtree_exe = $nctree_params{'ncsecstructtree'} || '/nfs/users/nfs_a/avilella/src/raxml/latest/RAxML-7.2.6/raxmlHPC-PTHREADS-SSE3';

  my $ncsec_struct_tree_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCSecStructTree',
      -program_file    => $ncsecstructtree_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCSecStructTree',
      -parameters      => $parameters
    );
  $analysisDBA->store($ncsec_struct_tree_analysis);
  $stats = $ncsec_struct_tree_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # NCGenomicAlignment
  print STDERR "NCGenomicAlignment\n";
  #
  my $treebest_exe = $nctree_params{'treebest'} || '/nfs/acari/avilella/src/treesoft/trunk/treebest_ncrna/treebest';
  $parameters = "{'treebest_exe'=>'$treebest_exe'";
  if (defined $nctree_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$nctree_params{'max_gene_count'};
  }
  if (defined $nctree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$nctree_params{'honeycomb_dir'}."'";
  }
  $parameters .= "}";

  my $ncgenomicalignment_exe = $nctree_params{'ncgenomicalignment'} || '/software/ensembl/compara/prank/091007/src/prank';

  my $nc_genomic_alignment_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCGenomicAlignment',
      -program_file    => $ncgenomicalignment_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCGenomicAlignment',
      -parameters      => $parameters
    );
  $analysisDBA->store($nc_genomic_alignment_analysis);
  $stats = $nc_genomic_alignment_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(20);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # NCTreeBestMMerge
  print STDERR "NCTreeBestMMerge\n";
  #
  $parameters = "{rna=>1,bootstrap=>1";
  if (defined $nctree_params{'max_gene_count'}) {
    $parameters .= ",max_gene_count=>".$nctree_params{'max_gene_count'};
  }
  if ($nctree_params{'species_tree_file'}){
    $parameters .= ",'species_tree_file'=>'". $nctree_params{'species_tree_file'}."'";
  } else {
    warn("No species_tree_file => 'myfile' has been set in your config file. "
         ."This parameter can not be set for njtree. EXIT 3\n");
    exit(3);
  }
  if (defined $nctree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$nctree_params{'honeycomb_dir'}."'";
  }

  $parameters .= ", 'use_genomedb_id'=>1" if defined $nctree_params{use_genomedb_id};

  $parameters .= "}";
  my $treebest_mmerge_analysis_data_id = $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($parameters);
  if (defined $treebest_mmerge_analysis_data_id) {
    $parameters = "{'treebest_mmerge_data_id'=>'$treebest_mmerge_analysis_data_id'}";
  }
  my $tree_best_program = $nctree_params{'treebest'} || '/nfs/acari/avilella/src/treesoft/trunk/treebest_ncrna/treebest';
  my $nc_treebest_mmerge_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCTreeBestMMerge',
      -program_file    => $tree_best_program,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCTreeBestMMerge',
      -parameters      => $parameters
    );
  $analysisDBA->store($nc_treebest_mmerge_analysis);
  $stats = $nc_treebest_mmerge_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(20);
  my $njtree_hive_capacity = $hive_params{'njtree_hive_capacity'};
  $njtree_hive_capacity = 400 unless defined $njtree_hive_capacity;
  $stats->hive_capacity($njtree_hive_capacity);
  $stats->update();

  #
  # NCOrthoTree
  print STDERR "NCOrthoTree\n";
  #
  my $with_options_orthotree = 0;
  my $ortho_params = '';
  if (defined $nctree_params{'honeycomb_dir'}) {
    $ortho_params = "'honeycomb_dir'=>'".$nctree_params{'honeycomb_dir'}."'";
    $with_options_orthotree = 1;
  }
  if(defined $nctree_params{'species_tree_file'}) {
    my $tree_file = $nctree_params{'species_tree_file'};
    $ortho_params .= ",'species_tree_file'=>'${tree_file}'";
    $with_options_orthotree = 1;
  }

  $ortho_params .= ", 'use_genomedb_id'=>1" if defined $nctree_params{use_genomedb_id};

  #EDIT Originally created a anon hash which caused problems with OrthoTree when using eval
  if($with_options_orthotree) {
    $parameters =~ s/\A{//;
    $parameters =~ s/}\Z//;
    $parameters = '{' . $parameters . ',' .  $ortho_params . '}'
  }

  my $analysis_data_id = $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($parameters);
  if (defined $analysis_data_id) {
    $parameters = "{'analysis_data_id'=>'$analysis_data_id'}";
  }

  my $nc_orthotree_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCOrthoTree',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCOrthoTree',
      -parameters      => $parameters
      );
  $analysisDBA->store($nc_orthotree_analysis);
  $stats = $nc_orthotree_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(10);
  my $ortho_tree_hive_capacity = $hive_params{'ortho_tree_hive_capacity'};
  $ortho_tree_hive_capacity = 200 unless defined $ortho_tree_hive_capacity;
  $stats->hive_capacity($ortho_tree_hive_capacity);
  $stats->update();

  #
  # Ktreedist
  print STDERR "Ktreedist\n";
  #
  my $ktreedist_exe = $nctree_params{'ktreedist_exe'} || '/software/ensembl/compara/ktreedist/Ktreedist.pl';

  my $ktreedist_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Ktreedist',
      -program_file    => $ktreedist_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Ktreedist',
    );
  $analysisDBA->store($ktreedist_analysis);
  $stats = $ktreedist_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();



  #
  # build graph of control and dataflow rules
  #

  $dataflowRuleDBA->create_rule($submit_genome_analysis, $genome_prepare_ncmembers_analysis);
  $dataflowRuleDBA->create_rule($genome_prepare_ncmembers_analysis, $gene_store_ncmembers_analysis);

  $ctrlRuleDBA->create_rule($gene_store_ncmembers_analysis, $rfam_load_models_analysis); # funnel

  $dataflowRuleDBA->create_rule($rfam_load_models_analysis, $rfam_classify_analysis);    # backbone
  $dataflowRuleDBA->create_rule($rfam_classify_analysis, $ncrecover_epo_analysis, 2);    # fan

  $dataflowRuleDBA->create_rule($ncrecover_epo_analysis, $ncrecover_search_analysis, 1);
  $dataflowRuleDBA->create_rule($ncrecover_search_analysis, $infernal_analysis, 1);
  $dataflowRuleDBA->create_rule($infernal_analysis, $ncsec_struct_tree_analysis, 1);
  $dataflowRuleDBA->create_rule($ncsec_struct_tree_analysis, $nc_genomic_alignment_analysis, 1);
  $dataflowRuleDBA->create_rule($nc_genomic_alignment_analysis, $nc_treebest_mmerge_analysis, 1);

  $dataflowRuleDBA->create_rule($nc_treebest_mmerge_analysis, $nc_orthotree_analysis, 1);
  $dataflowRuleDBA->create_rule($nc_treebest_mmerge_analysis, $ktreedist_analysis, 1);

  #
  print STDERR "Create initial jobs\n";
  # create initial jobs
  #

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => '{}',
        -analysis       => $rfam_load_models_analysis,
  );

  print STDERR "Finished\n";

  return 1;
}


