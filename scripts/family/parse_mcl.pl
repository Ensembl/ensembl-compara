#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Attribute;

$| = 1;

sub read_mcl_abc_format {
    my ($mclfile) = @_;

    my @clusters = ();

    if ($mclfile =~ /\.gz/) {
      open MCL, "gunzip -c $mclfile|" || die "$mclfile: $!";
    } else {
      open MCL, $mclfile || die "$mclfile: $!";
    }

    my $cluster_index = 0;

    while (<MCL>) {
        chomp;
        push @clusters, $cluster_index.' '.$_;
        $cluster_index++;
    }
    close MCL || die "$mclfile: $!";

    return \@clusters;
}

my $usage = "
Usage: $0 options

Options:
-mclfile <mcl_file_name> (obligatory)
-prefix <family_stable_id_prefix> (default: ENSF)
-foffset <family_id_numbering_start> (default:1)
-host <host_name>
-port <port_number>
-user <user_name>
-pass <password>
-database <database_name>

\n";

my $help                = 0;
my $method_link_type    = 'FAMILY';
my $family_prefix       = 'ENSF';
my $family_offset       = 1;
my $db_conf             = {};
my $mclfile             = undef;

GetOptions('help'     => \$help,
       'mclfile=s'    => \$mclfile,
	   'prefix=s'     => \$family_prefix,
	   'foffset=i'    => \$family_offset,
       'host=s'       => \$db_conf->{'-host'},
       'port=i'       => \$db_conf->{'-port'},
       'user=s'       => \$db_conf->{'-user'},
       'pass=s'       => \$db_conf->{'-pass'},
       'database=s'   => \$db_conf->{'-dbname'},
);

if ($help || !($mclfile && $db_conf->{'-host'} && $db_conf->{'-user'} && $db_conf->{'-dbname'}) ) {
  print STDERR $usage;
  exit ($help ? 0 : 1);
}

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


print STDERR "Reading mcl file...";

my $clusters = read_mcl_abc_format($mclfile);

print STDERR "Done\n";


print STDERR "Loading clusters in compara\n";

# starting to use the Family API here to load in a family database

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

  print STDERR "Done\n";
}

print STDERR "END\n";

