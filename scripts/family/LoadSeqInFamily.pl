#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use IO::File;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::MemberAdaptor;

my ($desc_file,$fasta_file) = @ARGV;

my %seqinfo;

if ($desc_file =~ /\.gz/) {
  open DESC, "gunzip -c $desc_file|" || 
    die "$desc_file: $!"; 
} else {
  open DESC, $desc_file ||
    die "$desc_file: $!";
}

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

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => 'ecs2e.internal.sanger.ac.uk',
                                                     -user   => 'ensadmin',
                                                     -pass   => 'ensembl',
                                                     -dbname => 'ensembl_compara_20_1b');

my $MemberAdaptor = $db->get_MemberAdaptor;

my $FH = IO::File->new();
$FH->open($fasta_file) || die "Could not open alignment file [$fasta_file], $!\n;";

my $member_stable_id;
my $member_seq;

while (<$FH>) {
  if (/^>(\S+)\s*.*$/) {
    my $new_id = $1;
    if (defined $member_stable_id && defined $member_seq) {
      my $source = uc($seqinfo{$member_stable_id}{'type'});
      if ($source eq "ENSEMBLPEP") {
        print STDERR "$member_stable_id sequence skipped\n";
        next;
      }
      my $member = $MemberAdaptor->fetch_by_source_stable_id($source, $member_stable_id);
      unless (defined $member) {
        print STDERR "$source, $member_stable_id not in db\n";
        $member_stable_id = $new_id;
        next;
      }
      print STDERR "$source, $member_stable_id";
      $member->sequence($member_seq);
      $MemberAdaptor->update_sequence($member);
      print STDERR " loaded\n";
      undef $member_stable_id;
      undef $member_seq;
    }
    $member_stable_id = $new_id;
  } elsif (/^[a-zA-Z\*]+$/) { ####### add * for protein with stop in it!!!!
    chomp;
    $member_seq .= $_;
  }
}

$FH->close;

if (defined $member_stable_id && defined $member_seq) {
  my $source = uc($seqinfo{$member_stable_id}{'type'});
  if ($source eq "ENSEMBLPEP") {
    print STDERR "$member_stable_id sequence skipped\n";
    exit 0;
  }
  my $member = $MemberAdaptor->fetch_by_source_stable_id($source, $member_stable_id);
  unless (defined $member) {
    print STDERR "$source, $member_stable_id not in db\n";
    exit 0;
  }
  $member->sequence($member_seq);
  $MemberAdaptor->update_sequence($member);
  print STDERR "$member_stable_id sequence loaded\n";
}

exit 0;
