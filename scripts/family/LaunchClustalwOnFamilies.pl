#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;

my $usage = "
Usage: $0 options

i.e.

$0 

Options:
-host 
-dbname family dbname
-dbuser
-dbpass
-family_stable_id|-family_id
-fasta_file
-fasta_index
-dir
-store

\n";

my ($family_stable_id,$family_id,$fasta_file,$fasta_index);

my $dir = ".";
my $store = 0;

my $fastafetch_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/fastafetch";

if (-e "/proc/version") {
  # it is a linux machine
  $fastafetch_executable = "/nfs/acari/abel/bin/i386/fastafetch";
}

my $clustalw_executable = "/usr/local/ensembl/bin/clustalw1.82";

my $help = 0;
my $host;
my $dbname;
my $dbuser;
my $dbpass;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'family_stable_id=s' => \$family_stable_id,
	   'family_id=i' => \$family_id,
	   'fasta_file=s' => \$fasta_file,
	   'fasta_index=s' => \$fasta_index,
	   'dir=s' => \$dir,
	   'store' => \$store);

if ($help) {
  print $usage;
  exit 0;
}


my $rand = time().rand(1000);

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => $host,
									 -user   => $dbuser,
									 -pass   => $dbpass,
									 -dbname => $dbname);

my $FamilyAdaptor = $family_db->get_FamilyAdaptor;
my $FamilyMemberAdaptor = $family_db->get_FamilyMemberAdaptor;

my $family;
my $id;

if (defined $family_stable_id) {
  $id = $family_stable_id;
  $family = $FamilyAdaptor->fetch_by_stable_id($family_stable_id);
} elsif (defined $family_id) {
  $id = $family_id;
  $family = $FamilyAdaptor->fetch_by_dbID($family_id);
}

my @members;

push @members,@{$family->get_members_by_dbname('ENSEMBLPEP')};
push @members,@{$family->get_members_by_dbname('SWISSPROT')};
push @members,@{$family->get_members_by_dbname('SPTREMBL')};

my $sb_id = "/tmp/sb_id.$rand";

open S,">$sb_id";

foreach my $member (@members) {
  my $member_stable_id = $member->stable_id;
  print STDERR $member_stable_id,"\n";
  print S $member_stable_id,"\n";
}

close S;

my $sb_file = "/tmp/sb.$rand";

unless (system("$fastafetch_executable $fasta_file $fasta_index $sb_id > $sb_file") == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in fastafetch $sb_id, $!\n";
}

# If only one member no need for a multiple alignment.
# Just load the sequence as it is in the family db

if (scalar @members == 1) {
  my $FH = IO::File->new();
  $FH->open($sb_file) || die "Could not open fasta file [$sb_file], $!\n;";
  
  my $member_stable_id;
  my $member_seq;
  
  my $number_of_sequence = 0;
  
  while (<$FH>) {
    if (/^>(\S+)\s*.*$/) {
      $member_stable_id = $1;
      $number_of_sequence++;
    } elsif (/^[a-zA-Z\*]+$/) { ####### add * for protein with stop in it!!!!
      chomp;
      $member_seq .= $_;
    }
  }
  
  if ($number_of_sequence != 1) {
    warn "For family " . $family->stable_id . " we get $number_of_sequence sequence instead of 1
EXIT 1\n";
    exit 1;
  }
  
  $FH->close;
  
  if (defined $member_stable_id && defined $member_seq) {
    my $member = $FamilyMemberAdaptor->fetch_by_stable_id($member_stable_id)->[0];
    $member->alignment_string($member_seq);
    $FamilyMemberAdaptor->update($member);
    undef $member_stable_id;
    undef $member_seq;
  } else {
    warn "For family " . $family->stable_id . " member_stable_id or sequence are not defined
EXIT 2\n";
    exit 2;
  }
  
  exit 0;
}

my $clustal_file = "/tmp/clustalw.$rand";

my $status = system("$clustalw_executable -INFILE=$sb_file -OUTFILE=$clustal_file");

unless ($status == 0) {
  unlink glob("/tmp/*$rand*");
  die "error in clustalw, $!\n";
}

if ($store) {
  $family->read_clustalw($clustal_file);
  foreach my $member (@{$family->get_all_members}) {
    $FamilyMemberAdaptor->update($member);
  }
} else {
  unless (system("cp $clustal_file $dir/$id.out") == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in cp $id.out,$1\n";
  }
}

unlink glob("/tmp/*$rand*");

exit 0;
