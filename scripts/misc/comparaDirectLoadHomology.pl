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
use Bio::EnsEMBL::Compara::Homology;
use Bio::EnsEMBL::Compara::Attribute;



# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'speciesList'} = ();
$self->{'orthoFile'} = undef;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'file=s'  => \$self->{'orthoFile'},
          );

if ($help) { usage(); }

parse_conf($self, $conf_file);

if($host)   { $self->{'compara_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'compara_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'compara_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'compara_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'compara_conf'}->{'-pass'}   = $pass; }


unless(defined($self->{'compara_conf'}->{'-host'})
       and defined($self->{'compara_conf'}->{'-user'})
       and defined($self->{'compara_conf'}->{'-dbname'}))
{
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage(); 
}


$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_conf'}});
$self->{'pipelineDBA'} = new Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor(-DBCONN => $self->{'comparaDBA'}->dbc);

load_orthos($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaDirectLoadOrtho.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -file <path>           : file containing homology pairs (as gene_stable_ids)\n";
  print "comparaDirectLoadOrtho.pl v1.1\n";
  
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


sub load_orthos {
  my $self = shift;
 
  my $homologyDBA = $self->{'comparaDBA'}->get_HomologyAdaptor();
  my $memberDBA = $self->{'comparaDBA'}->get_MemberAdaptor();

  my $build_homology_idx=1;

  my $fileCount=0;
  my $loadCount=0;
  open ORTHOS, $self->{'orthoFile'};
  while(<ORTHOS>) {
    $fileCount++;
    my ($stable_id1, $stable_id2) = split;
    #print("$stable_id1 <=> $stable_id2\n");
    my $gene1 = $memberDBA->fetch_by_source_stable_id('ENSEMBLGENE', $stable_id1);
    my $gene2 = $memberDBA->fetch_by_source_stable_id('ENSEMBLGENE', $stable_id2);
    warn("ERROR couldn't find member for stable_id = $stable_id1\n") unless($gene1); 
    warn("ERROR couldn't find member for stable_id = $stable_id2\n") unless($gene2);

  # create an Homology object
    my $homology = new Bio::EnsEMBL::Compara::Homology;
    my $stable_id = $gene1->taxon_id() . "_" . $gene2->taxon_id . "_";
    $stable_id .= sprintf ("%011.0d",$build_homology_idx++);
    $homology->stable_id($stable_id);
    $homology->source_name("ENSEMBL_HOMOLOGS");
    $homology->description("DWGA");

    my $pep_member_id1 = $self->get_pep_member_id($gene1->dbID);
    my $pep_member_id2 = $self->get_pep_member_id($gene2->dbID);
    if($pep_member_id1 and $pep_member_id2) {
      my $attribute1 = new Bio::EnsEMBL::Compara::Attribute;
      $attribute1->peptide_member_id($pep_member_id1);
      $homology->add_Member_Attribute([$gene1, $attribute1]);

      my $attribute2 = new Bio::EnsEMBL::Compara::Attribute;
      $attribute2->peptide_member_id($pep_member_id2);
      $homology->add_Member_Attribute([$gene2, $attribute2]);

      #print($homology->stable_id . "\n");
      $homologyDBA->store($homology);
      $loadCount++;
    }
    else {
      warn("CAN'T create $stable_id1 <=> $stable_id2 : missing peptide(s)\n");
    }
  }

  print("$fileCount homologies in file\n");
  print("$loadCount homologies stored in db\n");

}

sub get_pep_member_id
{
  my $self = shift;
  my $gene_member_id = shift;

  my $sql = "select member_gene_peptide.peptide_member_id from member_gene_peptide,member,sequence where gene_member_id =$gene_member_id AND member_gene_peptide.peptide_member_id=member.member_id AND member.sequence_id=sequence.sequence_id ORDER by sequence.length DESC";

  my $pep_member_id;
  my $sth = $self->{'comparaDBA'}->prepare($sql);
  $sth->execute();
  $sth->bind_columns(\$pep_member_id);
  $sth->fetch();
  $sth->finish();
  warn("NO peptide for gene_member_id = $gene_member_id\n") unless($pep_member_id);
  return $pep_member_id;
}
