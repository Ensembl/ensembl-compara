#!/usr/local/ensembl/bin/perl

=head1 NAME

add_Analysis, handles insertion of analysis objects into the database

=head1 SYNOPSIS

add_Analysis -dbhost -dbport -dbuser -dbpass -dbname -logic_name -module -type

=head1 DESCRIPTION

this script will insert analysis objects into a ensembl core database
with the pipeline tables added on

for the script to work the db files are required as are -logic_name
-module and -type

=head1 OPTIONS

    -dbhost    host name for database (gets put as host= in locator)

    -dbport    For RDBs, what port to connect to (port= in locator)

    -dbname    For RDBs, what name to connect to (dbname= in locator)

    -dbuser    For RDBs, what username to connect as (dbuser= in locator)

    -dbpass    For RDBs, what password to use (dbpass= in locator)

    -help      Displays script documentation with PERLDOC
  
    -logic_name the logic name of the analysis
    
    -database the name of the analysis database

    -database_version the version of the analysis database
   
    -database_file the full path to the database
 
    -program the name of the program being used
 
    -program_version the version of the program

    -module the name of the module, the module should either live in
     Bio::EnsEMBL::Pipeline::RunnableDB or you should provide the full 
     path to the module

    -module_version the version of the module

    -gff_source the source of the data ie RepeatMasker

    -gff_feature the type of feature ie Repeat

    -input_type the type of input_id this analysis will take, this should
     be all in uppercase ie CONTIG or SLICE

    
=cut

use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::DBSQL::AnalysisAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Rule;

use strict;
use Getopt::Long;

my $conf_file;
my $dbconf_file;
my %db_conf = {};
$db_conf{'-user'} = 'ensadmin';
$db_conf{'-pass'} = 'ensembl';
$db_conf{'-port'} = 3306;

my $dbhost;
my $dbport;
my $dbuser;
my $dbpass;
my $dbname;

my $template_file;
my $logic_name;
my $database;
my $database_version;
my $database_file;
my $program;
my $program_file;
my $program_version;
my $parameters;
my $module;
my $module_version;
my $gff_source;
my $gff_feature;
my $input_type;
my $help;

my %analysis_template = {};
my @speciesList = ();

&GetOptions(
            'conf:s'    => \$conf_file,
            'dbconf:s'  => \$dbconf_file,
            'dbhost:s'  => \$dbhost,
            'dbport:n'  => \$dbport,
            'dbuser:s'  => \$dbuser,
            'dbpass:s'  => \$dbpass,
            'dbname:s'  => \$dbname,
            'template:s' => \$template_file,
            'logic_name:s' => \$logic_name,
            'database:s'   => \$database,
            'database_version:s' => \$database_version,
            'database_file:s'    => \$database_file,
            'program:s'          => \$program,
            'program_version:s'  => \$program_version,
            'program_file:s'     => \$program_file,
            'parameters:s'       => \$parameters,
            'module:s'           => \$module,
            'module_version:s'   => \$module_version,
            'gff_sources:s'      => \$gff_source,
            'gff_feature:s'      => \$gff_feature,
            'input_type:s'       => \$input_type,
            'h|help'            => \$help,
           );

if ($help) { exec('perldoc', $0); }

parse_conf($conf_file);

my $db  = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(%db_conf);

my @spList2;
foreach my $speciesPtr (@speciesList) {
  my $condition = $db->get_AnalysisAdaptor->fetch_by_logic_name($speciesPtr->{condition_logic_name});
  $speciesPtr->{condition} = $condition;
  if($condition) { push @spList2, $speciesPtr; }
  else { warn("analysis condition '".$speciesPtr->{condition_logic_name}."' not in database\n"); }
}
@speciesList = @spList2;

foreach my $species1Ptr (@speciesList) {

  my $logic_name = "blast_" . $species1Ptr->{abrev};
  print("build analysis $logic_name\n");
  my %analParams = %analysis_template;
  $analParams{'-logic_name'}    = $logic_name;
  $analParams{'-input_id_type'} = $species1Ptr->{condition}->input_id_type();
  $analParams{'-db'}            = $species2Ptr->{abrev};
  $analParams{'-db_file'}       = $species2Ptr->{condition}->db_file();
  my $analysis = new Bio::EnsEMBL::Pipeline::Analysis(%analParams);
  $db->get_AnalysisAdaptor->store($analysis);

  foreach my $species2Ptr (@speciesList) {
    if($species1Ptr != $species2Ptr) {
=head3
      my $logic_name = "blast_" . $species1Ptr->{abrev} . $species2Ptr->{abrev};
      print("build analysis $logic_name\n");
      my %analParams = %analysis_template;
      $analParams{'-logic_name'}    = $logic_name;
      $analParams{'-input_id_type'} = $species1Ptr->{condition}->input_id_type();
      $analParams{'-db'}            = $species2Ptr->{abrev};
      $analParams{'-db_file'}       = $species2Ptr->{condition}->db_file();
      my $analysis = new Bio::EnsEMBL::Pipeline::Analysis(%analParams);
      $db->get_AnalysisAdaptor->store($analysis);
=cut
      my $rule = Bio::EnsEMBL::Pipeline::Rule->new('-goalAnalysis'=>$analysis);
      $rule->add_condition($species1Ptr->{condition}->logic_name());
      $db->get_RuleAdaptor->store($rule);
    }
  }
}

exit(1);



##################
#
# subroutines
#
#################

sub parse_conf {
  my($conf_file) = shift;

  if(-e $conf_file) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'DBCONNECT') {
        %db_conf = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'BLAST_TEMPLATE') {
        %analysis_template = %{$confPtr};
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @speciesList, $confPtr;
      }
    }
  }
}
