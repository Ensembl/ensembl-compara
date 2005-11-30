#!/usr/local/ensembl/bin/perl -w
=head1
  this script does homology dumps generated with this SQL statement from two different
  compara databases and compares them for differences.  

=cut

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;
use Bio::EnsEMBL::Hive::URLFactory;
use Bio::EnsEMBL::Compara::Production::HomologySet;
use Time::HiRes qw { time };

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_ref_hash'}    = {};
$self->{'compara_ref_missing'} = {};
$self->{'compara_new_hash'} = {};
$self->{'conversion_hash'} = {};
$self->{'allTypes'} = {};

$self->{'refDups'} = 0;
$self->{'newDups'} = 0;

my $help;
my $sameBRH=0;
my $sameRHS=0;
my $BRH2BRH=0;  #changed BRH sub type (eg BRH to BRH_MULTI)
my $BRH2RHS=0;
my $RHS2BRH=0;
my $countAdds=0;
my $ref_homology_count=0;
my $new_homology_count=0;
my $BRHCount=0;
my $RHSCount=0;
my $newBRH=0;
my $newRHS=0;
my $url  = undef;
my $url2 = undef;

GetOptions('help'     => \$help,
           'url=s'    => \$url,
           'url2=s'   => \$url2,
           'gdb1=i'   => \$self->{'genome_db_id_1'},
           'gdb2=i'   => \$self->{'genome_db_id_2'},
          );

if ($help) { usage(); }

unless($url) {
  print "\nERROR : must specify url for compara database\n\n";
  usage();
}

$self->{'comparaDBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara');

if(defined($url2)) {
  $self->{'compara2DBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($url2, 'compara');
}

test_homology_set($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "homology_diff.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url <str>             : url of reference compara DB\n";
  print "  -url2 <str>            : url of compara DB \n";
  print "  -gdb1 <int>            : genome_db_id of first genome\n";
  print "  -gdb2 <int>            : genome_db_id of second genome\n";
  print "homology_diff.pl v1.1\n";

  exit(1);
}


##################################
#
# HomologySet testing
#
##################################


sub load_homology_set
{
  my $self = shift;
  my $method_link_type = shift;
  my $species = shift;
  
  my $mlssDBA = $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor;
  my $homologyDBA = $self->{'comparaDBA'}->get_Homology2Adaptor;
 
  my $mlss = $mlssDBA->fetch_by_method_link_type_genome_db_ids($method_link_type, $species);
  
  my $starttime = time();
  my $homology_list = $homologyDBA->fetch_all_by_MethodLinkSpeciesSet($mlss);
  printf("%1.3f sec to fetch %d homology objects\n", 
         (time() - $starttime), scalar(@{$homology_list}));

  $starttime = time();
  my $homology_set = new Bio::EnsEMBL::Compara::Production::HomologySet;
  $homology_set->add(@{$homology_list});
  printf("%1.3f sec to load HomologySet\n", (time() - $starttime));

  return $homology_set;
}


sub test_homology_set
{
  my $self = shift;
  
  my $homology_set1 = load_homology_set($self, 'TREE_HOMOLOGIES',[1,2]);
  $homology_set1->print_stats;

  my $homology_set2 = load_homology_set($self, 'ENSEMBL_ORTHOLOGUES',[1,2]);
  $homology_set2->print_stats;

  my $missing1 = $homology_set1->crossref_missing_genes($homology_set2);
  printf("%d genes in set1 not in set2\n", scalar(@$missing1));
  
  my $missing2 = $homology_set2->crossref_missing_genes($homology_set1);
  printf("%d genes in set2 not in set1\n", scalar(@$missing2));
  
  my $cross_hash = $homology_set1->crossref_homology_types($homology_set2);
  $homology_set1->print_conversion_stats($homology_set2, $cross_hash);
}





1;


