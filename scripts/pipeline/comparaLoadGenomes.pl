#!/usr/local/ensembl/bin/perl -w

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Hive;


my $conf_file;
my %analysis_template;
my @speciesList = ();
my @uniprotList = ();
my %hive_params ;

my %compara_conf = ();
#$compara_conf{'-user'} = 'ensadmin';
$compara_conf{'-port'} = 3306;

my ($help, $host, $user, $pass, $dbname, $port, $compara_conf, $adaptor, $ensembl_genomes);
my ($subset_id, $genome_db_id, $prefix, $fastadir, $verbose);

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

if(%analysis_template and (not(-d $analysis_template{'fasta_dir'}))) {
  die("\nERROR!!\n  ". $analysis_template{'fasta_dir'} . " fasta_dir doesn't exist, can't configure\n");
}

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'comparaDBA'}   = new Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor(%compara_conf);
$self->{'hiveDBA'}      = new Bio::EnsEMBL::Hive::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

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


foreach my $speciesPtr (@speciesList) {
  $self->submitGenome($speciesPtr);
}

foreach my $srsPtr (@uniprotList) {
  $self->submitUniprot($srsPtr);
}

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaLoadGenomes.pl [options]\n";
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
  my($conf_file) = shift;

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
      elsif($type eq 'BLAST_TEMPLATE') {
        %analysis_template = %{$confPtr};
      }
      elsif($type eq 'SPECIES') {
        push @speciesList, $confPtr;
      }
      elsif($type eq 'HIVE') {
        %hive_params = %{$confPtr};
      }
      elsif($type eq 'UNIPROT') {
        push @uniprotList, $confPtr;
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
      $genome_name = (defined $meta->get_Species) ? $meta->get_Species->binomial : $species->{species};
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
        -input_job_id   => 0
        );
}


sub submitUniprot
{
  my $self         = shift;
  my $uniprotHash  = shift;  #hash reference

  my $analysisDBA = $self->{'hiveDBA'}->get_AnalysisAdaptor;
  my $loadUniProt = $analysisDBA->fetch_by_logic_name('LoadUniProt');

  unless($loadUniProt) {
    $loadUniProt = Bio::EnsEMBL::Analysis->new(
        -db_version      => '1',
        -logic_name      => 'LoadUniProt',
        -module          => 'Bio::EnsEMBL::Compara::RunnableDB::LoadUniProt',
      );
    $analysisDBA->store($loadUniProt);
    my $stats = $loadUniProt->stats;
    $stats->batch_size(1);
    $stats->hive_capacity(-1);
    $stats->status('LOADING');
    $stats->update();
  }

  delete $uniprotHash->{'TYPE'};
  my $input_id = encode_hash($uniprotHash);

  Bio::EnsEMBL::Hive::DBSQL::AnalysisJobAdaptor->CreateNewJob (
        -input_id       => $input_id,
        -analysis       => $loadUniProt,
        -input_job_id   => 0
        );

}
