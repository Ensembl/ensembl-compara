#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->no_version_check(1);

my $usage = "
Usage: $0 options

Options:
-host 
-dbname family dbname
-dbuser
-dbpass
-family_stable_id|-family_id
-muscle_file
-dir
-store

\n";

my ($family_stable_id,$family_id);

my $dir = ".";
my $store = 0;

my $muscle_executable = "/usr/local/ensembl/bin/muscle";

unless (-e $muscle_executable) {
  $muscle_executable = "/nfs/acari/abel/bin/alpha-dec-osf4.0/muscle";
  if (-e "/proc/version") {
    # it is a linux machine
    $muscle_executable = "/nfs/acari/abel/bin/i386/muscle";
  }
}

my $help = 0;
my $host;
my $port = "";
my $dbname;
my $dbuser;
my $dbpass;
my $muscle_file;
my $fast = 0;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'family_stable_id=s' => \$family_stable_id,
	   'family_id=i' => \$family_id,
	   'dir=s' => \$dir,
           'muscle_file=s' => \$muscle_file,
	   'store' => \$store,
           'fast' => \$fast);

if ($help) {
  print $usage;
  exit 0;
}

if (defined $muscle_file && $store == 0) {
  die "If you provide a muscle_file, you should also set -store option\n"
}

my $rand = time().rand(1000);

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname);

my $FamilyAdaptor = $db->get_FamilyAdaptor;
my $MemberAdaptor = $db->get_MemberAdaptor;
my $AttributeAdaptor = $db->get_AttributeAdaptor;

my $family;
my $id;

if (defined $family_stable_id) {
  $id = $family_stable_id;
  $family = $FamilyAdaptor->fetch_by_stable_id($family_stable_id);
} elsif (defined $family_id) {
  $id = $family_id;
  $family = $FamilyAdaptor->fetch_by_dbID($family_id);
}

my $sb_file = "/tmp/sb.$rand";

unless (defined $muscle_file) {

  my @members_attributes;

  push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

  open S, ">$sb_file";
  
  foreach my $member_attribute (@members_attributes) {
    my ($member,$attribute) = @{$member_attribute};
    my $member_stable_id = $member->stable_id;
    print STDERR $member_stable_id,"\n";
    print S ">$member_stable_id\n";
    my $seq = $member->sequence;
    $seq =~ s/(.{72})/$1\n/g;
    chomp $seq;
    print S $seq,"\n";
  }

  close S;

  # If only one member no need for a multiple alignment.
  # Just load the sequence as it is in the family db

  if (scalar @members_attributes == 1) {
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
      my $member = $MemberAdaptor->fetch_by_source_stable_id($member_stable_id);
      my $attribute = $AttributeAdaptor->fetch_by_Member_Relation($member,$family);
      my $alignment_string = $member_seq;
      $alignment_string =~ s/\-([A-Z])/\- $1/g;
      $alignment_string =~ s/([A-Z])\-/$1 \-/g;
      my @cigar_segments = split " ",$alignment_string;
      my $cigar_line = "";
      foreach my $segment (@cigar_segments) {
      my $seglength = length($segment);
      $seglength = "" if ($seglength == 1);
      if ($segment =~ /^\-+$/) {
        $cigar_line .= $seglength . "D";
      } else {
        $cigar_line .= $seglength . "M";
      }
    }
      $member->sequence($member_seq);
      $attribute->cigar_line($cigar_line);
      
      $FamilyAdaptor->update_relation([$member, $attribute]);
      
      undef $member_stable_id;
      undef $member_seq;
    } else {
      warn "For family " . $family->stable_id . " member_stable_id or sequence are not defined
EXIT 2\n";
      exit 2;
    }
    
    exit 0;
  }

  $muscle_file = "/tmp/muscle.$rand";

# The following muscle parameters are supposed to be used with huge alignments 
# (several thousands of sequences)
  my $status;
  if ($fast) {
    $status = system("$muscle_executable -in $sb_file -out $muscle_file.msc -maxiters 1 -diags1 -sv -clw -nocore -verbose -quiet -log $muscle_file.msc.log");
  } else {
    $status = system("$muscle_executable -in $sb_file -out $muscle_file.msc -maxhours 5 -clw -nocore -verbose -quiet -log $muscle_file.msc.log");
  }
  
  unless ($status == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in muscle, $!\n";
  }
}  


if ($store) {
  $family->read_clustalw("$muscle_file.msc");
  my @members_attributes;

  push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

  foreach my $member_attribute (@members_attributes) {
    $FamilyAdaptor->update_relation($member_attribute);
  }
} else {
  unless (system("cp $muscle_file.msc $dir/$id.msc") == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in cp $id.out,$1\n";
  }
  system("cp $muscle_file.msc.log $dir/$id.msc.log");
  system("cp $sb_file $dir/$id.pep");
}

unlink glob("/tmp/*$rand*");

exit 0;
