#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Attribute;

$| = 1;

my $usage = "
Usage: $0 options tab_file mcl_file

i.e.

$0 

Options:
-dbname family dbname
-prefix family stable id prefix (default: ENSF)
-offset family id numbering start (default:1)

\n";

my $help = 0 ;
my $method_link_type = "FAMILY";
my $family_prefix = "ENSF";
my $family_offset = 1;
my $dbname;
my $reg_conf;

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
	   'prefix=s' => \$family_prefix,
	   'offset=i' => \$family_offset,
           'reg_conf=s' => \$reg_conf);

if ($help) {
  print $usage;
  exit 0;
}

unless (scalar @ARGV == 2) {
  print "Need 2 arguments\n";
  print $usage;
  exit 0;
}

my ($tab_file, $mcl_file) = @ARGV;

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);


my @clusters;
my %stable_id2source_name;
my %tab_index2stable_id;
my %redundant_sequence_id2stable_ids;

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname,'compara')->dbc;
my $fa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','Family');
my $ma = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','Member');
my $gdba = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomeDB');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MethodLinkSpeciesSet');


my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
$mlss->species_set(\@{$gdba->fetch_all});
$mlss->method_link_type($method_link_type);
$mlssa->store($mlss);

print STDERR "Reading tab file...";

open TAB, $tab_file ||
  die "$tab_file: $!";

while (<TAB>) {
  if (/^(\S+)\s+(\S+)/) {
    my ($index,$stable_id) = ($1,$2);
    $tab_index2stable_id{$index} = $stable_id;
  } else {
    warn "$tab_file has not the expected format
EXIT 1\n";
    exit 1;
  }
}
close TAB
  || die "$tab_file: $!";

print STDERR "Done\n";

print STDERR "Getting source_name from database...";

my $sql = "select stable_id,source_name,description from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP','EXTERNALPEP')";
my $sth = $dbc->prepare($sql);
$sth->execute;

my ($stable_id,$source_name,$description);

$sth->bind_columns(\$stable_id,\$source_name,\$description);

while ($sth->fetch) {
    $description = "" unless (defined $description);
    $stable_id2source_name{$stable_id} = $source_name;
}

$sth->finish;

#foreach my $stable_id (keys %stable_id2source_name) {
#  print $stable_id," ";
#  print join(" ", $stable_id2source_name{$stable_id}),"\n";
#}

print STDERR "Done\n";

print STDERR "Getting redundancy information from the database...";

$sql = "select sequence_id,count(*) as count from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP','EXTERNALPEP') group by sequence_id having count>1";
$sth = $dbc->prepare($sql);
$sth->execute;

my ($sequence_id,$count);
$sth->bind_columns(\$sequence_id,\$count);

my $sql2 = "select stable_id from member where sequence_id = ?";
my $sth2 = $dbc->prepare($sql2);

while ( $sth->fetch() ) {
  $sth2->execute($sequence_id);
  my ($stable_id);
  $sth2->bind_columns(\$stable_id);
  while ( $sth2->fetch() ) {
    push @{$redundant_sequence_id2stable_ids{$sequence_id}},$stable_id;
  }
}

$sth2->finish;
$sth->finish;

#foreach my $sequence_id (keys %redundant_sequence_id2stable_ids) {
#  print $sequence_id," ";
#  print join(" ", @{$redundant_sequence_id2stable_ids{$sequence_id}}),"\n";
#}

print STDERR "Done\n";


print STDERR "Reading mcl file...";
if ($mcl_file =~ /\.gz/) {
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

print STDERR "Loading clusters in compara\n";

# starting to use the Family API here to load in a family database
# still print out description for each Uniprot/SWISSPROT and Uniprot/SPTREMBL 
# entries in the family in order to determinate a consensus description

foreach my $cluster (@clusters) {
  my ($cluster_index, @cluster_members) = split /\s+/,$cluster;

  my $popped = pop @cluster_members;
  if ($popped ne "\$") {
    die "problem in the mcl parsing in clustar id $cluster_index\n";
  }

  print STDERR "Loading cluster $cluster_index...";

  my $stable_id = sprintf ("$family_prefix%011.0d",$cluster_index + $family_offset);
  my $family = Bio::EnsEMBL::Compara::Family->new_fast
    ({
      '_stable_id' => $stable_id,
      '_version'   => 1,
      '_method_link_species_set' => $mlss,
      '_description_score' => 0
     });
  
  foreach my $tab_idx (@cluster_members) {
    my $seqid = $tab_index2stable_id{$tab_idx};

    unless($seqid) {
      warn("no seqid defined for member [$tab_idx]\n");
      next;
    }

    if(!$stable_id2source_name{$seqid}) {
      warn("no stable_id2source_name defined for [$seqid]\n");
      next;
    }

    my $member_source =  $stable_id2source_name{$seqid};
    my $member = $ma->fetch_by_source_stable_id($member_source, $seqid);
    unless($member) {
      die "member does not exist in the database";
    }
    
    my $attribute = new Bio::EnsEMBL::Compara::Attribute;

    $family->add_Member_Attribute([$member, $attribute]);
  }

  my $dbID = $fa->store($family);
#  my $dbID = 1;

  foreach my $member_attribute (@{$family->get_all_Member_Attribute}) {
    my ($member,$attribute) = @{$member_attribute};
    if ($member->source_name eq 'Uniprot/SWISSPROT' 
        || $member->source_name eq 'Uniprot/SPTREMBL' 
        || $member->source_name eq 'EXTERNALPEP') {
      print $member->source_name,"\t$dbID\t",$member->stable_id,"\t",$member->description,"\n";
    }

    if (defined $redundant_sequence_id2stable_ids{$member->sequence_id}) {
      foreach my $stable_id (@{$redundant_sequence_id2stable_ids{$member->sequence_id}}) {
        next if ($stable_id eq $member->stable_id);
        next unless ($stable_id2source_name{$stable_id} eq 'Uniprot/SWISSPROT' 
                     || $stable_id2source_name{$stable_id} eq 'Uniprot/SPTREMBL' 
                     || $stable_id2source_name{$stable_id} eq 'EXTERNALPEP');
        my $rd_member = $ma->fetch_by_source_stable_id($stable_id2source_name{$stable_id}, $stable_id);
        print $rd_member->source_name,"\t$dbID\t",$rd_member->stable_id,"\t",$rd_member->description,"\n";
      }
    } 
  }

  print STDERR "Done\n";
#  last;
}

print STDERR "END\n";

