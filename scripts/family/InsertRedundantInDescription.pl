#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Taxon;

$| = 1;

my $usage = "
Usage: $0 options redundant_ids_file description_file

Options:
-host 
-dbname
-dbuser
-dbpass
-conf_file

\n";


my $help = 0;
my $host;
my $port = "";
my $dbname;
my $dbuser = 'ensro';
my $dbpass;
my $conf_file;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file);

my ($redunfile, $desc_file) = @ARGV;

if ($help) {
  print $usage;
  exit 0;
}

# get the redundant ids
if ($redunfile =~ /\.gz/) {
  open REDUN, "gunzip -c $redunfile|" ||
    die "$redunfile: $!";
} else {
  open REDUN, $redunfile ||
    die "$redunfile: $!";
}

my %redun_hash;

while (<REDUN>) {
  chomp;
  my @tab = split;
  my $refid = shift @tab;
  foreach my $id (@tab) {
    next if ($id eq $refid);
    $redun_hash{$id} = $refid;
  }
}

close REDUN;

# get id's type, description and taxon
if ($desc_file =~ /\.gz/) {
  open DESC, "gunzip -c $desc_file|" || 
    die "$desc_file: $!"; 
} else {
  open DESC, $desc_file ||
    die "$desc_file: $!";
}

my %seqinfo;

while (<DESC>) {
  if (/^(.*)\t(.*)\t(.*)\t(.*)$/) {
    my ($type,$seqid,$desc,$taxon) = ($1,$2,$3,$4);
    if(!$taxon || !$seqid) {
      warn("taxon or seqid not defined, skipping description:\n".
           "\t[$type]\t[$seqid]\t\[$desc]\t[$taxon]\n");
      next;
    }
    $desc = "" unless (defined $desc);
    $seqinfo{$seqid}{'type'} = $type;
    $seqinfo{$seqid}{'description'} = $desc;
    $seqinfo{$seqid}{'taxon'} = $taxon;
  } else {
    warn "$desc_file has not the expected format
EXIT 2\n";
    exit 2;
  }
}

close DESC
  || die "$desc_file: $!";

my $db;

if (defined $conf_file) {
  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                    -port   => $port,
                                                    -user   => $dbuser,
                                                    -pass   => $dbpass,
                                                    -dbname => $dbname,
                                                    -conf_file => $conf_file);
} else {
  $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                    -port   => $port,
                                                    -user   => $dbuser,
                                                    -pass   => $dbpass,
                                                    -dbname => $dbname);
}

my $fa = $db->get_FamilyAdaptor;
my $ma = $db->get_MemberAdaptor;

foreach my $id (keys %redun_hash) {
  my $refid = $redun_hash{$id};
  my $refid_source = uc($seqinfo{$refid}{'type'});
  my $refid_member = $ma->fetch_by_source_stable_id($refid_source, $refid);
  die "No member for $refid_source $refid\n" unless (defined $refid_member);
  
  my $family = $fa->fetch_by_Member($refid_member)->[0];
  die "No family for $refid_source $refid\n" unless (defined $family);

  print uc($seqinfo{$id}{'type'}),"\t",$family->dbID,"\t",$id,"\t",$seqinfo{$id}{'description'},"\n";
}
