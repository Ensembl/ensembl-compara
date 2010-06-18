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
my %analysis_template;
my @speciesList = ();
my %hive_params;
my %dnds_params;
my %sitewise_dnds_params;
my %genetree_params;

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
           'v'        => \$verbose,
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

if(%analysis_template and (not(-d $analysis_template{'fasta_dir'})) and (not(-d $analysis_template{'cluster_dir'})) ) {
  die("\nERROR!!\n  ". $analysis_template{'fasta_dir'} . ' fasta_dir or ' . $analysis_template{'cluster_dir'} . " cluster_dir doesn't exist, can't configure\n");
}

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'comparaDBA'} = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}    = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}

$self->build_GeneTreeSystem();

exit(0);

#######################
#
# subroutines
#
#######################

sub usage {
  print "loadGeneTreeSystem.hcluster_tablereuse.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadGeneTreeSystem.hcluster_tablereuse.pl v1.0\n";

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
      if(($confPtr->{TYPE} eq 'BLAST_TEMPLATE') or ($confPtr->{TYPE} eq 'BLASTP_TEMPLATE')) {
        %analysis_template = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'HIVE') {
        %hive_params = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'dNdS') {
        %dnds_params = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'sitewise_dNdS') {
        %sitewise_dnds_params = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @speciesList, $confPtr;
      }
      if($confPtr->{TYPE} eq 'GENE_TREE') {
        %genetree_params = %{$confPtr};
      }
    }
  }
}
#
# need to make sure analysis 'SubmitGenome' is in database
# this is a generic analysis of type 'genome_db_id'
# the input_id for this analysis will be a genome_db_id
# the full information to access the genome will be in the compara database
# also creates 'GenomeLoadMembers' analysis and
# 'GenomeDumpFasta' analysis in the 'genome_db_id' chain

sub build_GeneTreeSystem
{
  #yes this should be done with a config file and a loop, but...
  my $self = shift;

  my $dataflowRuleDBA  = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA      = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  my $analysisStatsDBA = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;
  my $analysisDBA      = $self->{'hiveDBA'}->get_AnalysisAdaptor;
  my $stats;

  #
  # SubmitGenome
  print STDERR "SubmitGenome...\n";
  #
  my $submit_genome_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitGenome',
#      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );

  $analysisDBA->store($submit_genome_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($submit_genome_analysis->dbID);
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  return $submit_genome_analysis unless($analysis_template{fasta_dir});

  #
  # blast_template
  #
  # create an unlinked analysis called blast_template
  # it will not have rules so it will never execute
  # used to store module,parameters... to be used as template for
  # the dynamic creation of the analyses like blast_1_NCBI34

  #Have to generate new parameters & not use analysis_template as
  #that now has keys which are not prefixed by a -
  #Since hash order is unpredictable this causes problems with rearrange
  my %new_params = map { $_ => $analysis_template{$_} } grep {$_ =~ /^-/} keys(%analysis_template);

  my $blast_template_analysis = Bio::EnsEMBL::Analysis->new(%new_params);
  $blast_template_analysis->logic_name("blast_template");
  my $blast_template_analysis_data_id =
    $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($blast_template_analysis->parameters);
  my $parameters = undef;
  if (defined $blast_template_analysis_data_id) {
    $parameters = "{'blast_template_analysis_data_id'=>'$blast_template_analysis_data_id'}";
    $blast_template_analysis->parameters($parameters);
  }
  eval { $analysisDBA->store($blast_template_analysis); };

  #
  # GenomeLoadReuseMembers
  print STDERR "GenomeLoadReuseMembers...\n";
  #
  # Uses GenomeLoadReuseMembers and will not execute run section if it's a new genome
  my $genome_load_reuse_members_analysis =  Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeLoadReuseMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadReuseMembers',
      -parameters      => $blast_template_analysis->parameters
    );
  $analysisDBA->store($genome_load_reuse_members_analysis);
  $stats  =  $analysisStatsDBA->fetch_by_analysis_id($genome_load_reuse_members_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();

  $dataflowRuleDBA->create_rule($submit_genome_analysis, $genome_load_reuse_members_analysis);

  #
  # GenomeLoadMembers
  print STDERR "GenomeLoadMembers...\n";
  #
  # Uses GenomeLoadReuseMembers but will not execute run section if it's a reused genome
  my $genome_load_members_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeLoadMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeLoadReuseMembers',
      -parameters      => $blast_template_analysis->parameters
    );
  $analysisDBA->store($genome_load_members_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($genome_load_members_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(-1); #unlimited
  $stats->update();

  $dataflowRuleDBA->create_rule($submit_genome_analysis, $genome_load_members_analysis);

#  #
#  # LoadUniProt
#  print STDERR "LoadUniProt...\n";
#  #
#  # Only needed to load uniprot sequences. Used for the MCL Families pipeline
#  my $load_uniprot_analysis = Bio::EnsEMBL::Analysis->new(
#        -db_version      => '1',
#        -logic_name      => 'LoadUniProt',
#        -module          => 'Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt',
#      );
#  $analysisDBA->store($load_uniprot_analysis);
#  $stats = $analysisStatsDBA->fetch_by_analysis_id($load_uniprot_analysis->dbID);
#  $stats->batch_size(1);
#  $stats->hive_capacity(-1);
#  $stats->failed_job_tolerance(100); # This wont block the main pipeline
#  $stats->status('LOADING');
#  $stats->update();

  #
  # BlastSubsetStaging
  print STDERR "BlastSubsetStaging...\n";
  #
  my $blast_subset_staging_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'BlastSubsetStaging',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );
  $analysisDBA->store($blast_subset_staging_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($blast_subset_staging_analysis->dbID);
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  $dataflowRuleDBA->create_rule($genome_load_members_analysis, $blast_subset_staging_analysis);

#  $dataflowRuleDBA->create_rule($load_uniprot_analysis, $blast_subset_staging_analysis, 2);

  #
  # GenomeSubmitPep
  print STDERR "GenomeSubmitPep...\n";
  #
  my $genome_submit_pep_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeSubmitPep',
#      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeSubmitPep'
    );
  $analysisDBA->store($genome_submit_pep_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($genome_submit_pep_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();

  $dataflowRuleDBA->create_rule($blast_subset_staging_analysis, $genome_submit_pep_analysis);

  # GenomeDumpFasta does not use the normal eval method of parameter loading so this is why
  # our hash lookie-like structure is not a real evallable hash
  my @dump_fasta_params = ("fasta_dir => $analysis_template{fasta_dir}");
  my $blast_hive_capacity = $hive_params{'blast_hive_capacity'};
  push(@dump_fasta_params, "blast_hive_capacity => ${blast_hive_capacity}") if defined $blast_hive_capacity;
  my $dump_fasta_params_str = join(',', @dump_fasta_params);

  #
  # GenomeDumpFasta
  print STDERR "GenomeDumpFasta...\n";
  #
  my $genome_dump_fasta_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomeDumpFasta',
#      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomeDumpFasta',
      -parameters      => $dump_fasta_params_str,
    );
  $analysisDBA->store($genome_dump_fasta_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($genome_dump_fasta_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->update();

  $dataflowRuleDBA->create_rule($blast_subset_staging_analysis, $genome_dump_fasta_analysis);

  #
  # CreateBlastRules
  print STDERR "CreateBlastRules...\n";
  #
  # Only run the next analysis, CreateHclusterPrepareJobs, when all blasts are finished
  $parameters = "{phylumBlast=>0, selfBlast=>1,cr_analysis_logic_name=>'CreateHclusterPrepareJobs'}";
  my $create_blast_rules_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateBlastRules',
#      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateBlastRules',
      -parameters      => $parameters
    );
  $analysisDBA->store($create_blast_rules_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($create_blast_rules_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(1);
  $stats->status('BLOCKED');
  $stats->update();

  $ctrlRuleDBA->create_rule($genome_load_reuse_members_analysis, $create_blast_rules_analysis);
  $ctrlRuleDBA->create_rule($genome_load_reuse_members_analysis, $genome_load_members_analysis);
  $ctrlRuleDBA->create_rule($genome_load_members_analysis, $create_blast_rules_analysis);
  $ctrlRuleDBA->create_rule($blast_subset_staging_analysis, $create_blast_rules_analysis);
  $ctrlRuleDBA->create_rule($genome_submit_pep_analysis, $create_blast_rules_analysis);
  $ctrlRuleDBA->create_rule($genome_dump_fasta_analysis, $create_blast_rules_analysis);

  $dataflowRuleDBA->create_rule($genome_dump_fasta_analysis, $create_blast_rules_analysis);

  #
  # BlastTableReuse
  print STDERR "BlastTableReuse...\n";
  #
  my $blast_table_reuse_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'BlastTableReuse',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::BlastTableReuse',
      -parameters      => $blast_template_analysis->parameters
    );
  $analysisDBA->store($blast_table_reuse_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($blast_table_reuse_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(4);
  $stats->update();

  $dataflowRuleDBA->create_rule($genome_load_reuse_members_analysis, $blast_table_reuse_analysis);
  $ctrlRuleDBA->create_rule($blast_table_reuse_analysis, $create_blast_rules_analysis); # new

  #
  # Create peptide_align_feature per-species tables
  print STDERR "Create peptide_align_feature_ per-species tables...\n";
  #
  foreach my $speciesPtr (@speciesList) {
    my $gdb_id = $speciesPtr->{'genome_db_id'};
    my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor()->fetch_by_dbID($gdb_id)
        || die( "Cannot fetch_by_dbID genome_db $gdb_id" );
    my $species_name = lc($gdb->name);
    $species_name =~ s/\ /\_/g;
    my $tbl_name = "peptide_align_feature"."_"."$species_name"."_"."$gdb_id";
    my $sql = "CREATE TABLE IF NOT EXISTS $tbl_name like peptide_align_feature";

    print STDERR "## $sql\n";
    my $sth = $self->{'comparaDBA'}->dbc->prepare($sql);
    $sth->execute();
  }

  #
  # CreateStoreSeqExonBoundedJobs
  print STDERR "CreateStoreSeqExonBoundedJobs...\n";
  #
  $parameters = $genetree_params{'cluster_params'};
  my $create_store_seq_exon_bounded_jobs_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateStoreSeqExonBoundedJobs',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateStoreSeqExonBoundedJobs',
      -parameters      => $parameters
  );
  $analysisDBA->store($create_store_seq_exon_bounded_jobs_analysis);

  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($create_store_seq_exon_bounded_jobs_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
  }


  #
  # CreateStoreSeqCDSJobs
  print STDERR "CreateStoreSeqCDSJobs...\n";
  #
  $parameters = $genetree_params{'cluster_params'};
  my $create_store_seq_cds_jobs_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateStoreSeqCDSJobs',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateStoreSeqCDSJobs',
      -parameters      => $parameters
  );
  $analysisDBA->store($create_store_seq_cds_jobs_analysis);

  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($create_store_seq_cds_jobs_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
  }


  #
  # StoreSeqExonBounded
  print STDERR "StoreSeqExonBounded...\n";
  #
  my $store_seq_exon_bounded_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'StoreSeqExonBounded',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::StoreSeqExonBounded',
      -parameters      => $blast_template_analysis->parameters
    );
  $analysisDBA->store($store_seq_exon_bounded_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($store_seq_exon_bounded_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(200);
  $stats->update();

  #
  # StoreSeqCDS
  print STDERR "StoreSeqCDS...\n";
  #
  my $store_seq_cds_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'StoreSeqCDS',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::StoreSeqCDS',
      -parameters      => $blast_template_analysis->parameters
    );
  $analysisDBA->store($store_seq_cds_analysis);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($store_seq_cds_analysis->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(200);
  $stats->update();

  #
  # CreateHclusterPrepareJobs
  print STDERR "CreateHclusterPrepareJobs...\n";
  #
  # FIXME
  $parameters = $genetree_params{'cluster_params'};
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  $parameters = '{' . $parameters . ",cluster_dir=>'" . $analysis_template{cluster_dir} . "'}";

  my $create_hcluster_prepare_jobs_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateHclusterPrepareJobs',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateHclusterPrepareJobs',
      -parameters      => $parameters
  );
  $analysisDBA->store($create_hcluster_prepare_jobs_analysis);

  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($create_hcluster_prepare_jobs_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
  }

  #
  # HclusterPrepare
  print STDERR "HclusterPrepare...\n";
  #
  $parameters = $genetree_params{'cluster_params'};
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  $parameters = '{' . $parameters . ",cluster_dir=>'" . $analysis_template{cluster_dir} . "'}";
  my $hcluster_prepare_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'HclusterPrepare',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HclusterPrepare',
      -parameters      => $parameters
    );
  $analysisDBA->store($hcluster_prepare_analysis);
  $stats = $hcluster_prepare_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(4);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # HclusterRun
  print STDERR "HclusterRun...\n";
  #
  $parameters = $genetree_params{'cluster_params'};
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  $parameters = '{' . $parameters . ",cluster_dir=>'" . $analysis_template{cluster_dir} . "'}";
  my $hcluster_run_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'HclusterRun',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HclusterRun',
      -parameters      => $parameters
    );

  if(exists $genetree_params{hcluster_sg}) {
  	$hcluster_run_analysis->program_file($genetree_params{hcluster_sg});
  }

  $analysisDBA->store($hcluster_run_analysis);
  $stats = $hcluster_run_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # ClustersetQC
  print STDERR "ClustersetQC...\n";
  #
  $parameters = $blast_template_analysis->parameters;
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  $parameters =  $parameters . ",cluster_dir=>'" . $analysis_template{cluster_dir} . "'";
  $parameters = '{' . $parameters . ",groupset_tag=>'" . 'ClustersetQC' . "'}";
  my $clusterset_qc_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'ClustersetQC',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GroupsetQC',
      -parameters      => $parameters
    );

  $analysisDBA->store($clusterset_qc_analysis);
  $stats = $clusterset_qc_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(3);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # Clusterset_staging
  print STDERR "Clusterset_staging...\n";
  #
  my $clusterset_staging_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Clusterset_staging',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
    );
  $analysisDBA->store($clusterset_staging_analysis);
  $stats = $clusterset_staging_analysis->stats;
  $stats->batch_size(-1);
  $stats->hive_capacity(1);
  $stats->update();

  #
  # MCoffee
  print STDERR "MCoffee...\n";
  #
  $parameters = "{'method'=>'cmcoffee'";
  
  my $exon_boundaries = (defined $genetree_params{exon_boundaries}) ? $genetree_params{exon_boundaries} : 2; 
  if($exon_boundaries) {
    $parameters .= qq{, use_exon_boundaries => $exon_boundaries};
  }
  if (defined $genetree_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$genetree_params{'max_gene_count'};
  }
  if (defined $genetree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'}."'";
  }
  if(defined $genetree_params{mafft}) {
  	$parameters .= qq|, 'mafft' => '$genetree_params{mafft}'|;
  }
  $parameters .= "}";

  my $mcoffee_exe = $genetree_params{'mcoffee'} || '/software/ensembl/compara/tcoffee-7.86b/t_coffee';

  my $mcoffee_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'MCoffee',
      -program_file    => $mcoffee_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::MCoffee'
    );

  #If params exceed 254 then use the analysis_data table.
  if(length($parameters) > 254) {
  	my $ad_dba =  $self->{'hiveDBA'}->get_AnalysisDataAdaptor();
   	my $adi = $ad_dba->store_if_needed($parameters);
   	$parameters = "{'analysis_data_id'=>${adi}}";
  }

  $mcoffee_analysis->parameters($parameters);

  $analysisDBA->store($mcoffee_analysis);
  $stats = $mcoffee_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(600);
  $stats->update();

#   #
#   # Muscle
#   #
#   $parameters = "{'options'=>'-maxhours 5'";
#   if (defined $genetree_params{'max_gene_count'}) {
#     $parameters .= ",'max_gene_count'=>".$genetree_params{'max_gene_count'};
#   }
#   if (defined $genetree_params{'honeycomb_dir'}) {
#     $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'}."'";
#   }
#   $parameters .= "}";

#   my $muscle_exe = $genetree_params{'muscle'} || '/usr/local/ensembl/bin/muscle';

#   my $muscle = Bio::EnsEMBL::Analysis->new(
#       -logic_name      => 'Muscle',
#       -program_file    => $muscle_exe,
#       -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Muscle',
#       -parameters      => $parameters
#     );
#   $analysisDBA->store($muscle);
#   $stats = $muscle->stats;
#   $stats->batch_size(1);
#   $stats->hive_capacity(-1);
#   $stats->update();

  #
  # NJTREE_PHYML
  print STDERR "NJTREE_PHYML...\n";
  #
  $parameters = "{cdna=>1,bootstrap=>1";
  if (defined $genetree_params{'max_gene_count'}) {
    $parameters .= ",max_gene_count=>".$genetree_params{'max_gene_count'};
  }
  if ($genetree_params{'species_tree_file'}){
    $parameters .= ",'species_tree_file'=>'". $genetree_params{'species_tree_file'}."'";
    # TODO -- insert species_tree_string into DB:
    # Open $genetree_params{'species_tree_file'}, load string into variable, do insert like this:
    # insert into protein_tree_tag (node_id,tag,value) values (1,'species_tree_string',$string)"
  } else {
    warn("No species_tree_file => 'myfile' has been set in your config file. "
         ."This parameter can not be set for njtree. EXIT 3\n");
    exit(3);
  }
  if (defined $genetree_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'}."'";
  }
  if (defined $genetree_params{'gs_mirror'}) {
    $parameters .= ",'gs_mirror'=>'".$genetree_params{'gs_mirror'}."'";
  }

  $parameters .= ", 'use_genomedb_id'=>1" if defined $genetree_params{use_genomedb_id};

  $parameters .= "}";
  my $njtree_phyml_analysis_data_id = $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($parameters);
  if (defined $njtree_phyml_analysis_data_id) {
    $parameters = "{'njtree_phyml_analysis_data_id'=>'$njtree_phyml_analysis_data_id'}";
  }
  my $tree_best_program = $genetree_params{'treebest'} || '/nfs/users/nfs_a/avilella/src/treesoft/trunk/treebest/treebest';
  my $njtree_phyml_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NJTREE_PHYML',
      -program_file    => $tree_best_program,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NJTREE_PHYML',
      -parameters      => $parameters
    );
  $analysisDBA->store($njtree_phyml_analysis);
  $stats = $njtree_phyml_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(5); # Some of the biggest clusters can fail and go through the other options
  my $njtree_hive_capacity = $hive_params{'njtree_hive_capacity'};
  $njtree_hive_capacity = 400 unless defined $njtree_hive_capacity;
  $stats->hive_capacity($njtree_hive_capacity);
  $stats->update();

  #
  # Change $dnds_params{'method_link_type'} to {'method_link_types'}
  #
  if( defined( $dnds_params{'method_link_type'} ) ){
    warn('[WARN] dNdS => method_link_type is deprecated. '
         .'Use method_link_types instead');
    $dnds_params{'method_link_types'}
      ||= '['. $dnds_params{'method_link_type'} . ']';
  }

  #
  # OrthoTree
  print STDERR "OrthoTree...\n";
  #
  my $with_options_orthotree = 0;
  my $ortho_params = '';
  if (defined $genetree_params{'honeycomb_dir'}) {
    $ortho_params = "'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'}."'";
    $with_options_orthotree = 1;
  }
  if (defined $dnds_params{'species_sets'}) {
    $ortho_params .= ',species_sets=>' . $dnds_params{'species_sets'};
    if( defined $dnds_params{'method_link_types'} ){
      $ortho_params .= ',method_link_types=>'
          . $dnds_params{'method_link_types'};
    }
    $with_options_orthotree = 1;
  }
  if(defined $genetree_params{'species_tree_file'}) {
    my $tree_file = $genetree_params{'species_tree_file'};
    $ortho_params .= ",'species_tree_file'=>'${tree_file}'";
    $with_options_orthotree = 1;
  }

  $ortho_params .= ", 'use_genomedb_id'=>1" if defined $genetree_params{use_genomedb_id};

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

  my $ortho_tree_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'OrthoTree',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::OrthoTree',
      -parameters      => $parameters
      );
  $analysisDBA->store($ortho_tree_analysis);
  $stats = $ortho_tree_analysis->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(5); # Some of the biggest clusters can fail and go through the other options
  my $ortho_tree_hive_capacity = $hive_params{'ortho_tree_hive_capacity'};
  $ortho_tree_hive_capacity = 200 unless defined $ortho_tree_hive_capacity;
  $stats->hive_capacity($ortho_tree_hive_capacity);

  $stats->update();

  #
  # QuickTreeBreak
  #
  print STDERR "QuickTreeBreak...\n";
  #
   $parameters = "{max_gene_count=>".$genetree_params{'max_gene_count'};
  if($genetree_params{sreformat}) {
  	$parameters .= qq|, sreformat_exe=>'$genetree_params{sreformat}'|;
  }
  $parameters .= '}';
  my $quick_tree_break_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'QuickTreeBreak',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::QuickTreeBreak',
      -parameters      => $parameters
      );
  $quick_tree_break_analysis->program_file($genetree_params{quicktree}) if $genetree_params{quicktree};
  $analysisDBA->store($quick_tree_break_analysis);
  $stats = $quick_tree_break_analysis->stats;
  $stats->batch_size(1);
  my $quicktreebreak_hive_capacity = 1; # Some deletes in OrthoTree can be hard on the mysql server
  $stats->hive_capacity($quicktreebreak_hive_capacity);
  $stats->update();

  #
  # GeneTreesetQC
  print STDERR "GeneTreesetQC...\n";
  #
  $parameters = $blast_template_analysis->parameters;
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  $parameters = $parameters . ",cluster_dir=>'" . $analysis_template{cluster_dir} . "'";
  $parameters = '{' . $parameters . ",groupset_tag=>'" . 'GeneTreesetQC' . "'}";
  my $gene_treeset_qc_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'GeneTreesetQC',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GroupsetQC',
      -parameters      => $parameters
    );

  $analysisDBA->store($gene_treeset_qc_analysis);
  $stats = $gene_treeset_qc_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(3);
  $stats->status('BLOCKED');
  $stats->update();


  # turn these two on if you need dnds from the old homology system
  #
  # CreateHomology_dNdSJob
  print STDERR "CreateHomology_dNdSJob...\n";
  #
  my $create_homology_dNdS_job_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateHomology_dNdSJob',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateHomology_dNdSJobs',
  );
  $analysisDBA->store($create_homology_dNdS_job_analysis);

  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($create_homology_dNdS_job_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
    $ctrlRuleDBA->create_rule($ortho_tree_analysis,$create_homology_dNdS_job_analysis);
    $ctrlRuleDBA->create_rule($njtree_phyml_analysis,$create_homology_dNdS_job_analysis);
    $ctrlRuleDBA->create_rule($mcoffee_analysis,$create_homology_dNdS_job_analysis);
#    $ctrlRuleDBA->create_rule($BreakPAFCluster,$create_homology_dNdS_job_analysis);
  }
  if (defined $dnds_params{'species_sets'}) {
    $self->{'hiveDBA'}->get_AnalysisJobAdaptor->CreateNewJob
        (
         -input_id       => ( '{species_sets=>'
                              . $dnds_params{'species_sets'}
#                               . ',method_link_types=>'
#                               . $dnds_params{'method_link_types'}
                              . '}' ),
         -analysis       => $create_homology_dNdS_job_analysis,
        );
  }

  #
  # Homology_dNdS
  print STDERR "Homology_dNdS...\n";
  #
  my $homology_dNdS_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'Homology_dNdS',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Homology_dNdS'
  );
  $self->store_codeml_parameters(\%dnds_params);
  if (defined $dnds_params{'dNdS_analysis_data_id'}) {
    $homology_dNdS_analysis->parameters('{dNdS_analysis_data_id=>' . $dnds_params{'dNdS_analysis_data_id'} . '}');
  }
  $analysisDBA->store($homology_dNdS_analysis);
  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($homology_dNdS_analysis->dbID);
    $stats->batch_size(1);
    my $homology_dnds_hive_capacity = $hive_params{homology_dnds_hive_capacity};
  	$homology_dnds_hive_capacity = 200 unless defined $homology_dnds_hive_capacity;
  	$stats->hive_capacity($homology_dnds_hive_capacity);
    $stats->failed_job_tolerance(2);
    $stats->status('BLOCKED');
    $stats->update();
    $ctrlRuleDBA->create_rule($create_homology_dNdS_job_analysis,$homology_dNdS_analysis);
  }

  #
  # OtherParalogs
  print STDERR "OtherParalogs...\n";
  #
  my $other_paralogs_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'OtherParalogs',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::OtherParalogs',
      # -parameters      => $parameters
      );
  $analysisDBA->store($other_paralogs_analysis);
  $stats = $other_paralogs_analysis->stats;
  $stats->batch_size(1);
  my $otherparalogs_hive_capacity = 50;
  $stats->hive_capacity($otherparalogs_hive_capacity);
  $stats->update();

  #
  # Threshold_on_dS
  print STDERR "Threshold_on_dS...\n";
  #
  my $threshold_on_dS_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'Threshold_on_dS',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Threshold_on_dS'
  );
  $analysisDBA->store($threshold_on_dS_analysis);

  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($threshold_on_dS_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('BLOCKED');
    $stats->update();
    $ctrlRuleDBA->create_rule($homology_dNdS_analysis,$threshold_on_dS_analysis);
  }
  if (defined $dnds_params{'species_sets'}) {
    $self->{'hiveDBA'}->get_AnalysisJobAdaptor->CreateNewJob
        (
         -input_id       => ( '{species_sets=>'
                              . $dnds_params{'species_sets'}
#                               . ',method_link_types=>'
#                               . $dnds_params{'method_link_types'}
                              . '}' ),
         -analysis       => $threshold_on_dS_analysis,
        );
  }

  #
  # BuildHMMaa
  print STDERR "BuildHMMaa...\n";
  #
  my $buildhmm_program = $genetree_params{'buildhmm'} || '/software/ensembl/compara/hmmer3/hmmer-3.0/src/hmmbuild';
  my $sreformat_program = $genetree_params{'sreformat'} || '/usr/local/ensembl/bin/sreformat';
  my $buildhmm_hive_capacity = $hive_params{buildhmm_hive_capacity} || 200;
  my $buildhmm_batch_size = $hive_params{buildhmm_batch_size} || 1;
  
  my $build_HMM_aa_analysis = Bio::EnsEMBL::Analysis->new
    (
     -db_version      => '1',
     -logic_name      => 'BuildHMMaa',
     -module          => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMM',
     -program_file    => $buildhmm_program,
     -parameters      => "{sreformat => '${sreformat_program}'}"
    );
  $analysisDBA->store($build_HMM_aa_analysis);
  $stats = $build_HMM_aa_analysis->stats;
  $stats->batch_size($buildhmm_batch_size);
  $stats->hive_capacity($buildhmm_hive_capacity);
  $stats->status('READY');
  $stats->update();

  #
  # BuildHMMcds
  print STDERR "BuildHMMcds...\n";
  #
  $parameters = '';
  $parameters = "{cdna=>1, sreformat => '${sreformat_program}'}";
  my $build_HMM_cds_analysis = Bio::EnsEMBL::Analysis->new
    (
     -db_version      => '1',
     -logic_name      => 'BuildHMMcds',
     -module          => 'Bio::EnsEMBL::Compara::RunnableDB::BuildHMM',
     -program_file    => $buildhmm_program,
     -parameters      => $parameters,
    );
  $analysisDBA->store($build_HMM_cds_analysis);
  $stats = $build_HMM_cds_analysis->stats;
  $stats->batch_size($buildhmm_batch_size);
  $stats->hive_capacity($buildhmm_hive_capacity);
  $stats->status('READY');
  $stats->update();

  #
  # Sitewise_dNdS
  print STDERR "Sitewise_dNdS...\n";
  #

  if (defined $sitewise_dnds_params{'saturated'}) {
    $parameters = '';
    my $with_options_sitewise_dnds = 0;
    if (defined $genetree_params{'honeycomb_dir'}) {
      $parameters = "'honeycomb_dir'=>'".$genetree_params{'honeycomb_dir'}."',";
      $with_options_sitewise_dnds = 1;
    }
    if (defined $sitewise_dnds_params{'saturated'}) {
      $parameters .= "'saturated'=>" . $sitewise_dnds_params{'saturated'};
      $with_options_sitewise_dnds = 1;
    }
    if (defined $sitewise_dnds_params{gblocks}) {
    	$parameters .= q{'gblocks_exe'=>} . $sitewise_dnds_params{'gblocks'};
    	$with_options_sitewise_dnds = 1;
    }
    $parameters = '{' . $parameters .'}' if (1==$with_options_sitewise_dnds);

    my $sitewise_dNdS_analysis = Bio::EnsEMBL::Analysis->new
      (
       -db_version      => '1',
       -logic_name      => 'Sitewise_dNdS',
       -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Sitewise_dNdS',
       -program_file    => $sitewise_dnds_params{'program_file'} || ''
      );

    #If params exceed 254 then use the analysis_data table.
    if(length($parameters) > 254) {
    	my $ad_dba =  $self->{'hiveDBA'}->get_AnalysisDataAdaptor();
    	my $adi = $ad_dba->store_if_needed($parameters);
    	$parameters = "{'analysis_data_id'=>${adi}}";
    }
    $sitewise_dNdS_analysis->parameters($parameters);

    $analysisDBA->store($sitewise_dNdS_analysis);

    if(defined($self->{'hiveDBA'})) {
      my $stats = $analysisStatsDBA->fetch_by_analysis_id($sitewise_dNdS_analysis->dbID);
      $stats->batch_size(1);
      $stats->hive_capacity(600);
      $stats->failed_job_tolerance(5); # Some of the biggest clusters can fail and go through the other options
      $stats->status('BLOCKED');
      $stats->update();
      $ctrlRuleDBA->create_rule($ortho_tree_analysis,$sitewise_dNdS_analysis);
    }

    # Only start sitewise dnds after the pairwise dnds and threshold on dS has finished
    $ctrlRuleDBA->create_rule($threshold_on_dS_analysis,$sitewise_dNdS_analysis);

    # When a Sitewise_dNdS job is saturated, we reincorporate the
    # subtrees in the analysis to rerun them again
    $dataflowRuleDBA->create_rule($ortho_tree_analysis, $sitewise_dNdS_analysis, 1);
    # Saturated jobs create new jobs of the same kind
    $dataflowRuleDBA->create_rule($sitewise_dNdS_analysis, $sitewise_dNdS_analysis, 2);
  }
  #$DB::single=1;1;
  #
  # CreateHDupsQCJobs
  print STDERR "CreateHDupsQCJobs...\n";
  #
  my $create_Hdups_qc_jobs_analysis = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'CreateHDupsQCJobs',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::CreateHDupsQCJobs'
  );
  $analysisDBA->store($create_Hdups_qc_jobs_analysis);

  if(defined($self->{'hiveDBA'})) {
    my $stats = $analysisStatsDBA->fetch_by_analysis_id($create_Hdups_qc_jobs_analysis->dbID);
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('READY');
    $stats->update();
  }

  #
  # HDupsQC
  #
  print STDERR "HDupsQC...\n";
  #
  my $hdups_qc_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'HDupsQC',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::HDupsQC',
      );
  $analysisDBA->store($hdups_qc_analysis);
  $stats = $hdups_qc_analysis->stats;
  $stats->batch_size(1);
  my $hdupsqc_hive_capacity = 10;
  $stats->hive_capacity($hdupsqc_hive_capacity);
  $stats->update();


  #
  # build graph of control and dataflow rules
  #

  # $ctrlRuleDBA->create_rule($updatepafids_analysis, $paf_cluster);
  $ctrlRuleDBA->create_rule($create_blast_rules_analysis, $create_hcluster_prepare_jobs_analysis);
  $ctrlRuleDBA->create_rule($create_blast_rules_analysis, $create_store_seq_exon_bounded_jobs_analysis);
  $ctrlRuleDBA->create_rule($create_blast_rules_analysis, $create_store_seq_cds_jobs_analysis);
  $ctrlRuleDBA->create_rule($create_store_seq_exon_bounded_jobs_analysis, $store_seq_exon_bounded_analysis);
  $ctrlRuleDBA->create_rule($create_store_seq_cds_jobs_analysis, $store_seq_cds_analysis);
  $ctrlRuleDBA->create_rule($create_Hdups_qc_jobs_analysis, $hdups_qc_analysis);
  $ctrlRuleDBA->create_rule($threshold_on_dS_analysis,$create_Hdups_qc_jobs_analysis);
  $ctrlRuleDBA->create_rule($create_hcluster_prepare_jobs_analysis, $hcluster_prepare_analysis);
  $ctrlRuleDBA->create_rule($hcluster_prepare_analysis, $hcluster_run_analysis);
  $ctrlRuleDBA->create_rule($hcluster_run_analysis, $clusterset_qc_analysis);
  $dataflowRuleDBA->create_rule($submit_genome_analysis, $clusterset_qc_analysis);
  $dataflowRuleDBA->create_rule($submit_genome_analysis, $gene_treeset_qc_analysis);
  $ctrlRuleDBA->create_rule($clusterset_qc_analysis,$mcoffee_analysis);

  $ctrlRuleDBA->create_rule($create_homology_dNdS_job_analysis,$gene_treeset_qc_analysis);
  $ctrlRuleDBA->create_rule($gene_treeset_qc_analysis,$homology_dNdS_analysis);

#   $dataflowRuleDBA->create_rule($hcluster_prepare_analysis, $hcluster_run_analysis, 1);
#   $dataflowRuleDBA->create_rule($paf_cluster, $clusterset_staging_analysis, 1);
#   $dataflowRuleDBA->create_rule($paf_cluster, $mcoffee_analysis, 2);
#   $dataflowRuleDBA->create_rule($paf_cluster, $BreakPAFCluster, 3);

  $dataflowRuleDBA->create_rule($hcluster_run_analysis, $clusterset_staging_analysis, 1);
  $dataflowRuleDBA->create_rule($hcluster_run_analysis, $mcoffee_analysis, 2);
#  $dataflowRuleDBA->create_rule($hcluster_run_analysis, $BreakPAFCluster, 3);

  $dataflowRuleDBA->create_rule($mcoffee_analysis, $njtree_phyml_analysis, 1);
#  $dataflowRuleDBA->create_rule($mcoffee_analysis, $BreakPAFCluster, 2);

  # Failing small seqnum jobs create new Jackknife jobs of the same kind
  $dataflowRuleDBA->create_rule($njtree_phyml_analysis, $njtree_phyml_analysis, 2);
  $dataflowRuleDBA->create_rule($njtree_phyml_analysis, $quick_tree_break_analysis, 3);
  $dataflowRuleDBA->create_rule($njtree_phyml_analysis, $other_paralogs_analysis, 3);

  $dataflowRuleDBA->create_rule($ortho_tree_analysis, $build_HMM_aa_analysis, 1);
  $dataflowRuleDBA->create_rule($ortho_tree_analysis, $build_HMM_cds_analysis, 1);
  $dataflowRuleDBA->create_rule($ortho_tree_analysis, $quick_tree_break_analysis, 2);
  $dataflowRuleDBA->create_rule($ortho_tree_analysis, $other_paralogs_analysis, 2);
  $dataflowRuleDBA->create_rule($quick_tree_break_analysis, $mcoffee_analysis, 1);

  # OtherParalogs are calculated for every QuickTreeBreak, but only
  # after all clusters are analysed, to avoid descriptions clashing
  # between OrthoTree and OtherParalogs.
  $ctrlRuleDBA->create_rule($ortho_tree_analysis,      $other_paralogs_analysis);
  $ctrlRuleDBA->create_rule($njtree_phyml_analysis,   $other_paralogs_analysis);
  $ctrlRuleDBA->create_rule($mcoffee_analysis,        $other_paralogs_analysis);
  $ctrlRuleDBA->create_rule($quick_tree_break_analysis, $other_paralogs_analysis);
  $ctrlRuleDBA->create_rule($build_HMM_cds_analysis,    $other_paralogs_analysis);
  $ctrlRuleDBA->create_rule($build_HMM_aa_analysis,     $other_paralogs_analysis);

  $dataflowRuleDBA->create_rule($njtree_phyml_analysis, $ortho_tree_analysis, 1);

#  $dataflowRuleDBA->create_rule($njtree_phyml_analysis, $BreakPAFCluster, 2);

#  $dataflowRuleDBA->create_rule($BreakPAFCluster, $mcoffee_analysis, 2);
#  $dataflowRuleDBA->create_rule($BreakPAFCluster, $BreakPAFCluster, 3);

  #
  # create initial job
  print STDERR "create initial job...\n";
  #

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
    (
     -input_id       => 1,
     -analysis       => $create_hcluster_prepare_jobs_analysis,
    );

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
    (
     -input_id       => 1,
     -analysis       => $create_store_seq_exon_bounded_jobs_analysis,
    );

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
    (
     -input_id       => 1,
     -analysis       => $create_store_seq_cds_jobs_analysis,
    );

   Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
       (
        -input_id       => 1,
 #       -analysis       => $paf_cluster,
        -analysis       => $hcluster_run_analysis,
       );

   if($analysis_template{'-parameters'} =~ /reuse_db/) {
     Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
         (
          -input_id       => 1,
   #       -analysis       => $paf_cluster,
          -analysis       => $clusterset_qc_analysis,
         );

     Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
         (
          -input_id       => 1,
   #       -analysis       => $paf_cluster,
          -analysis       => $gene_treeset_qc_analysis,
         );
   }
   else {
     print STDERR "No reuse database detected in BLASTP_TEMPLATE. Skipping global checks for ClustersetQC and GeneTreesetQC\n";
   }

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
      (
       -input_id       => 1,
       -analysis       => $create_Hdups_qc_jobs_analysis,
      );

  print STDERR "Done.\n";
  return 1;
}

sub store_codeml_parameters
{
  my $self = shift;
  my $dNdS_Conf = shift;

  my $options_hash_ref = $dNdS_Conf->{'codeml_parameters'};
  return unless($options_hash_ref);

  my @keys = keys %{$options_hash_ref};
  my $options_string = "{\n";
  foreach my $key (@keys) {
    $options_string .= "'$key'=>'" . $options_hash_ref->{$key} . "',\n";
  }
  $options_string .= "}";

  $dNdS_Conf->{'dNdS_analysis_data_id'} =
         $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($options_string);

  $dNdS_Conf->{'codeml_parameters'} = undef;
}


