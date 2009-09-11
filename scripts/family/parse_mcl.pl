#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Attribute;

$| = 1;

my $usage = "
Usage: $0 options mcl_file dbname [tab_file]

Options:
-prefix <family_stable_id_prefix> (default: ENSF)
-foffset <family_id_numbering_start> (default:1)
-reg_conf <config_file.pl>

\n";

my $help = 0 ;
my $method_link_type = "FAMILY";
my $family_prefix = "ENSF";
my $family_offset = 1;
my $reg_conf;

GetOptions('help'   => \$help,
	   'prefix=s'   => \$family_prefix,
	   'foffset=i'  => \$family_offset,
       'reg_conf=s' => \$reg_conf);

if ($help) {
  print $usage;
  exit 0;
}

unless (scalar @ARGV >= 2) {
  print "Need at least 2 arguments\n";
  print $usage;
  exit 0;
}

my ($mcl_file, $dbname, $tab_file) = @ARGV;

# Take values from ENSEMBL_REGISTRY environment variable or from ~/.ensembl_init
# if no reg_conf file is given.
Bio::EnsEMBL::Registry->load_all($reg_conf);


my @clusters;

my $dbc   = Bio::EnsEMBL::Registry->get_DBAdaptor($dbname,'compara')->dbc;
my $fa    = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','Family');
my $ma    = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','Member');
my $gdba  = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','GenomeDB');
my $mlssa = Bio::EnsEMBL::Registry->get_adaptor($dbname,'compara','MethodLinkSpeciesSet');


my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
$mlss->species_set(\@{$gdba->fetch_all});
$mlss->method_link_type($method_link_type);
$mlssa->store($mlss);

my %tab_index2stable_id = ();
if($tab_file) {
    print STDERR "Reading tab file...";
    open TAB, $tab_file || die "$tab_file: $!";

    while (<TAB>) {
      if (/^(\S+)\s+(\S+)/) {
        my ($index,$member_stable_id) = ($1,$2);
        $tab_index2stable_id{$index} = $member_stable_id;
      } else {
        warn "$tab_file has not the expected format\nEXIT 1\n";
        exit 1;
      }
    }
    close TAB || die "$tab_file: $!";
    print STDERR "Done\n";
}



print STDERR "Getting source_name from database...";

my $sql = "select stable_id,source_name,description from member where source_name in ('Uniprot/SWISSPROT','Uniprot/SPTREMBL','ENSEMBLPEP','EXTERNALPEP')";
my $sth = $dbc->prepare($sql);
$sth->execute;

my ($member_stable_id,$source_name,$description);

$sth->bind_columns(\$member_stable_id,\$source_name,\$description);

my %stable_id2source_name = ();
while ($sth->fetch) {
    $description = "" unless (defined $description);
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
if ($mcl_file =~ /\.gz/) {
  open MCL, "gunzip -c $mcl_file|" || die "$mcl_file: $!";
} else {
  open MCL, $mcl_file || die "$mcl_file: $!";
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
close MCL || die "$mcl_file: $!";

print STDERR "Done\n";



print STDERR "Loading clusters in compara\n";

# starting to use the Family API here to load in a family database
# still print out description for each Uniprot/SWISSPROT and Uniprot/SPTREMBL 
# entries in the family in order to determinate a consensus description

foreach my $cluster (@clusters) {
    my ($cluster_index, @cluster_members) = split /\s+/,$cluster;

  my $popped = pop @cluster_members;
  if ($popped ne "\$") {
    die "problem in the mcl parsing in cluster id $cluster_index\n";
  }

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

    my $member; # going via different routes depending on the availability of $tab_file:

    if($tab_file) {

        my $member_stable_id = $tab_index2stable_id{$tab_idx};
        unless($member_stable_id) {
          warn("no member_stable_id defined for member [$tab_idx]\n");
          next;
        }

        my $member_source =  $stable_id2source_name{$member_stable_id};
        unless($member_source) {
          warn("no stable_id2source_name defined for [$member_stable_id]\n");
          next;
        }

        $member = $ma->fetch_by_source_stable_id($member_source, $member_stable_id);
        unless($member) {
          die "member does not exist in the database";
        }
    } else {
        ($member) = @{ $ma->fetch_all_by_sequence_id($tab_idx) };
        unless($member) {
            warn "Could not fetch member by sequence_id=$tab_idx";
        }
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

