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
my %hive_params;
my %ehmm_params;

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
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

if(%hive_params) {
  if(defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
}

$self->loadClustersets();
$self->build_EHMMSystem();

exit(0);

#######################
#
# subroutines
#
#######################

sub usage {
  print "loadEHMMSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates\n";
  print "loadEHMMSystem.pl v0.1\n";

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
      if($confPtr->{TYPE} eq 'EHMM') {
        %ehmm_params = %{$confPtr};
      }
    }
  }
}
#
# need to make sure analysis 'SubmitGenome' is in database
# this is a generic analysis of type 'genome_db_id'
# the input_id for this analysis will be a genome_db_id
# the full information to access the genome will be in the compara database

sub loadClustersets
{
  my $self     = shift;

  print("SubmitGenome for ".$species->{abrev}."\n") if($verbose);

  #
  # connect to external genome database
  #
  my $genomeDBA = undef;
  my $locator = $species->{dblocator};

  unless($locator) {
    print("  dblocator not specified, building one\n")  if($verbose);
    $locator = $species->{module}."/host=".$species->{host};
    $species->{port}   && ($locator .= ";port=".$species->{port});
    $species->{user}   && ($locator .= ";user=".$species->{user});
    $species->{pass}   && ($locator .= ";pass=".$species->{pass});
    $species->{dbname} && ($locator .= ";dbname=".$species->{dbname});
    $species->{species} && ($locator .= ";species=".$species->{species});
    $species->{species_id} && ($locator .=";species_id=".$species->{species_id});
  }
  $locator .= ";disconnect_when_inactive=1";
  print("    locator = $locator\n")  if($verbose);

  eval {
    $genomeDBA = Bio::EnsEMBL::DBLoader->new($locator);
  };

  unless($genomeDBA) {
    print("ERROR: unable to connect to genome database $locator\n\n");
    return;
  }

  my $meta = $genomeDBA->get_MetaContainer;
  my $taxon_id = $meta->get_taxonomy_id;

#   # If we are in E_G then we need to look for a taxon in meta by 'NAME.species.taxonomy_id'
#   if($ensembl_genomes) {
#     if(!defined $taxon_id or $taxon_id == 1) {
#       # We make the same call as in the MetaContainer code, but with the NAME appendage
#       my $key = $species->{eg_name}.'.'.'species.taxonomy_id';
#       my $arrRef = $meta->list_value_by_key($key);
#       if( @$arrRef ) {
#         $taxon_id = $arrRef->[0];
#         print "Found taxonid ${taxon_id}\n" if $verbose;
#       }
#       else {
#         warning("Please insert meta_key '${key}' in meta table at core db.\n");
#       }
#     }
#   }

  my $ncbi_taxon = $self->{'comparaDBA'}->get_NCBITaxonAdaptor->fetch_node_by_taxon_id($taxon_id);
  my $genome_name = $self->_get_name($species, $meta, $ncbi_taxon);

  my ($cs) = @{$genomeDBA->get_CoordSystemAdaptor->fetch_all()};
  my $assembly = $cs->version;
  my $genebuild = ($meta->get_genebuild or "");

  if($species->{taxon_id} && ($taxon_id ne $species->{taxon_id})) {
    throw("$genome_name taxon_id=$taxon_id not as expected ". $species->{taxon_id});
  }

  my $genome = Bio::EnsEMBL::Compara::GenomeDB->new();
  $genome->taxon_id($taxon_id);
  $genome->name($genome_name);
  $genome->assembly($assembly);
  $genome->genebuild($genebuild);
  $genome->locator($locator);
  $genome->dbID($species->{'genome_db_id'}) if(defined($species->{'genome_db_id'}));

 if($verbose) {
    print("  about to store genomeDB\n");
    print("    taxon_id = '".$genome->taxon_id."'\n");
    print("    name = '".$genome->name."'\n");
    print("    assembly = '".$genome->assembly."'\n");
		print("    genebuild = '".$genome->genebuild."'\n");
    print("    genome_db id=".$genome->dbID."\n");
  }

  $self->{'comparaDBA'}->get_GenomeDBAdaptor->store($genome);
  $species->{'genome_db'} = $genome;
  print "  ", $genome->name, " STORED as genome_db id = ", $genome->dbID, "\n";

  #
  # now fill table genome_db_extra
  #
  eval {
    my ($sth, $sql);
    $sth = $self->{'comparaDBA'}->dbc->prepare("SELECT genome_db_id FROM genome_db_extn
        WHERE genome_db_id = ".$genome->dbID);
    $sth->execute;
    my $dbID = $sth->fetchrow_array();
    $sth->finish();

    if($dbID) {
      $sql = "UPDATE genome_db_extn SET " .
                "phylum='" . $species->{phylum}."'".
                ",locator='".$locator."'".
                " WHERE genome_db_id=". $genome->dbID;
    }
    else {
      $sql = "INSERT INTO genome_db_extn SET " .
                " genome_db_id=". $genome->dbID.
                ",phylum='" . $species->{phylum}."'".
                ",locator='".$locator."'";
    }
    print("$sql\n") if($verbose);
    $sth = $self->{'comparaDBA'}->dbc->prepare( $sql );
    $sth->execute();
    $sth->finish();
    print("done SQL\n") if($verbose);
  };

  #
  # now configure the input_id_analysis table with the genome_db_id
  #
  my $analysisDBA = $self->{'hiveDBA'}->get_AnalysisAdaptor;
  my $submitGenome = $analysisDBA->fetch_by_logic_name('SubmitGenome');

  unless($submitGenome) {
    $submitGenome = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'SubmitGenome',
        -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
      );
    $analysisDBA->store($submitGenome);
    my $stats = $submitGenome->stats;
    $stats->batch_size(100);
    $stats->hive_capacity(-1);
    $stats->update();
  }

  my $genomeHash = {};
  $genomeHash->{'gdb'} = $genome->dbID;
  if(defined($species->{'pseudo_stableID_prefix'})) {
    $genomeHash->{'pseudo_stableID_prefix'} = $species->{'pseudo_stableID_prefix'};
  }
  my $input_id = encode_hash($genomeHash);

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $submitGenome,
  );
}


sub build_EHMMSystem
{
  my $self = shift;

  my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
  my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;
  my $analysisStatsDBA = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;
  my $analysisDBA = $self->{'hiveDBA'}->get_AnalysisAdaptor;
  my $stats;
  my $parameters = undef;

  #
  # SubmitClusterset
  print STDERR "SubmitClusterset\n";
  #
  my $submitclusterset = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'SubmitClusterset',
      -input_id_type   => 'genome_db_id',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy'
    );

  $analysisDBA->store($submit_analysis); # although it's stored in comparaLoadGenomes.pl
  $stats = $analysisStatsDBA->fetch_by_analysis_id($submit_analysis->dbID);
  $stats->batch_size(100);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # GenomePrepareNCMembers
  print STDERR "GenomePrepareNCMembers\n";
  #
  my $load_genome = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GenomePrepareNCMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GenomePrepareNCMembers',
      -parameters      => "{type => 'ncRNA'}"
    );
  $analysisDBA->store($load_genome);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($load_genome->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(100);
  $stats->update();

  $dataflowRuleDBA->create_rule($submit_analysis, $load_genome);

  #
  # GeneStoreNCMembers
  print STDERR "GeneStoreNCMembers\n";
  #
  my $genestore = Bio::EnsEMBL::Analysis->new(
      -db_version      => '1',
      -logic_name      => 'GeneStoreNCMembers',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::GeneStoreNCMembers',
      -parameters      => "{type => 'ncRNA'}"
    );
  $analysisDBA->store($genestore);
  $stats = $analysisStatsDBA->fetch_by_analysis_id($genestore->dbID);
  $stats->batch_size(1);
  $stats->hive_capacity(400);
  $stats->update();

  $dataflowRuleDBA->create_rule($load_genome,$genestore);

  #
  # RFAMLoadModels
  print STDERR "RFAMLoadModels\n";
  #
  my $rfam_loadmodels = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'RFAMLoadModels',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RFAMLoadModels'
    );
  $analysisDBA->store($rfam_loadmodels);
  $stats = $rfam_loadmodels->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # RFAMClassify
  print STDERR "RFAMClassify\n";
  #
  $parameters = "{";
  $parameters .= $ehmm_params{'cluster_params'};
  $parameters .= "}";
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;
  my $rfam_classify = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'RFAMClassify',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RFAMClassify',
      -parameters      => $parameters
    );
  $analysisDBA->store($rfam_classify);
  $stats = $rfam_classify->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(-1);
  $stats->status('BLOCKED');
  $stats->update();

  #
  # RFAMSearch
  print STDERR "RFAMSearch\n";
  #
  my $cmsearch_exe = $ehmm_params{'cmsearch'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmsearch';
  my $rfamsearch = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'RFAMSearch',
      -program_file    => $cmsearch_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::RFAMSearch',
    );
  $analysisDBA->store($rfamsearch);
  $stats = $rfamsearch->stats;
  $stats->batch_size(5);
  $stats->failed_job_tolerance(10);
  $stats->hive_capacity(500);
  $stats->update();


  #
  # Clusterset_staging
  print STDERR "Clusterset_staging\n";
  #
  my $clusterset_staging = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Clusterset_staging',
      -module          => 'Bio::EnsEMBL::Hive::RunnableDB::Dummy',
    );
  $analysisDBA->store($clusterset_staging);
  $stats = $clusterset_staging->stats;
  $stats->batch_size(-1);
  $stats->hive_capacity(1);
  $stats->update();

  #
  # NCRecoverEPO
  print STDERR "NCRecoverEPO\n";
  #
  $parameters = "{";
  $parameters .= $ehmm_params{'recover_params'};
  $parameters .= "}";
  $parameters =~ s/\A{//;
  $parameters =~ s/}\Z//;

  my $ncrecoverepo = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCRecoverEPO',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCRecoverEPO',
      -parameters      => $parameters
    );
  $analysisDBA->store($ncrecoverepo);
  $stats = $ncrecoverepo->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # NCRecoverSearch
  print STDERR "NCRecoverSearch\n";
  #
  $cmsearch_exe = $ehmm_params{'cmsearch'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmsearch';
  my $ncrecoversearch = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCRecoverSearch',
      -program_file    => $cmsearch_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCRecoverSearch',
    );
  $analysisDBA->store($ncrecoversearch);
  $stats = $ncrecoversearch->stats;
  $stats->batch_size(5);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(500);
  $stats->update();

  #
  # Infernal
  print STDERR "Infernal\n";
  #
  my $cmbuild_exe = $ehmm_params{'cmbuild'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmbuild';
  $parameters = "{'cmbuild_exe'=>'$cmbuild_exe'";
  if (defined $ehmm_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$ehmm_params{'max_gene_count'};
  }
  if (defined $ehmm_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$ehmm_params{'honeycomb_dir'}."'";
  }
  $parameters .= "}";

  my $infernal_exe = $ehmm_params{'infernal'} || '/software/ensembl/compara/infernal/infernal-1.0.2/src/cmalign';

  my $infernal = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Infernal',
      -program_file    => $infernal_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Infernal',
      -parameters      => $parameters
    );
  $analysisDBA->store($infernal);
  $stats = $infernal->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # NCSecStructTree
  print STDERR "NCSecStructTree\n";
  #
  $parameters = "{'method'=>'ncsecstructtree1'";
  if (defined $ehmm_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$ehmm_params{'max_gene_count'};
  }
  if (defined $ehmm_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$ehmm_params{'honeycomb_dir'}."'";
  }
  $parameters .= "}";

  my $ncsecstructtree_exe = $ehmm_params{'ncsecstructtree'} || '/software/ensembl/compara/raxml/RAxML-7.2.2/raxmlHPC-SSE3';

  my $ncsecstructtree = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCSecStructTree',
      -program_file    => $ncsecstructtree_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCSecStructTree',
      -parameters      => $parameters
    );
  $analysisDBA->store($ncsecstructtree);
  $stats = $ncsecstructtree->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();


  #
  # NCGenomicAlignment
  print STDERR "NCGenomicAlignment\n";
  #
  my $treebest_exe = $ehmm_params{'treebest'} || '/nfs/acari/avilella/src/treesoft/trunk/treebest_ncrna/treebest';
  $parameters = "{'treebest_exe'=>'$treebest_exe'";
  if (defined $ehmm_params{'max_gene_count'}) {
    $parameters .= ",'max_gene_count'=>".$ehmm_params{'max_gene_count'};
  }
  if (defined $ehmm_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$ehmm_params{'honeycomb_dir'}."'";
  }
  $parameters .= "}";

  my $ncgenomicalignment_exe = $ehmm_params{'ncgenomicalignment'} || '/software/ensembl/compara/prank/091007/src/prank';

  my $ncgenomicalignment = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCGenomicAlignment',
      -program_file    => $ncgenomicalignment_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCGenomicAlignment',
      -parameters      => $parameters
    );
  $analysisDBA->store($ncgenomicalignment);
  $stats = $ncgenomicalignment->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(20);
  $stats->hive_capacity(-1);
  $stats->update();

  #
  # NCTreeBestMMerge
  print STDERR "NCTreeBestMMerge\n";
  #
  $parameters = "{rna=>1,bootstrap=>1";
  if (defined $ehmm_params{'max_gene_count'}) {
    $parameters .= ",max_gene_count=>".$ehmm_params{'max_gene_count'};
  }
  if ($ehmm_params{'species_tree_file'}){
    $parameters .= ",'species_tree_file'=>'". $ehmm_params{'species_tree_file'}."'";
  } else {
    warn("No species_tree_file => 'myfile' has been set in your config file. "
         ."This parameter can not be set for njtree. EXIT 3\n");
    exit(3);
  }
  if (defined $ehmm_params{'honeycomb_dir'}) {
    $parameters .= ",'honeycomb_dir'=>'".$ehmm_params{'honeycomb_dir'}."'";
  }

  $parameters .= ", 'use_genomedb_id'=>1" if defined $ehmm_params{use_genomedb_id};

  $parameters .= "}";
  my $treebest_mmerge_analysis_data_id = $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($parameters);
  if (defined $treebest_mmerge_analysis_data_id) {
    $parameters = "{'treebest_mmerge_data_id'=>'$treebest_mmerge_analysis_data_id'}";
  }
  my $tree_best_program = $ehmm_params{'treebest'} || '/nfs/acari/avilella/src/treesoft/trunk/treebest_ncrna/treebest';
  my $treebest_mmerge = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCTreeBestMMerge',
      -program_file    => $tree_best_program,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCTreeBestMMerge',
      -parameters      => $parameters
    );
  $analysisDBA->store($treebest_mmerge);
  $stats = $treebest_mmerge->stats;
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
  if (defined $ehmm_params{'honeycomb_dir'}) {
    $ortho_params = "'honeycomb_dir'=>'".$ehmm_params{'honeycomb_dir'}."'";
    $with_options_orthotree = 1;
  }
  if(defined $ehmm_params{'species_tree_file'}) {
    my $tree_file = $ehmm_params{'species_tree_file'};
    $ortho_params .= ",'species_tree_file'=>'${tree_file}'";
    $with_options_orthotree = 1;
  }

  $ortho_params .= ", 'use_genomedb_id'=>1" if defined $ehmm_params{use_genomedb_id};

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

  my $ncorthotree = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCOrthoTree',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCOrthoTree',
      -parameters      => $parameters
      );
  $analysisDBA->store($ncorthotree);
  $stats = $ncorthotree->stats;
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
  my $ktreedist_exe = $ehmm_params{'ktreedist_exe'} || '/software/ensembl/compara/ktreedist/Ktreedist.pl';

  my $ktreedist = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'Ktreedist',
      -program_file    => $ktreedist_exe,
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::Ktreedist',
    );
  $analysisDBA->store($ktreedist);
  $stats = $ktreedist->stats;
  $stats->batch_size(1);
  $stats->failed_job_tolerance(80);
  $stats->hive_capacity(-1);
  $stats->update();



  $parameters = "{max_gene_count=>".$ehmm_params{'max_gene_count'}."}";
  my $ncquicktreebreak = Bio::EnsEMBL::Analysis->new(
      -logic_name      => 'NCQuickTreeBreak',
      -module          => 'Bio::EnsEMBL::Compara::RunnableDB::NCQuickTreeBreak',
      -parameters      => $parameters
      );
  $analysisDBA->store($ncquicktreebreak);
  $stats = $ncquicktreebreak->stats;
  $stats->batch_size(1);
  my $quicktreebreak_hive_capacity = 10;
  $stats->hive_capacity($quicktreebreak_hive_capacity);

  $stats->update();

  #
  # build graph of control and dataflow rules
  #

  $ctrlRuleDBA->create_rule($genestore, $rfam_classify);
  $ctrlRuleDBA->create_rule($genestore, $rfam_loadmodels);
  $ctrlRuleDBA->create_rule($rfam_loadmodels, $rfam_classify);
  $ctrlRuleDBA->create_rule($rfam_classify, $clusterset_staging);
  $ctrlRuleDBA->create_rule($rfamsearch, $clusterset_staging);
  $ctrlRuleDBA->create_rule($ncrecoverepo, $clusterset_staging);
  $ctrlRuleDBA->create_rule($ncrecoversearch, $clusterset_staging);
  # $dataflowRuleDBA->create_rule($rfam_classify, $clusterset_staging, 1); # This may be redundant here
  $dataflowRuleDBA->create_rule($rfam_classify, $ncrecoverepo, 2);
  $dataflowRuleDBA->create_rule($rfam_classify, $rfamsearch, 3);
  $dataflowRuleDBA->create_rule($rfamsearch, $infernal, 1);
  $dataflowRuleDBA->create_rule($ncrecoverepo, $ncrecoversearch, 1);
  $dataflowRuleDBA->create_rule($ncrecoversearch, $infernal, 1);
  $dataflowRuleDBA->create_rule($clusterset_staging, $infernal, 1);
  $dataflowRuleDBA->create_rule($infernal, $ncsecstructtree, 1);
  $dataflowRuleDBA->create_rule($ncsecstructtree, $ncgenomicalignment, 1);
  $dataflowRuleDBA->create_rule($ncgenomicalignment, $treebest_mmerge, 1);

  $dataflowRuleDBA->create_rule($treebest_mmerge, $ncquicktreebreak, 3);
  $dataflowRuleDBA->create_rule($ncorthotree, $ncquicktreebreak, 2);
  $dataflowRuleDBA->create_rule($treebest_mmerge, $ncorthotree, 1);
  $dataflowRuleDBA->create_rule($treebest_mmerge, $ktreedist, 1);

  #
  print STDERR "Create initial jobs\n";
  # create initial jobs
  #

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
       (
        -input_id       => 1,
        -analysis       => $rfam_classify,
       );
  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob
       (
        -input_id       => 1,
        -analysis       => $rfam_loadmodels,
       );

  print STDERR "Finished\n";

  return 1;
}


