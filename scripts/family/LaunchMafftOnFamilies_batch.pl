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
-mafft_file
-dir
-store

\n";

my ($family_stable_id,$starting_family_id,$starting_family_id_file,$num_families);

my $dir = ".";
my $store = 0;

my $mafft_executable = "/nfs/acari/avilella/src/mafft/mafft-6.522/scripts/mafft";
BEGIN {$ENV{MAFFT_BINARIES} = '/nfs/acari/avilella/src/mafft/mafft-6.522/binaries'; }

unless (-e $mafft_executable) {
  print STDERR "Error no binaries\n";
  exit 1;
}

my $help = 0;
my $host;
my $port = "";
my $dbname;
my $dbuser;
my $dbpass;
my $mafft_file;
my $fast = 0;
my $parttree = 0;

GetOptions('help' => \$help,
	   'h|host=s' => \$host,
	   'p|port=i' => \$port,
	   'db|dbname=s' => \$dbname,
	   'u|dbuser=s' => \$dbuser,
	   'ps|dbpass=s' => \$dbpass,
	   'fs|family_stable_id=s' => \$family_stable_id,
	   'f|starting_family_id=s' => \$starting_family_id,
	   'starting_family_id_file=s' => \$starting_family_id_file,
	   'n|num_families=s' => \$num_families,
	   'dir=s' => \$dir,
           'mafft_file=s' => \$mafft_file,
	   's|store' => \$store,
           'parttree' => \$parttree,
           'fast' => \$fast);

if ($help) {
  print $usage;
  exit 0;
}

if (defined $mafft_file && $store == 0) {
  die "If you provide a mafft_file, you should also set -store option\n"
}

my $rand;

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname);

my $family;
my $id;

if (defined($starting_family_id_file)) {
    open LIST, "$starting_family_id_file" or die "couldnt open family file $starting_family_id_file: $!\n";
    while (<LIST>) {
      chomp $_;
      $starting_family_id = $_;
    }
    close LIST;
}

die "Need to find starting_family_id + num_families: $!\n" unless (defined($starting_family_id) && defined($num_families));
my $starting_id = $starting_family_id;
my $end_id = $starting_family_id + $num_families;
my $temp;
if ($starting_id > $end_id) {
  $temp = $starting_id;
  $starting_id = $end_id;
  $end_id = $temp;
}

my $pep_dir = "$dir/pep";
my $msc_dir = "$dir/msc";

mkdir $pep_dir;
mkdir $msc_dir;

for my $family_id ($starting_id .. $end_id) {
  $mafft_file = undef;
  $id = $family_id;
  my $FamilyAdaptor = $db->get_FamilyAdaptor;
  $family = $FamilyAdaptor->fetch_by_dbID($family_id);
  unless (defined($family)) {
    print STDERR "Failed: $family_id\n";
    next;
  }

  my $aln;
  eval {$aln = $family->get_SimpleAlign};

  unless ($@) {
    my $flush = $aln->is_flush;
    # print STDERR "Family $family_id already aligned\n";
    next if (defined($flush));
  }

  $rand = time().rand(1000);
  my $sb_file = "/tmp/sb.$rand";

  unless (defined $mafft_file) {

    my @members_attributes;

    push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

    unless (0 < scalar(@members_attributes)) {
      print STDERR "Failed: $family_id\n";
      next;
    }

    open S, ">$sb_file";

    foreach my $member_attribute (@members_attributes) {
      my ($member,$attribute) = @{$member_attribute};
      my $member_stable_id = $member->stable_id;
      # print STDERR $member_stable_id,"\n";
      print S ">$member_stable_id\n";
      my $seq = $member->sequence;
      $seq =~ s/(.{72})/$1\n/g;
      chomp $seq;
      unless (defined($seq)) {
        print STDERR "Failed: $family_id\n";
        next;
      }
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
        my $MemberAdaptor = $db->get_MemberAdaptor;
        my $member = $MemberAdaptor->fetch_by_source_stable_id(undef,$member_stable_id);
        my $AttributeAdaptor = $db->get_AttributeAdaptor;
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
        eval { $attribute->cigar_line($cigar_line) };
      
        $FamilyAdaptor->update_relation([$member, $attribute]) unless ($@);
      
        undef $member_stable_id;
        undef $member_seq;
      } else {
        warn "For family " . $family->stable_id . " member_stable_id or sequence are not defined
EXIT 2\n";
        exit 2;
      }
    
      exit 0;
    }

  $mafft_file = "/tmp/mafft.$rand";

  my $status;
  my $extratags = '';
  if($parttree) { $extratags .= " --parttree " }
  if($fast) { $extratags .= " --retree 1 " }
  print STDERR "### $mafft_executable $extratags $sb_file > $mafft_file.msc\n";
  $status = system("$mafft_executable $extratags $sb_file > $mafft_file.msc");
  
    unless ($status == 0) {
      unlink glob("/tmp/*$rand*");
      print STDERR "Failed: $family_id\n";
      next;
      #      die "error in mafft, $!\n";
    }
  }


  if ($store) {
    $family->read_fasta("$mafft_file.msc");
    my @members_attributes;

    push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

    foreach my $member_attribute (@members_attributes) {
      $FamilyAdaptor->update_relation($member_attribute);
    }
  } else {
    unless (system("cp $mafft_file.msc $msc_dir/$id.msc") == 0) {
      unlink glob("/tmp/*$rand*");
      die "error in cp $id.out,$1\n";
    }
    system("cat $mafft_file.msc.log > $dir/$starting_id.msc.log");
    system("cp $sb_file $pep_dir/$id.pep");
    unlink glob("/tmp/*$rand*");
    $mafft_file = undef;
  }
}

1;
