#!/usr/local/ensembl/bin/perl -w
=head1
  this script does homology dumps generated with this SQL statement from two different
  compara databases and compares them for differences.  

  TODO: make this more general, maybe using DBI to connect to the 2 compara DBs
  and do the dump here.

$sql = "SELECT m1.stable_id, m2.stable_id, h.description" .
       " FROM homology h, homology_member hm1, homology_member hm2, member m1, member m2 ".
       " WHERE h.homology_id=hm1.homology_id AND hm1.member_id=m1.member_id AND m1.genome_db_id=2 ".
       " AND h.homology_id=hm2.homology_id AND hm2.member_id=m2.member_id AND m2.genome_db_id=3 ".
       " ORDER BY  m1.stable_id, m2.stable_id";
=cut

use strict;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Pipeline::Analysis;
use Bio::EnsEMBL::Pipeline::Rule;
use Bio::EnsEMBL::Compara::GenomeDB;
use Bio::EnsEMBL::DBLoader;


# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_conf'} = {};
$self->{'compara_conf'}->{'-user'} = 'ensro';
$self->{'compara_conf'}->{'-port'} = 3306;

$self->{'compara_ref_conf'} = {};
$self->{'compara_ref_conf'}->{'-user'} = 'ensro';
$self->{'compara_ref_conf'}->{'-port'} = 3306;

my $conf_file;
my ($help, $host, $user, $pass, $dbname, $port, $adaptor);
$self->{'compara_ref_hash'}    = {};
$self->{'compara_ref_missing'} = {};
$self->{'compara_ref_dups'} = {};

$self->{'refDups'} = 0;
$self->{'newDups'} = 0;

my $sameBRH=0;
my $sameRHS=0;
my $BRH2RHS=0;
my $RHS2BRH=0;
my $countAdds=0;
my $ref_homology_count=0;
my $new_homology_count=0;
my $BRHCount=0;
my $RHSCount=0;
my $newBRH=0;
my $newRHS=0;

GetOptions('help'     => \$help,
           'conf=s'   => \$conf_file,
           'dbhost=s' => \$host,
           'dbport=i' => \$port,
           'dbuser=s' => \$user,
           'dbpass=s' => \$pass,
           'dbname=s' => \$dbname,
           'gdb1=i'   => \$self->{'genome_db_id_1'},
           'gdb2=i'   => \$self->{'genome_db_id_2'},
          );

if ($help) { usage(); }

parse_conf($self, $conf_file);

if($host)   { $self->{'compara_conf'}->{'-host'}   = $host; }
if($port)   { $self->{'compara_conf'}->{'-port'}   = $port; }
if($dbname) { $self->{'compara_conf'}->{'-dbname'} = $dbname; }
if($user)   { $self->{'compara_conf'}->{'-user'}   = $user; }
if($pass)   { $self->{'compara_conf'}->{'-pass'}   = $pass; }


unless(defined($self->{'compara_conf'}->{'-host'})
       and defined($self->{'compara_conf'}->{'-user'})
       and defined($self->{'compara_conf'}->{'-dbname'}))
{
  print "\nERROR : must specify host, user, and database to connect to compara\n\n";
  usage();
}

$self->{'comparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_conf'}});
$self->{'refComparaDBA'}  = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%{$self->{'compara_ref_conf'}});

loadReferenceCompara($self);

compareComparas($self);

print("reference_compara\n  $ref_homology_count total homologies\n");
print("  ", $self->{'refDups'}, " duplicate homologies for cleanup\n");

print("new compara\n  $new_homology_count total homologies\n");
print("  ", $self->{'newDups'}, " duplicate homologies for cleanup\n");

printf("%1.1f%% same BRH ($sameBRH/$BRHCount)\n", scalar($sameBRH/$BRHCount*100.0)) if($BRHCount>0);
printf("%1.1f%% same RHS ($sameRHS/$RHSCount)\n", scalar($sameRHS/$RHSCount*100.0)) if($RHSCount>0);
print("$BRH2RHS converted BRH20 -> RHS21\n");
print("$RHS2BRH converted RHS20 -> BRH21\n");
print("$newBRH new BRH Homologies\n");
print("$newRHS new RHS Homologies\n");
print(scalar(keys(%{$self->{'compara_ref_missing'}})) . " lost homologies\n");

foreach my $key (keys(%{$self->{'compara_ref_missing'}})) {
  print("  $key => " . $self->{'compara_ref_missing'}->{$key} . "\n");
}
exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "comparaDumpAllPeptides.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -conf <path>           : config file describing compara, templates, and external genome databases\n";
  print "  -dbhost <machine>      : compara mysql database host <machine>\n";
  print "  -dbport <port#>        : compara mysql port number\n";
  print "  -dbname <name>         : compara mysql database <name>\n";
  print "  -dbuser <name>         : compara mysql connection user <name>\n";
  print "  -dbpass <pass>         : compara mysql connection password\n";
  print "  -gdb1 <int>            : genome_db_id of first genome\n";
  print "  -gdb2 <int>            : genome_db_id of second genome\n";
  print "comparaDumpAllPeptides.pl v1.1\n";

  exit(1);
}


sub parse_conf {
  my $self      = shift;
  my $conf_file = shift;

  if($conf_file and (-e $conf_file)) {
    #read configuration file from disk
    my @conf_list = @{do $conf_file};

    foreach my $confPtr (@conf_list) {
      #print("HANDLE type " . $confPtr->{TYPE} . "\n");
      if($confPtr->{TYPE} eq 'COMPARA') {
        $self->{'compara_conf'} = $confPtr;
      }
      if($confPtr->{TYPE} eq 'REF_COMPARA') {
        $self->{'compara_ref_conf'} = $confPtr;
      }
    }
  }
}



sub get_taxon_descriptions {
  my $self = shift;

  $self->{'taxon_hash'} = {};

  my ($taxon_id, $genus, $species, $sub_species, $common_name, $classification);
  my $sql = "SELECT taxon_id, genus, species, sub_species, common_name, classification ".
            " FROM taxon";
  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();
  $sth->bind_columns(\$taxon_id, \$genus, \$species, \$sub_species, \$common_name, \$classification );
  while($sth->fetch()) {
    $classification =~ s/\s+/:/g;
    $sub_species='' if($sub_species eq 'NULL');
    my $taxonDesc = "taxon_id=$taxon_id;".
                    "taxon_genus=$genus;".
                    "taxon_species=$species;".
                    "taxon_sub_species=$sub_species;".
                    "taxon_common_name=$common_name;".
                    "taxon_classification=$classification;";
    $self->{'taxon_hash'}->{$taxon_id} = $taxonDesc;
    print("$taxonDesc\n");
  }
  $sth->finish;
}


sub loadReferenceCompara
{
  my $self = shift;

  print("loadReferenceCompara\n");
  my $sql = "SELECT m1.stable_id, m2.stable_id, h.description" .
            " FROM homology h, homology_member hm1, homology_member hm2, member m1, member m2 ".
            " WHERE h.homology_id=hm1.homology_id AND hm1.member_id=m1.member_id ".
            " AND m1.genome_db_id= ". $self->{'genome_db_id_1'} .
            " AND h.homology_id=hm2.homology_id AND hm2.member_id=m2.member_id ".
            " AND m2.genome_db_id= ". $self->{'genome_db_id_2'};
            #" ORDER BY  m1.stable_id, m2.stable_id";
  my $sth = $self->{'refComparaDBA'}->prepare( $sql );
  $sth->execute();
  my ($gene_id1, $gene_id2, $type);
  $sth->bind_columns(\$gene_id1, \$gene_id2, \$type );
  while($sth->fetch()) {
    my $key = $gene_id1 ."_". $gene_id2;
    #print("storing compara20 key='$key' value='$type20'\n");
    $ref_homology_count++;
    if($self->{'compara_ref_hash'}->{$key}) {
      $self->{'refDups'}++;
      print("ref_compara duplicate '$key' already as ".$self->{'compara_ref_hash'}->{$key}."\n");
    }
    $BRHCount++ if($type eq 'BRH');
    $RHSCount++ if($type eq 'RHS');

    $self->{'compara_ref_hash'}->{$key} = $type;
    $self->{'compara_ref_missing'}->{$key} = $type;
  }
}


sub compareComparas
{
  my $self = shift;

  print("compareComparas\n");

  my $sql = "SELECT m1.stable_id, m2.stable_id, h.description, h.homology_id" .
            " FROM homology h, homology_member hm1, homology_member hm2, member m1, member m2 ".
            " WHERE h.homology_id=hm1.homology_id AND hm1.member_id=m1.member_id ".
            " AND m1.genome_db_id= ". $self->{'genome_db_id_1'} .
            " AND h.homology_id=hm2.homology_id AND hm2.member_id=m2.member_id ".
            " AND m2.genome_db_id= ". $self->{'genome_db_id_2'};
            #" ORDER BY  m1.stable_id, m2.stable_id";
  my $sth = $self->{'comparaDBA'}->prepare( $sql );
  $sth->execute();
  my ($gene_id1, $gene_id2, $type21, $homology_id);
  $sth->bind_columns(\$gene_id1, \$gene_id2, \$type21, \$homology_id );
  while($sth->fetch()) {
    my $key = $gene_id1 ."_". $gene_id2;
    my $ref_type = $self->{'compara_ref_hash'}->{$key};

    if($self->{'compara_ref_dups'}->{$key}) {
      $self->{'newDups'}++;
      print("new_compara duplicate '$key' already as ".$self->{'compara_ref_hash'}->{$key}."\n");
    }
    $self->{'compara_ref_dups'}->{$key} =



    
    #print("check compara21 key='$key' '$type21' vs '$type20'\n");
    $new_homology_count++;
    #$BRHCount++ if($type21 eq 'BRH');
    #$RHSCount++ if($type21 eq 'RHS');
    if($ref_type) {
      #print("check compara21 key='$key' '$type21' vs '$type20'\n");
      $sameBRH++ if(($ref_type eq 'BRH') and ($type21 eq 'BRH'));
      $sameRHS++ if(($ref_type eq 'RHS') and ($type21 eq 'RHS'));
      $BRH2RHS++ if(($ref_type eq 'BRH') and ($type21 eq 'RHS'));
      $RHS2BRH++ if(($ref_type eq 'RHS') and ($type21 eq 'BRH'));

      delete $self->{'compara_ref_missing'}->{$key};
    }
    else {
      $newBRH++ if($type21 eq 'BRH');
      $newRHS++ if($type21 eq 'RHS');
    }
  }
}

