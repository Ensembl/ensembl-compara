#!/usr/local/ensembl/bin/perl -w

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
use Bio::SimpleAlign;
use Bio::EnsEMBL::Compara::Tree;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'speciesList'} = ();
$self->{'removeXedSeqs'} = undef;
$self->{'outputFasta'} = undef;
$self->{'noSplitSeqLines'} = undef;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
my $url;

GetOptions('help'     => \$help,
           'url=s'    => \$url,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'fasta=s'  => \$self->{'outputFasta'},
           'noX=i'    => \$self->{'removeXedSeqs'},
           'nosplit'  => \$self->{'noSplitSeqLines'},
           'gab_id=i' => \$self->{'print_align_GAB_id'},
          );

if ($help) { usage(); }

parse_conf($self, $conf_file);

if($host)   { $self->{'compara_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'compara_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'compara_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'compara_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'compara_conf'}->{'-pass'}   = $pass; }

$self->{'comparaDBA'}  = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara') if($url);
if(defined($self->{'comparaDBA'})) {
  print("URL OK!!!\n");
} else {
  unless(defined($self->{'compara_conf'}->{'-host'})
         and defined($self->{'compara_conf'}->{'-user'})
         and defined($self->{'compara_conf'}->{'-dbname'}))
  {
    print "\nERROR : must specify host, user, and database to connect to compara\n\n";
    usage();
  }
  $self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_conf'}});
}

create_taxon_tree($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "testTaxonTree.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -fasta <path>          : file where fasta dump happens\n";
  print "  -noX <num>             : don't dump if <num> 'X's in a row in sequence\n";
  print "  -nosplit               : don't split sequence lines into readable format\n";
  print "testTaxonTree.pl v1.1\n";
  
  exit(1);  
}


sub parse_conf {
  my $self      = shift;
  my $conf_file = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      #print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'COMPARA') {
        $self->{'compara_conf'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'BLAST_TEMPLATE') {
        $self->{'analysis_template'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'SPECIES') {
        push @{$self->{'speciesList'}}, $confPtr;
      }
    }
  }
}


sub create_taxon_tree {
  my $self = shift;

  my $root = new Bio::EnsEMBL::Compara::TreeNode;
  my $count = 1;
  
  my $taxonDBA = $self->{'comparaDBA'}->get_TaxonAdaptor;
  my $gdb_list = $self->{'comparaDBA'}->get_GenomeDBAdaptor->fetch_all;
  foreach my $gdb (@$gdb_list) {
    my $taxon = $taxonDBA->fetch_by_dbID($gdb->taxon_id);
    my @levels = $taxon->classification;
    my $taxon_info = join(":", $taxon->classification);
    #print("$taxon_info\n");

    my $child_tree = undef;
    foreach my $level_name (@levels) {
      #print("  $level_name\n");
      my $found = $root->find_node_by_name($level_name);
      if($found) {
        $found->add_child_node($child_tree);
        $child_tree=undef;
        last;
      } else {
        my $new_node = new Bio::EnsEMBL::Compara::TreeNode;
        $new_node->dbID($count++);
        $new_node->name($level_name);
        if($child_tree) {
          $new_node->add_child_node($child_tree);
          $child_tree = $new_node;
        } else {
          $child_tree = $new_node;
        }
      }
    }
    $root = $child_tree if($child_tree);
    
  }
  
  $root->print_tree;

  $self->{'comparaDBA'}->get_TreeNodeAdaptor->store($root);
  printf("store as dbID=%d\n", $root->dbID);
  
  my $fetchTree = $self->{'comparaDBA'}->get_TreeNodeAdaptor->fetch_tree_rooted_at_node_id($root->dbID);
  $fetchTree->print_tree;

}


