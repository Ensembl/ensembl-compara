#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use File::Basename;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

my $usage = "
Usage: $0 options

Options:
-host 
-dbname family dbname
-dbuser
-dbpass
-family_stable_id|-family_id
-clustal_file
-dir
-store

\n";

my ($family_stable_id,$family_id);

my $dir = ".";
my $store = 0;

my $clustalw_executable = "/usr/local/ensembl/bin/clustalw";

my $help = 0;
my $host;
my $port = "";
my $dbname;
my $dbuser;
my $dbpass;
my $clustal_file;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'family_stable_id=s' => \$family_stable_id,
	   'family_id=i' => \$family_id,
	   'dir=s' => \$dir,
           'clustal_file=s' => \$clustal_file,
	   'store' => \$store);

if ($help) {
  print $usage;
  exit 0;
}

if (defined $clustal_file && $store == 0) {
  die "If you provide a clustal_file, you should also set -store option\n"
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

unless (defined $clustal_file) {

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

  $clustal_file = "/tmp/clustalw.$rand";

  my $status = system("$clustalw_executable -INFILE=$sb_file -OUTFILE=$clustal_file");
  
  unless ($status == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in clustalw, $!\n";
  }
}  


if ($store) {
  $family->read_clustalw($clustal_file);
  my @members_attributes;

  push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
  push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

  foreach my $member_attribute (@members_attributes) {
    $FamilyAdaptor->update_relation($member_attribute);
  }
} else {
  unless (system("cp $clustal_file $dir/$id.aln") == 0) {
    unlink glob("/tmp/*$rand*");
    die "error in cp $id.out,$1\n";
  }
  system("cp $sb_file $dir/$id.pep");
}

unlink glob("/tmp/*$rand*");

exit 0;
