#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Hive;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

my $conf_file;
my %analysis_template;
my @speciesList = ();
my @uniprotList = ();
my %hive_params ;
my %conservation_score_params;

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my $import_alignment_params;
my $alignment_params;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor, $ensembl_genomes);
my ($subset_id, $genome_db_id, $prefix, $fastadir, $verbose);

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

GetOptions('help'            => \$help,
           'conf=s'          => \$conf_file,
           'dbhost=s'        => \$host,
           'dbport=i'        => \$port,
           'dbuser=s'        => \$user,
           'dbpass=s'        => \$pass,
           'dbname=s'        => \$dbname,
           'ensembl_genomes' => \$ensembl_genomes,
           'v' => \$verbose,
          );

if ($help) { usage(); }

Bio::EnsEMBL::Registry->no_version_check(1);

$self->parse_conf($conf_file);

if($host)   { $compara_conf{'-host'}   = $host; }
if($port)   { $compara_conf{'-port'}   = $port; }
if($dbname) { $compara_conf{'-dbname'} = $dbname; }
if($user)   { $compara_conf{'-user'}   = $user; }
if($pass)   { $compara_conf{'-pass'}   = $pass; }


unless(defined($compara_conf{'-host'}) and defined($compara_conf{'-user'}) and defined($compara_conf{'-dbname'})) {
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage();
}

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);
$self->{'analysisStatsDBA'} = $self->{'hiveDBA'}->get_AnalysisStatsAdaptor;

if (%hive_params) {
  if (defined($hive_params{'hive_output_dir'})) {
    die("\nERROR!! hive_output_dir doesn't exist, can't configure\n  ", $hive_params{'hive_output_dir'} , "\n")
      if(($hive_params{'hive_output_dir'} ne "") and !(-d $hive_params{'hive_output_dir'}));
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('hive_output_dir');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('hive_output_dir', $hive_params{'hive_output_dir'});
  }
  if (defined($hive_params{'name'})) {
    $self->{'comparaDBA'}->get_MetaContainer->delete_key('name');
    $self->{'comparaDBA'}->get_MetaContainer->store_key_value('name', $hive_params{'name'});
  }
}

#load analysis_data
$self->prepareLowCoverageAlignerSystem;
foreach my $speciesPtr (@speciesList) {
  $self->submitGenome($speciesPtr);
}

$self->setup_pipeline();

#$self->createImportAlignmentAnalysis;

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "loadLowCoverageAlignerSystem.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
	print "  -ensembl_genomes       : use ensembl genomes specific code\n";
  print "comparaLoadGenomes.pl v1.2\n";
  
  exit(1);
}


sub parse_conf {
    my $self = shift;
    my($conf_file) = shift;
    $self->{'set_internal_ids'} = 0;

    if($conf_file and (-e $conf_file)) {
	#read configuration file from disk
	my @conf_list = @{do $conf_file};
	
	foreach my $confPtr (@conf_list) {
	    my $type = $confPtr->{TYPE};
	    delete $confPtr->{TYPE};
	    print("HANDLE type $type\n") if($verbose);
	    if($type eq 'COMPARA') {
		%compara_conf = %{$confPtr};
	    }
	    elsif($type eq 'SPECIES') {
		push @speciesList, $confPtr;
	    }
	    elsif($type eq 'HIVE') {
		%hive_params = %{$confPtr};
	    }
	    elsif($type eq 'IMPORT_ALIGNMENT') {
		%$import_alignment_params = %{$confPtr};
	    }
	    elsif($type eq 'LOW_COVERAGE_GENOME_ALIGNMENT') {
		%$alignment_params = %{$confPtr};
	    }
	    elsif($type eq 'CONSERVATION_SCORE') {
		die "You cannot have more than one CONSERVATION_SCORE block in your configuration file"
		  if (%conservation_score_params);
		%conservation_score_params = %{$confPtr};
	    } 
	    elsif($type eq 'SET_INTERNAL_IDS') {
		$self->{'set_internal_ids'} = 1;
	    }
	}
    }
}


sub submitGenome
{
  my $self     = shift;
  my $species  = shift;  #hash reference

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
  my $genome_name;
  # check for ncbi table
  if (defined $ncbi_taxon) {
    $genome_name = $ncbi_taxon->binomial;
  }
  # Some NCBI taxons for complete genomes have no binomial, so one has
  # to go to the species level - A.G.
  if (!defined $genome_name ) {
    $verbose && print"  Cannot get binomial from NCBITaxon, try Meta...\n";
    # We assume that the species field is the binomial name
    if (defined($species->{species})) {
      $genome_name = $species->{species};
    } else {
      $genome_name = (defined $meta->get_Species) ? meta->get_Species->binomial : $species->{species};
    }
  }

  my ($cs) = @{$genomeDBA->get_CoordSystemAdaptor->fetch_all()};
  my $assembly = $cs->version;
  $assembly = '-undef-' if ($ensembl_genomes && !$cs->version);
  my $genebuild = ($meta->get_genebuild or "");

  #EDIT because the meta container always returns a value
  if ($ensembl_genomes && 1 == length($genebuild)) {
	$genebuild = '' if (1 == $genebuild);
  }

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
}

#
# Populate analysis_data
#
sub prepareLowCoverageAlignerSystem {
    my $self = shift;
    
    #
    #tree
    #
    my $tree_string;
    if (defined $alignment_params->{'tree_string'}) {
	$tree_string = $alignment_params->{'tree_string'};
    } elsif (defined $alignment_params->{'tree_file'}) {
	my $tree_file = $alignment_params->{'tree_file'};
        open TREE_FILE, $tree_file || throw("Can not open $tree_file");
        $tree_string = join("", <TREE_FILE>);
        close TREE_FILE;
    }
    if ($tree_string) {
        $self->{'tree_analysis_data_id'} =
	  $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($tree_string);
    }
    
    #
    #taxon_tree
    #
    my $taxon_tree_string;
    if (defined $alignment_params->{'taxon_tree_string'}) {
	$taxon_tree_string = $alignment_params->{'taxon_tree_string'};
    } elsif (defined $alignment_params->{'taxon_tree_file'}) {
	my $taxon_tree_file = $alignment_params->{'taxon_tree_file'};
        open TREE_FILE, $taxon_tree_file || throw("Can not open $taxon_tree_file");
        $taxon_tree_string = join("", <TREE_FILE>);
        close TREE_FILE;
    }
    if ($taxon_tree_string) {
        $self->{'taxon_tree_analysis_data_id'} =
	  $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($taxon_tree_string);
    }

    #
    #pairwise data
    #Either define all the url/mlss_id pairs in a string (pairwise_string)
    #or define all the url/mlss_id pairs in a file (pairwise_file)
    #or define a single url and a list of mlss_ids in that database
    #
    my $pairwise_string;
    if (defined $alignment_params->{'pairwise_string'}) {
	$pairwise_string = $alignment_params->{'pairwise_string'};
    } elsif (defined $alignment_params->{'pairwise_file'}) {
	my $pairwise_file = $alignment_params->{'pairwise_file'};
        open PAIRWISE_FILE, $pairwise_file || throw("Can not open $pairwise_file");
        $pairwise_string = join("", <PAIRWISE_FILE>);
        close PAIRWISE_FILE;
    } elsif (defined $alignment_params->{'pairwise_url'}) {
	throw("Need to define list of method_link_species_set_ids")
	  if (!defined $alignment_params->{'pairwise_mlss'});
	foreach my $mlss (split(",", $alignment_params->{'pairwise_mlss'})) {
	    $pairwise_string .=  " {compara_db_url=>'" .$alignment_params->{'pairwise_url'} . "',method_link_species_set_id=>$mlss} ";
	}
    }

    if ($pairwise_string) {
        $self->{'pairwise_analysis_data_id'} =
	  $self->{'hiveDBA'}->get_AnalysisDataAdaptor->store_if_needed($pairwise_string);
    }
}

sub setup_pipeline() {
    #yes this should be done with a config file and a loop, but...
    my $self = shift;
  
    my $dataflowRuleDBA = $self->{'hiveDBA'}->get_DataflowRuleAdaptor;
    my $ctrlRuleDBA = $self->{'hiveDBA'}->get_AnalysisCtrlRuleAdaptor;


    #ANALYSIS 1 - ImportAlignment
    my $importAlignmentAnalysis = $self->createImportAlignmentAnalysis;

    #ANALYSIS 2 - SetInternalIds (optional)
    my $setInternalIdsAnalysis;
    if ($self->{'set_internal_ids'}) {
	$setInternalIdsAnalysis = $self->createSetInternalIdsAnalysis;
	$ctrlRuleDBA->create_rule($importAlignmentAnalysis, $setInternalIdsAnalysis);
    } 

    #ANALYSIS 3 - CreateLowCoverageJobs 
    my $lowCoverageJobsAnalysis = $self->createLowCoverageJobsAnalysis;
    if ($self->{'set_internal_ids'}) {
	$ctrlRuleDBA->create_rule($setInternalIdsAnalysis,$lowCoverageJobsAnalysis);
    } else {
	$ctrlRuleDBA->create_rule($importAlignmentAnalysis,$lowCoverageJobsAnalysis);
    }
    #ANALYSIS 4 - LowCoverageGenomeAlignment
    my $lowCoverageAnalysis = $self->createLowCoverageAnalysis;
    $ctrlRuleDBA->create_rule($lowCoverageJobsAnalysis,$lowCoverageAnalysis);

    #ANALYSIS 5 - DeleteAlignment
    my $deleteAlignmentAnalysis = $self->createDeleteAlignmentAnalysis;
    $ctrlRuleDBA->create_rule($lowCoverageAnalysis,$deleteAlignmentAnalysis);

    #ANALYSIS 6 - UpdateMaxAlignmentLength
    my $updateMaxAlignmentLengthAnalysis = $self->createUpdateMaxAlignmentLengthAnalysis;

    $ctrlRuleDBA->create_rule($deleteAlignmentAnalysis, $updateMaxAlignmentLengthAnalysis);

    
    #ANALYSIS 7 - Conservation scores
    my $conservation_score_analysis = $self->create_conservation_score_analysis();
    $dataflowRuleDBA->create_rule($lowCoverageAnalysis, $conservation_score_analysis);
    $ctrlRuleDBA->create_rule($updateMaxAlignmentLengthAnalysis, $conservation_score_analysis);
    
    #add entry into meta table linking gerp to it's multiple aligner mlss_id
    if (defined($alignment_params->{gerp_mlss_id})) {
	my $key = "gerp_" . $alignment_params->{gerp_mlss_id};
	my $value = $alignment_params->{method_link_species_set_id};
	$self->{'comparaDBA'}->get_MetaContainer->store_key_value($key, $value);
    }

    #ANALYSIS 8 - CreateNeighbourNodesJobs
    my $createNeighbourNodesJobsAnalysis = $self->createNeighbourNodesJobsAnalysis;
    $ctrlRuleDBA->create_rule($conservation_score_analysis,$createNeighbourNodesJobsAnalysis);

    #ANALYSIS 9 - SetNeighbourNodes
    my $createSetNeighbourNodesAnalysis = $self->createSetNeighbourNodesAnalysis;
    $ctrlRuleDBA->create_rule($createNeighbourNodesJobsAnalysis, $createSetNeighbourNodesAnalysis);

}

sub createImportAlignmentAnalysis {
    my $self = shift;

    #
    # Creating ImportAlignment analysis
    #
    my $stats;
    my $importAlignmentAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'ImportAlignment',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::ImportAlignment',
#        -parameters      => ""
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($importAlignmentAnalysis);
     $stats = $importAlignmentAnalysis->stats;
     $stats->batch_size(1);
     $stats->hive_capacity(1); 
     $stats->update();
     $self->{'importAlignmentAnalysis'} = $importAlignmentAnalysis;
    

    my $input_id =  "from_db_url=>'" . $import_alignment_params->{'from_db_url'} . "',method_link_species_set_id=>" . $import_alignment_params->{'method_link_species_set_id'};
    
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $importAlignmentAnalysis
    );
    return $importAlignmentAnalysis;
 }

sub createLowCoverageJobsAnalysis {
    my $self = shift;

    #
    # Creating CreateLowCoverageGenomeAlignmentJobs
    #
    my $lc_stats;
    my $createLowCoverageJobsAnalysis = Bio::EnsEMBL::Analysis->new(
       -db_version      => '1',
       -logic_name      => 'CreateLowCoverageGenomeAlignmentJobs',
       -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateLowCoverageJobs',
#       -parameters      => ""
     );
    $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($createLowCoverageJobsAnalysis);
    $lc_stats = $createLowCoverageJobsAnalysis->stats;
    $lc_stats->batch_size(1);
    $lc_stats->hive_capacity(-1); #unlimited
    $lc_stats->update();
    $self->{'createLowCoverageJobsAnalysis'} = $createLowCoverageJobsAnalysis;
    
    my $input_id = "base_method_link_species_set_id=>" . $import_alignment_params->{'method_link_species_set_id'} . 
      ",new_method_link_species_set_id=>" . $alignment_params->{'method_link_species_set_id'} . 
      ",tree_analysis_data_id=>" . $self->{'tree_analysis_data_id'} . 
      ",taxon_tree_analysis_data_id=>" . $self->{'taxon_tree_analysis_data_id'} . 
       ",pairwise_analysis_data_id=>" . $self->{'pairwise_analysis_data_id'} . 
       ",reference_species=>'" . $alignment_params->{'reference_species'} . "'";

    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $createLowCoverageJobsAnalysis
          );

    return $createLowCoverageJobsAnalysis;
}

sub createLowCoverageAnalysis {

    #
    # Creating LowCoverageGenomeAlignment analysis
    #
    my ($logic_name, $module) = set_logic_name_and_module(
	     $alignment_params, "LowCoverageGenomeAlignment");

    my $parameters = "max_block_size=>" . $alignment_params->{'max_block_size'};
    my $stats2;
     my $lowCoverageAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => $logic_name,
        -module          => $module,
        -parameters      => "{$parameters}"
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($lowCoverageAnalysis);
     $stats2 = $lowCoverageAnalysis->stats;
     $stats2->batch_size(1);
     $stats2->hive_capacity(30);
     $stats2->update();
     $self->{'lowCoverageGenomeAlignmentAnalysis'} = $lowCoverageAnalysis;

    return $lowCoverageAnalysis;
}

sub createDeleteAlignmentAnalysis {
    my $self = shift;

    #
    # Creating DeleteAlignment analysis
    #
    my $stats;
    my $deleteAlignmentAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'DeleteAlignment',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::DeleteAlignment',
#        -parameters      => ""
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($deleteAlignmentAnalysis);
     $stats = $deleteAlignmentAnalysis->stats;
     $stats->batch_size(1);
     $stats->hive_capacity(1); 
     $stats->update();
     $self->{'deleteAlignmentAnalysis'} = $deleteAlignmentAnalysis;
    

    my $input_id =  "method_link_species_set_id=>" . $import_alignment_params->{'method_link_species_set_id'};
    
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $deleteAlignmentAnalysis
    );
    return $deleteAlignmentAnalysis;
 }

sub createSetInternalIdsAnalysis {
    my $self = shift;

    #
    # Creating SetInternalIds analysis
    #
    my $stats;
    my $setInternalIdsAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'SetInternalIds',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetInternalIds',
#        -parameters      => ""
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($setInternalIdsAnalysis);
     $stats = $setInternalIdsAnalysis->stats;
     $stats->batch_size(1);
     $stats->hive_capacity(1); 
     $stats->update();
     $self->{'setInternalIdsAnalysis'} = $setInternalIdsAnalysis;
    
    my $input_id =  "method_link_species_set_id=>" . $alignment_params->{'method_link_species_set_id'};
    
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $setInternalIdsAnalysis
    );
    return $setInternalIdsAnalysis;
 }

sub createUpdateMaxAlignmentLengthAnalysis {
    my $self = shift;

    #
    # Creating updateMaxAlignmentLength analysis
    #
    my $stats;
    my $updateMaxAlignmentLengthAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'UpdateMaxAlignmentLength',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::UpdateMaxAlignmentLength',
#        -parameters      => ""
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($updateMaxAlignmentLengthAnalysis);
     $stats = $updateMaxAlignmentLengthAnalysis->stats;
     $stats->batch_size(1);
     $stats->hive_capacity(1); 
     $stats->update();
     $self->{'updateMaxAlignmentLengthAnalysis'} = $updateMaxAlignmentLengthAnalysis;
    
    my $input_id = 1;
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -analysis       => $updateMaxAlignmentLengthAnalysis,
            -input_id       => $input_id,
    );
    return $updateMaxAlignmentLengthAnalysis;
 }

#####################################################################
##
## create_conservation_score_analysis
##
#####################################################################

sub create_conservation_score_analysis {
  my ($self) = @_;
  
  return undef if (!%conservation_score_params);
  
  my ($logic_name, $module) = set_logic_name_and_module(
      \%conservation_score_params, "Gerp");

  my ($method_link_id, $method_link_type);
  my ($method_link_id_cs, $method_link_type_cs) = qw(501 GERP_CONSERVATION_SCORE);
  my ($method_link_id_ce, $method_link_type_ce) = qw(11 GERP_CONSTRAINED_ELEMENT);
  if (defined $conservation_score_params{'method_links'}) {
      foreach my $method_link (@{$conservation_score_params{'method_links'}}) {
	  ($method_link_id, $method_link_type) = @$method_link;
	  
	  if ($method_link_type eq "GERP_CONSERVATION_SCORE") {
	      $method_link_id_cs = $method_link_id;
	      $method_link_type_cs = $method_link_type;
	  }
	  if ($method_link_type eq "GERP_CONSTRAINED_ELEMENT") {
	      $method_link_id_ce = $method_link_id;
	      $method_link_type_ce = $method_link_type;
	  }
      }
  }

  my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id_cs, type='$method_link_type_cs'";
  $self->{'hiveDBA'}->dbc->do($sql);
  
  $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id_ce, type='$method_link_type_ce'";
  $self->{'hiveDBA'}->dbc->do($sql);
  
  foreach my $method_link_type ($method_link_type_cs, $method_link_type_ce) {

      my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
      $mlss->method_link_type($method_link_type);
      
      my $gdbs = [];
      
      foreach my $species (@speciesList) {
	  my $name = $species->{species};
	  my $gdb = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_by_name_assembly($name);
	  push @{$gdbs}, $gdb;
      }
      $mlss->species_set($gdbs);
      
      #use method_link_species_set id from config file if defined
      if ($method_link_type eq "GERP_CONSERVATION_SCORE") {
	  if (defined($conservation_score_params{'method_link_species_set_id_cs'})) {
	      $mlss->dbID($conservation_score_params{'method_link_species_set_id_cs'});
	  }
      } else {
	  if (defined($conservation_score_params{'method_link_species_set_id_ce'})) {
	      $mlss->dbID($conservation_score_params{'method_link_species_set_id_ce'});
	  }
      }
      
      $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
      
      #add gerp conservation score mlss id for use in 
      #create_multiple_aligner_analysis to create entry into meta table
      if ($method_link_type eq "GERP_CONSERVATION_SCORE") {
	  $alignment_params->{gerp_mlss_id} = $mlss->dbID;
      }
  }
  
  my $parameters = "";
  if (defined $conservation_score_params{'param_file'}) {
      $parameters .= "param_file=>\'" . $conservation_score_params{'param_file'} ."\',";
  }
  if (defined $conservation_score_params{'window_sizes'}) {
      $parameters .= "window_sizes=>\'" . $conservation_score_params{'window_sizes'} ."\',";
  }
  if (defined $conservation_score_params{'tree_file'}) {
      $parameters .= "tree_file=>\'" . $conservation_score_params{'tree_file'} ."\',";
  }
  
  $parameters .= "constrained_element_method_link_type=>\'" . $method_link_type_ce ."\',";
  
  $parameters = "{$parameters}";
  
  #default program_version
  my $program_version = 2.1;
  if (defined $conservation_score_params{'program_version'}) {
      $program_version = $conservation_score_params{'program_version'};
  }
  
  #location of program_file
  my $program_file = "/software/ensembl/compara/gerp/GERPv2.1";
  if (defined $conservation_score_params{'program_file'}) {
      $program_file = $conservation_score_params{'program_file'};
  }
  
  my $conservation_score_analysis = Bio::EnsEMBL::Analysis->new(
      -logic_name      => $logic_name,
      -module          => $module,
      -parameters      => $parameters,
      -program_version => $program_version,
      -program_file    => $program_file
    );

  $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($conservation_score_analysis);
  my $stats = $conservation_score_analysis->stats;
  $stats->batch_size(1);
  $stats->hive_capacity(60);
  $stats->status('BLOCKED');
  $stats->update();


  return $conservation_score_analysis;
}

sub createNeighbourNodesJobsAnalysis {
    my $self = shift;

    #
    # Creating SetNeighbourNodesJobs analysis
    #
    my $stats;
    my $createNeighbourNodesJobsAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'CreateNeighbourNodesJobsAlignment',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::CreateNeighbourNodesJobs',
#        -parameters      => ""
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($createNeighbourNodesJobsAnalysis);
     $stats = $createNeighbourNodesJobsAnalysis->stats;
     $stats->batch_size(1);
     $stats->hive_capacity(1); 
     $stats->update();
     $self->{'createNeighbourNodesJobsAnalysis'} = $createNeighbourNodesJobsAnalysis;
    

    my $input_id =  "method_link_species_set_id=>" .  $alignment_params->{'method_link_species_set_id'};
    
    Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob(
            -input_id       => "{$input_id}",
            -analysis       => $createNeighbourNodesJobsAnalysis
    );
    return $createNeighbourNodesJobsAnalysis;
 }

sub createSetNeighbourNodesAnalysis {
    my $self = shift;

    #
    # Creating SetNeighbourNodes analysis
    #
    my $stats;
    my $createSetNeighbourNodesAnalysis = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'SetNeighbourNodes',
        -module          => 'Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::SetNeighbourNodes',
#        -parameters      => ""
      );

     $self->{'hiveDBA'}->get_AnalysisAdaptor()->store($createSetNeighbourNodesAnalysis);
     $stats = $createSetNeighbourNodesAnalysis->stats;
     $stats->batch_size(1);
     $stats->hive_capacity(15); 
     $stats->update();
     $self->{'createSetNeighbourNodesAnalysis'} = $createSetNeighbourNodesAnalysis;
    
    return $createSetNeighbourNodesAnalysis;
 }


#####################################################################
##
## set_logic_name_and_module
##
#####################################################################

sub set_logic_name_and_module {
  my ($params, $default) = @_;

  my $logic_name = $default; #Default value
  if (defined $params->{'logic_name'}) {
    $logic_name = $params->{'logic_name'};
  }
  my $module = "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::$logic_name";
  if (defined $params->{'module'}) {
    $module = $params->{'module'};
  }

  return ($logic_name, $module);
}
