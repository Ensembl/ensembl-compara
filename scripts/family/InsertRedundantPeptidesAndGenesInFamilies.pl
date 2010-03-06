#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

$| = 1;

my $usage = "
$0
  [--help]                    this menu
    -host <host_name>
    -port <port_number>
    -user <user_name>
    -pass <password>
    -database <database_name>
\n";

my $help    = 0;
my $db_conf = {};

GetOptions('help' => \$help,
        'host=s'       => \$db_conf->{'-host'},
        'port=i'       => \$db_conf->{'-port'},
        'user=s'       => \$db_conf->{'-user'},
        'pass=s'       => \$db_conf->{'-pass'},
        'database=s'   => \$db_conf->{'-dbname'},
);

if ($help || !($db_conf->{'-host'} && $db_conf->{'-user'} && $db_conf->{'-dbname'}) ) {
    print $usage;
    exit ($help ? 0 : 1);
}

my %sequence_id2member_id;

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$db_conf);
my $dbc         = $compara_dba->dbc();

print STDERR "Loading sequence_id to member_id mapping from the database...";

my $sql = "select sequence_id,member_id from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP')";
my $sth = $dbc->prepare($sql);
$sth->execute;

my ($sequence_id,$member_id);
$sth->bind_columns(\$sequence_id,\$member_id);

while ( $sth->fetch() ) {
    push @{$sequence_id2member_id{$sequence_id}},$member_id;
}
$sth->finish;
print STDERR "Done\n";


print STDERR "Loading redundant peptides in families...";

foreach my $sequence_id (keys %sequence_id2member_id) {
  next if (scalar @{$sequence_id2member_id{$sequence_id}} == 1);    # skip cases where there is no redundancy (1 member per sequence)
  my $member_ids = join(",", @{$sequence_id2member_id{$sequence_id}});
  my $sql = "select * from family_member where member_id in ($member_ids)";
  my $sth = $dbc->prepare($sql);
  $sth->execute;

  my ($ref_family_id, $ref_member_id, $ref_cigar_line);
  my ($family_id, $member_id, $cigar_line);
  $sth->bind_columns(\$family_id, \$member_id, \$cigar_line);
  
  next unless($family_id); # do not load the sequences that did not undergo clustering for some reason

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

  foreach my $member_id (@{$sequence_id2member_id{$sequence_id}}) {
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

