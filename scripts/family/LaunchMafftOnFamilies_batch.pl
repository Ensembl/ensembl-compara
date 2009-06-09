#!/usr/local/bin/perl -w

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
-starting_family_id
-family_stable_id
-dir
-store

\n";

my $mafft_executable = "/software/ensembl/compara/mafft-6.522/bin/mafft";
BEGIN {$ENV{MAFFT_BINARIES} = '/software/ensembl/compara/mafft-6.522'; }

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
my $dir = ".";
my $store = 0;
my $parttree = 0;
my $fast = 0;
my ($family_stable_id,$starting_family_id,$num_families);

GetOptions('help' => \$help,
	   'h|host=s' => \$host,
	   'p|port=i' => \$port,
	   'db|dbname=s' => \$dbname,
	   'u|dbuser=s' => \$dbuser,
	   'ps|dbpass=s' => \$dbpass,
	   'fs|family_stable_id=s' => \$family_stable_id,
	   'f|starting_family_id=s' => \$starting_family_id,
	   'n|num_families=s' => \$num_families,
	   'dir=s' => \$dir,
	   's|store' => \$store,
       'parttree' => \$parttree,
       'fast' => \$fast);

if ($help) {
    print $usage;
    exit 0;
}

my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname);
my $FamilyAdaptor = $db->get_FamilyAdaptor;

die "Need to find starting_family_id + num_families: $!\n" unless (defined($starting_family_id) && defined($num_families));

my $starting_id = $starting_family_id;
my $end_id = $starting_family_id + $num_families - 1;

if ($starting_id > $end_id) {
  my $temp = $starting_id;
  $starting_id = $end_id;
  $end_id = $temp;
}

my $pep_dir = "$dir/pep";
my $msc_dir = "$dir/msc";

unless($store) {
    mkdir $pep_dir;
    mkdir $msc_dir;
}

my $failed = 0;

for my $family_id ($starting_id .. $end_id) {

    my $family = $FamilyAdaptor->fetch_by_dbID($family_id);
    unless (defined($family)) {
        print STDERR "Failed: family $family_id could not have been fetched by the adaptor\n";
        $failed = 1;
        next;
    }

    my $aln;
    eval {$aln = $family->get_SimpleAlign};
    unless ($@) {
    my $flush = $aln->is_flush;
        # print STDERR "Family $family_id already aligned\n";
        next if (defined($flush));
    }

    my @members_attributes = ();

    push @members_attributes,@{$family->get_Member_Attribute_by_source('ENSEMBLPEP')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SWISSPROT')};
    push @members_attributes,@{$family->get_Member_Attribute_by_source('Uniprot/SPTREMBL')};

    if(scalar @members_attributes == 0) {
        print STDERR "Failed: family $family_id does not seem to contain any members\n";
        $failed = 1;
        next;

    } elsif(scalar @members_attributes == 1) {    # the simple singleton case: just load the fake cigar_line

        my ($member,$attribute) = @{$members_attributes[0]};

        my $cigar_line = length($member->sequence).'M';
        eval { $attribute->cigar_line($cigar_line) };
        if($@) {
            print STDERR "Failed: could not set the cigar_line for singleton family $family_id, because: $@\n";
            $failed = 1;
            next;
        } elsif($store) {
            $FamilyAdaptor->update_relation([$member, $attribute]);
        }
        
        next;
    }

    # otherwise prepare the files and perform the actual mafft run:

    my $rand = time().rand(1000);
    my $pep_file = "/tmp/family_${family_id}.pep.$rand";

    open PEP, ">$pep_file";

    foreach my $member_attribute (@members_attributes) {
        my ($member,$attribute) = @{$member_attribute};
        my $member_stable_id = $member->stable_id;
        my $seq = $member->sequence;

        print PEP ">$member_stable_id\n";
        $seq =~ s/(.{72})/$1\n/g;
        chomp $seq;
        unless (defined($seq)) {
            print STDERR "Failed: member $member_stable_id in family $family_id doesn't have a sequence\n";
            $failed = 1;
            next;
        }
        print PEP $seq,"\n";
    }

    close PEP;

    my $mafft_file = "/tmp/family_${family_id}.mafft.$rand";

    my $mafft_args = '';
    if($parttree) { $mafft_args .= " --parttree " }
    if($fast)     { $mafft_args .= " --retree 1 " }

    my $cmd_line = "$mafft_executable $mafft_args $pep_file > $mafft_file";
    print STDERR "About to execute: $cmd_line\n";

    if(system($cmd_line)) {
        print STDERR "Failed: running mafft on family $family_id failed, because: $!\n";
        $failed = 1;
        next;
    }

    if ($store) {
        $family->load_cigars_from_fasta($mafft_file, 1);
    } else {
        if(system("cp $mafft_file $msc_dir/$family_id.msc")) {
            print STDERR "Failed: could not copy '$mafft_file', because: $!\n";
            $failed = 1;
            next;
        }
        system("cat $mafft_file.log > $dir/family_${family_id}.log");
        if(system("cp $pep_file $pep_dir/family_${family_id}.pep")) {
            print STDERR "Failed: could not copy '$pep_file', because: $!\n";
            $failed = 1;
            next;
        }
    }

        # the files will be removed on success and should stay undeleted on failure
    unlink $pep_file, $mafft_file;
}

exit($failed);
