#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;

$| = 1;

my $usage = "
$0
  [--help]                    this menu
   --dbname string            (e.g. compara25) one of the compara destination database Bio::EnsEMBL::Registry aliases
  [--reg_conf filepath]       the Bio::EnsEMBL::Registry configuration file. If none given, 
                              the one set in ENSEMBL_REGISTRY will be used if defined, if not
                              ~/.ensembl_init will be used.
\n";

my $help = 0 ;
my $dbname;
my $reg_conf;

GetOptions('help' => \$help,
	   'dbname=s' => \$dbname,
           'reg_conf=s' => \$reg_conf);

if ($help) {
  print $usage;
  exit 0;
}

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);

my %redundant_sequence_id2member_ids;

my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname,'compara')->dbc;

print STDERR "Getting sequence_id vs member_id information from the database...";

my $sql = "select sequence_id,member_id from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP')";
my $sth = $dbc->prepare($sql);
$sth->execute;

my ($sequence_id,$member_id);
$sth->bind_columns(\$sequence_id,\$member_id);

while ( $sth->fetch() ) {
    push @{$redundant_sequence_id2member_ids{$sequence_id}},$member_id;
}

$sth->finish;

print STDERR "Done\n";

print STDERR "Loading redundant peptides in families...";

foreach my $sequence_id (keys %redundant_sequence_id2member_ids) {
  next if (scalar @{$redundant_sequence_id2member_ids{$sequence_id}} == 1);
  my $member_ids = join(",", @{$redundant_sequence_id2member_ids{$sequence_id}});
  my $sql = "select * from family_member where member_id in ($member_ids)";
  my $sth = $dbc->prepare($sql);
  $sth->execute;

  my ($ref_family_id, $ref_member_id, $ref_cigar_line);
  my ($family_id, $member_id, $cigar_line);
  $sth->bind_columns(\$family_id, \$member_id, \$cigar_line);
  
  my $sql2 = "insert ignore into family_member (family_id, member_id, cigar_line) values (?,?,?)";
  my $sth2 = $dbc->prepare($sql2);

  my $number_of_rows = 0;
  while ( $sth->fetch() ) {
    $number_of_rows++;
    $ref_family_id = $family_id;
    $ref_member_id = $member_id;
    $ref_cigar_line = $cigar_line;
  }
  if ($number_of_rows > 1) {
    print STDERR "sequence_id $sequence_id have more than just one ref_member_id\n";
    next;
  }

  foreach my $member_id (@{$redundant_sequence_id2member_ids{$sequence_id}}) {
    next if ($member_id == $ref_member_id);
    $sth2->execute($family_id, $member_id, $cigar_line);
  }

  $sth2->finish;
  $sth->finish;
}

print STDERR "Done\n";

print STDERR "Loading ensembl genes in families...";

$sql = "insert ignore into family_member select fm.family_id,m.gene_member_id,NULL from member m,family_member fm where m.member_id=fm.member_id and m.source_name='ENSEMBLPEP' group by family_id,gene_member_id";

$sth = $dbc->prepare($sql);
$sth->execute;

$sth->finish;

print STDERR "Done";
