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
use Bio::EnsEMBL::Hive::URLFactory;

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

$self->{'compara_ref_hash'}    = {};
$self->{'compara_ref_missing'} = {};
$self->{'compara_new_hash'} = {};
$self->{'conversion_hash'} = {};
$self->{'allTypes'} = {};

$self->{'refDups'} = 0;
$self->{'newDups'} = 0;

my $help;
my $sameBRH=0;
my $sameRHS=0;
my $BRH2BRH=0;  #changed BRH sub type (eg BRH to BRH_MULTI)
my $BRH2RHS=0;
my $RHS2BRH=0;
my $countAdds=0;
my $ref_homology_count=0;
my $new_homology_count=0;
my $BRHCount=0;
my $RHSCount=0;
my $newBRH=0;
my $newRHS=0;
my $url     = undef;
my $url_ref = undef;

GetOptions('help'     => \$help,
           'url1=s'   => \$url_ref,
           'url2=s'   => \$url,
           'gdb1=i'   => \$self->{'genome_db_id_1'},
           'gdb2=i'   => \$self->{'genome_db_id_2'},
          );

if ($help) { usage(); }

unless($url and $url_ref) {
  print "\nERROR : must specify url for 2 compara databases\n\n";
  usage();
}

$self->{'comparaDBA'}    = Bio::EnsEMBL::Hive::URLFactory->fetch($url, 'compara');
$self->{'refComparaDBA'} = Bio::EnsEMBL::Hive::URLFactory->fetch($url_ref, 'compara');

unless($self->{'comparaDBA'} and $self->{'refComparaDBA'} and
       $self->{'comparaDBA'}->isa('Bio::EnsEMBL::Compara::DBSQL::DBAdaptor') and
       $self->{'refComparaDBA'}->isa('Bio::EnsEMBL::Compara::DBSQL::DBAdaptor'))
{
  print "\nERROR : must specify must specify url for 2 compara databases\n\n";
  usage();
}

loadReferenceCompara($self);

compareComparas($self);

print("reference_compara\n  $ref_homology_count total homologies\n");
print("  ", $self->{'refDups'}, " duplicate homologies for cleanup\n");

print("new compara\n  $new_homology_count total homologies\n");
print("  ", $self->{'newDups'}, " duplicate homologies for cleanup\n");

print("differences\n");
printf("%6.1f%% same BRH ($sameBRH/$BRHCount)\n", scalar($sameBRH/$BRHCount*100.0)) if($BRHCount>0);
printf("%6.1f%% same RHS ($sameRHS/$RHSCount)\n", scalar($sameRHS/$RHSCount*100.0)) if($RHSCount>0);
printf("%7d switched BRH subtype\n", $BRH2BRH);
printf("%7d converted BRH -> RHS\n", $BRH2RHS);
printf("%7d converted RHS -> BRH\n", $RHS2BRH);
printf("%7d new BRH Homologies\n", $newBRH);
printf("%7d new RHS Homologies\n", $newRHS);

print_conversion_stats($self);
print_missing_stats($self);

exit(0);


#######################
#
# subroutines
#
#######################

sub usage {
  print "homology_diff.pl [options]\n";
  print "  -help                  : print this help\n";
  print "  -url1 <str>            : url of reference compara DB\n";
  print "  -url2 <str>            : url of compara DB \n";
  print "  -gdb1 <int>            : genome_db_id of first genome\n";
  print "  -gdb2 <int>            : genome_db_id of second genome\n";
  print "homology_diff.pl v1.1\n";

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
  my $sth = $self->{'refComparaDBA'}->dbc->prepare( $sql );
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
    $self->{'allTypes'}->{$type} = $type;

    $self->{'conversion_hash'}->{$type} = {'total'=>0} unless($self->{'conversion_hash'}->{$type});
    my $count = $self->{'conversion_hash'}->{$type}->{'total'};
    $self->{'conversion_hash'}->{$type}->{'total'} = $count+1;
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
  my $sth = $self->{'comparaDBA'}->dbc->prepare( $sql );
  $sth->execute();
  my ($gene_id1, $gene_id2, $new_type, $homology_id);
  $sth->bind_columns(\$gene_id1, \$gene_id2, \$new_type, \$homology_id );
  while($sth->fetch()) {
    my $key = $gene_id1 ."_". $gene_id2;
    my $ref_type = $self->{'compara_ref_hash'}->{$key};

    if($self->{'compara_new_hash'}->{$key}) {
      $self->{'newDups'}++;
      print("new_compara duplicate '$key' as $new_type and ",
            $self->{'compara_new_hash'}->{$key},
            "\n");
    }
    $self->{'compara_new_hash'}->{$key} = $new_type;

    $self->{'allTypes'}->{$new_type} = $new_type;

    #my $count = $self->{'allTypes'}->{$new_type};
    #$count=0 unless($count);
    #$self->{'allTypes'}->{$new_type} = $count+1;


    #print("check compara21 key='$key' '$new_type' vs '$type20'\n");
    $new_homology_count++;
    #$BRHCount++ if($new_type eq 'BRH');
    #$RHSCount++ if($new_type eq 'RHS');
    if($ref_type) {
      #print("check compara21 key='$key' '$new_type' vs '$type20'\n");
      $sameBRH++ if(($ref_type =~ /^BRH/) and ($ref_type eq $new_type));
      $sameRHS++ if(($ref_type =~ /^RHS/) and ($ref_type eq $new_type));

      my $count = $self->{'conversion_hash'}->{$ref_type}->{$new_type};
      $count=0 unless($count);
      $self->{'conversion_hash'}->{$ref_type}->{$new_type} = $count+1;
      
      $BRH2BRH++ if(($ref_type =~ /^BRH/) and ($new_type =~ /^BRH/) and ($ref_type ne $new_type));
      $BRH2RHS++ if(($ref_type =~ /^BRH/) and ($new_type eq 'RHS'));
      $RHS2BRH++ if(($ref_type eq 'RHS') and ($new_type =~ /^BRH/));

      delete $self->{'compara_ref_missing'}->{$key};
    }
    else {
      $newBRH++ if($new_type =~ /^BRH/);
      $newRHS++ if($new_type =~ /^RHS/);
    }
  }
}


sub print_conversion_stats
{
  my $self = shift;
  my %typeCount;
  my @allTypes = sort(keys(%{$self->{'allTypes'}}));

  printf("%10s ", "old/new");
  foreach my $new_type (@allTypes) {
    printf("%10s ", $new_type);
  }
  printf("%10s\n",'old_total');
  
  foreach my $ref_type (@allTypes) {
    my $convHash = $self->{'conversion_hash'}->{$ref_type};
    printf("%10s ", $ref_type);
    foreach my $new_type (@allTypes) {
      my $count = $self->{'conversion_hash'}->{$ref_type}->{$new_type};
      $count=0 unless($count);
      printf("%10d ", $count);
    }
    my $count = $self->{'conversion_hash'}->{$ref_type}->{'total'};
    $count=0 unless($count);
    printf("%10d\n", $count);
  }
}


sub print_missing_stats
{
  my $self = shift;
  my %typeCount;

  print(scalar(keys(%{$self->{'compara_ref_missing'}})) . " lost homologies\n");

  foreach my $key (keys(%{$self->{'compara_ref_missing'}})) {
    my $type = $self->{'compara_ref_missing'}->{$key};
    my $count = $typeCount{$type};
    $count=0 unless($count);
    $typeCount{$type} = $count+1;
    #print("  $key => " . $self->{'compara_ref_missing'}->{$key} . "\n");
  }
  
  foreach my $type (keys(%typeCount)) {
    print("  $type ", $typeCount{$type}, "\n");
  }

      
}

