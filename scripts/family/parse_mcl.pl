#!/usr/local/ensembl/bin/perl -w
# $Id$

# Parse MCL output (numbers) back into real clusters (with protein names)

use strict;
use Getopt::Long;
use IO::File;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::Family;
use Bio::EnsEMBL::ExternalData::Family::FamilyMember;
use Bio::EnsEMBL::ExternalData::Family::Taxon;

$| = 1;

my $usage = "
Usage: $0 options mcl_file index_file desc_file > mcl.clusters

i.e.

$0 

Options:
-host 
-dbname family dbname
-dbuser
-dbpass
-release release version i.e. 13_1
-prefix family stable id prefix (default: ENSF)
-offset family id numbering start (default:1)

\n";

my $help = 0 ;
my $release_number;
my $family_prefix = "ENSF";
my $family_offset = 1;
my $host;
my $dbname;
my $dbuser;
my $dbpass;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'release=s' => \$release_number,
	   'prefix=s' => \$family_prefix,
	   'offset=i' => \$family_offset);

if ($help) {
  print $usage;
  exit 0;
}

unless (scalar @ARGV == 3) {
  print "Need 3 arguments\n";
  print $usage;
  exit 0;
}

my ($mcl_file,$index_file,$desc_file) = @ARGV;

my @clusters;
my %seqinfo;
my %member_index;

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor(-host   => $host,
									 -user   => $dbuser,
									 -dbname => $dbname,
									 -pass => $dbpass);

my $FamilyAdaptor = $family_db->get_FamilyAdaptor;

print STDERR "Reading index file...";

if ($index_file =~ /\.gz/) {
  open INDEX, "gunzip -c $index_file|" ||
    die "$index_file: $!";
} else {
  open INDEX, $index_file ||
    die "$index_file: $!";
}
my $max_member_index;

while (<INDEX>) {
  if (/^(\S+)\s+(\S+)/) {
    my ($index,$seqid) = ($1,$2);
    $member_index{$index} = $seqid;
    $seqinfo{$seqid}{'index'} = $index;
    unless (defined $max_member_index) {
      $max_member_index = $index;
    } elsif ($index > $max_member_index) {
      $max_member_index = $index;
    }
  } else {
    warn "$index_file has not the expected format
EXIT 1\n";
    exit 1;
  }
}
close INDEX
  || die "$index_file: $!";

print STDERR "Done\n";

print STDERR "Reading description file...";

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
    unless (defined $seqinfo{$seqid}{'index'}) {
      $max_member_index++;
      $seqinfo{$seqid}{'index'} = $max_member_index;
    }
  } else {
    warn "$desc_file has not the expected format
EXIT 2\n";
    exit 2;
  }
}

close DESC
  || die "$desc_file: $!";

print STDERR "Done\n";

print STDERR "Reading mcl file...";
if ($index_file =~ /\.gz/) {
  open MCL, "gunzip -c $mcl_file|" ||
    die "$mcl_file: $!";
} else {
  open MCL, $mcl_file ||
    die "$mcl_file: $!";
}

my $headers_off = 0;
my $one_line_members = "";

while (<MCL>) {
  if (/^begin$/) {
    $headers_off = 1;
    next;
  }
  next unless ($headers_off);
  last if (/^\)$/);
  chomp;
  $one_line_members .= $_;
  if (/\$/) {
    push @clusters, $one_line_members;
    $one_line_members = "";
  }
}

close MCL ||
  die "$mcl_file: $!";

print STDERR "Done\n";

print STDERR "Loading clusters in family db\n";

# starting to use the Family API here to load in a family database
# still print out description for each entries in order to determinate 
# a consensus description

my $max_cluster_index;

foreach my $cluster (@clusters) {
  my ($cluster_index, @cluster_members) = split /\s+/,$cluster;
  print STDERR "Loading cluster $cluster_index...";

  unless (defined $max_cluster_index) {
    $max_cluster_index = $cluster_index;
  } elsif ($cluster_index > $max_cluster_index) {
    $max_cluster_index = $cluster_index;
  }

  my $Family = new  Bio::EnsEMBL::ExternalData::Family::Family;
  my $family_stable_id = sprintf ("$family_prefix%011.0d",$cluster_index + $family_offset);
  $Family->stable_id($family_stable_id);
  $Family->release($release_number);
  $Family->description("NULL");
  $Family->annotation_confidence_score(0);

  foreach my $member (@cluster_members) {
    last if ($member =~ /^\$$/);
    my $seqid = $member_index{$member};

    unless($seqid) {
      warn("no seqid defined for member [$member]\n");
      next;
    }

    if(!$seqinfo{$seqid}) {
      warn("no seqinfo defined for [$seqid]\n");
      next;
    }
   
    if(!$seqinfo{$seqid}{'taxon'}) {
      warn("taxon is not defined for seqid [$seqid]");
      if($seqinfo{$seqid}) {
         map {warn( $_ . '=>' . $seqinfo{$seqid}{$_})} keys %{$seqinfo{$seqid}};
      }
      next;
    }

    my $taxon_hash = parse_taxon($seqinfo{$seqid}{'taxon'});
    my @classification = split(':',$taxon_hash->{'taxon_classification'});
    my $taxon = new Bio::EnsEMBL::ExternalData::Family::Taxon->new(-classification=>\@classification);
    $taxon->common_name($taxon_hash->{'taxon_common_name'});
    $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
    $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});

    my $FamilyMember = new Bio::EnsEMBL::ExternalData::Family::FamilyMember;
    $FamilyMember->stable_id($seqid);
    $FamilyMember->database(uc $seqinfo{$seqid}{'type'});
    $FamilyMember->taxon($taxon);
    $FamilyMember->alignment_string("NULL");
    $Family->add_member($FamilyMember);
  }

  my $dbID = $FamilyAdaptor->store($Family);

  foreach my $FamilyMember (@{$Family->get_all_members}) {
    print $FamilyMember->database,"\t$dbID\t",$FamilyMember->stable_id,"\t",$seqinfo{$FamilyMember->stable_id}{'description'},"\n";
    $seqinfo{$FamilyMember->stable_id}{'printed'} = 1;
  }
  print STDERR "Done\n";
}

# taking care here of the protein that did not give any hit in the blastp run
# and therefore were not included in the mcl matrix. So making sure they are stored in the
# family database as singletons.

print STDERR "Loading singleton kept out of clustering because of no blastp hit...";

foreach my $seqid (keys %seqinfo) {
  next if (defined $seqinfo{$seqid}{'printed'});
  $max_cluster_index++;

  print STDERR "Loading singleton $max_cluster_index...";

  my $Family = new  Bio::EnsEMBL::ExternalData::Family::Family;
  my $family_stable_id = sprintf ("$family_prefix%011.0d",$max_cluster_index + $family_offset);
  $Family->stable_id($family_stable_id);
  $Family->release($release_number);
  $Family->description("NULL");
  $Family->annotation_confidence_score(0);

  if(!$seqinfo{$seqid}{'taxon'}) {
    warn("taxon is not defined for seqid [$seqid]");
    if($seqinfo{$seqid}) {
       map {warn( $_ . '=>' . $seqinfo{$seqid}{$_})} keys %{$seqinfo{$seqid}};
    }
    next;
  }

  my $taxon_hash = parse_taxon($seqinfo{$seqid}{'taxon'});
  my @classification = split(':',$taxon_hash->{'taxon_classification'});
  my $taxon = new Bio::EnsEMBL::ExternalData::Family::Taxon(-classification=>\@classification);
  $taxon->common_name($taxon_hash->{'taxon_common_name'});
  $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
  $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});
  
  my $FamilyMember = new Bio::EnsEMBL::ExternalData::Family::FamilyMember;
  $FamilyMember->stable_id($seqid);
  $FamilyMember->database(uc $seqinfo{$seqid}{'type'});
  $FamilyMember->taxon($taxon);
  $FamilyMember->alignment_string("NULL");
  $Family->add_member($FamilyMember);
  
  my $dbID = $FamilyAdaptor->store($Family);

  print $FamilyMember->database,"\t$dbID\t",$FamilyMember->stable_id,"\t",$seqinfo{$FamilyMember->stable_id}{'description'},"\n";
  $seqinfo{$FamilyMember->stable_id}{'printed'} = 1;
  print STDERR "Done\n";
}

sub parse_taxon {
  my ($str) = @_;

  $str=~s/=;/=NULL;/g;
  my %taxon = map {split '=',$_} split';',$str;

  return \%taxon;
}
