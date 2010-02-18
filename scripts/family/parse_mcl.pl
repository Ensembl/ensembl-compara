#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Attribute;

$| = 1;

sub read_mcl_abc_format {
    my ($mcl_file) = @_;

    my @clusters = ();

    if ($mcl_file =~ /\.gz/) {
      open MCL, "gunzip -c $mcl_file|" || die "$mcl_file: $!";
    } else {
      open MCL, $mcl_file || die "$mcl_file: $!";
    }

    my $cluster_index = 0;

    while (<MCL>) {
        chomp;
        push @clusters, $cluster_index.' '.$_;
        $cluster_index++;
    }
    close MCL || die "$mcl_file: $!";

    return \@clusters;
}

my $usage = "
Usage: $0 options mcl_file

Options:
-prefix <family_stable_id_prefix> (default: ENSF)
-foffset <family_id_numbering_start> (default:1)
-host <host_name>
-port <port_number>
-user <user_name>
-pass <password>
-dbname <database_name>

\n";

my $help                = 0;
my $method_link_type    = "FAMILY";
my $family_prefix       = "ENSF";
my $family_offset       = 1;
my $db_conf             = {};

GetOptions('help'     => \$help,
	   'prefix=s'     => \$family_prefix,
	   'foffset=i'    => \$family_offset,
       'host=s'       => \$db_conf->{'-host'},
       'port=i'       => \$db_conf->{'-port'},
       'user=s'       => \$db_conf->{'-user'},
       'pass=s'       => \$db_conf->{'-pass'},
       'dbname=s'     => \$db_conf->{'-dbname'},
);

if ($help) {
  print $usage;
  exit 0;
}

if (scalar(@ARGV) != 1) {
  print "Expecting 1 argument:\n";
  print $usage;
  exit 0;
}

my ($mcl_file) = @ARGV;

my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(%$db_conf);
my $dbc         = $compara_dba->dbc();

my $fa          = $compara_dba->get_FamilyAdaptor();
my $ma          = $compara_dba->get_MemberAdaptor();
my $gdba        = $compara_dba->get_GenomeDBAdaptor();
my $mlssa       = $compara_dba->get_MethodLinkSpeciesSetAdaptor();

my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
$mlss->species_set(\@{$gdba->fetch_all});
$mlss->method_link_type($method_link_type);
$mlssa->store($mlss);

print STDERR "Getting source_name from database...";

my $sql = "select stable_id,source_name,description from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP','EXTERNALPEP')";
my $sth = $dbc->prepare($sql);
$sth->execute;

my ($member_stable_id,$source_name);

$sth->bind_columns(\$member_stable_id,\$source_name);

my %stable_id2source_name = ();
while ($sth->fetch) {
    $stable_id2source_name{$member_stable_id} = $source_name;
}
$sth->finish;
print STDERR "Done\n";


print STDERR "Getting redundancy information from the database...";

$sql = "select sequence_id,count(*) as count from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP','EXTERNALPEP') group by sequence_id having count>1";
$sth = $dbc->prepare($sql);
$sth->execute;

my ($sequence_id,$count);
$sth->bind_columns(\$sequence_id,\$count);

my $sql2 = "select stable_id from member where sequence_id = ?";
my $sth2 = $dbc->prepare($sql2);

my %redundant_sequence_id2stable_ids = ();
while ( $sth->fetch() ) {
  $sth2->execute($sequence_id);
  my ($member_stable_id);
  $sth2->bind_columns(\$member_stable_id);
  while ( $sth2->fetch() ) {
    push @{$redundant_sequence_id2stable_ids{$sequence_id}},$member_stable_id;
  }
}

$sth2->finish;
$sth->finish;
print STDERR "Done\n";


print STDERR "Reading mcl file...";

my $clusters = read_mcl_abc_format($mcl_file);
print STDERR "Done\n";


print STDERR "Loading clusters in compara\n";

# starting to use the Family API here to load in a family database
# still print out description for each Uniprot/SWISSPROT and Uniprot/SPTREMBL 
# entries in the family in order to determinate a consensus description

foreach my $cluster (@$clusters) {
   my ($cluster_index, @cluster_members) = split /\s+/,$cluster;

  if( (scalar(@cluster_members) == 0)
   or ((scalar(@cluster_members) == 1) and ($cluster_members[0] eq '0'))) {
        print STDERR "Skipping an empty cluster $cluster_index...";
        next;
  }

    print STDERR "Loading cluster $cluster_index...";

   my $family_stable_id = sprintf ("$family_prefix%011.0d",$cluster_index + $family_offset);
   my $family = Bio::EnsEMBL::Compara::Family->new_fast({
      '_stable_id'               => $family_stable_id,
      '_version'                 => 1,
      '_method_link_species_set' => $mlss,
      '_description_score'       => 0,
  });
  
  foreach my $tab_idx (@cluster_members) {

    my ($member) = @{ $ma->fetch_all_by_sequence_id($tab_idx) };
    unless($member) {
        warn "Could not fetch member by sequence_id=$tab_idx";
    }
    
    if($member) {
            # A funny way to add members to a family.
            # You cannot do it without introducing an empty attribute, it seems?
            #
        my $attribute = new Bio::EnsEMBL::Compara::Attribute;
        $family->add_Member_Attribute([$member, $attribute]);
    }
  }

  my $family_dbID = $fa->store($family);

  foreach my $member (@{$family->get_all_Members}) {
    my $member_source = $member->source_name();

    if ($member_source eq 'Uniprot/SWISSPROT' 
        or $member_source eq 'Uniprot/SPTREMBL' 
        or $member_source eq 'EXTERNALPEP') {
            print join("\t", $member_source, $family_dbID, $member->stable_id, $member->description)."\n";
    }

    if (defined $redundant_sequence_id2stable_ids{$member->sequence_id}) {
      foreach my $rmember_stable_id (@{$redundant_sequence_id2stable_ids{$member->sequence_id}}) {
        next if ($rmember_stable_id eq $member->stable_id);
        my $rmember_source = $stable_id2source_name{$rmember_stable_id};

        if($rmember_source eq 'Uniprot/SWISSPROT' 
             or $rmember_source eq 'Uniprot/SPTREMBL' 
             or $rmember_source eq 'EXTERNALPEP') {

                my $rd_member = $ma->fetch_by_source_stable_id($rmember_source, $rmember_stable_id);
                print join("\t", $rmember_source, $family_dbID, $rmember_stable_id, $rd_member->description)."\n";
        }

      }
    } 
  }

  print STDERR "Done\n";
}

print STDERR "END\n";

