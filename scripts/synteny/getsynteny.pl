#!/usr/local/ensembl/bin/perl

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Analysis;
use Getopt::Long;

my $usage = "
getsynteny.pl  -host ecs1b.sanger.ac.uk 
               -user ensro
               -dbname ensembl_compara_10_1
               -chr_names \"22\"
               -species1 \"Homo sapiens\"
               -assembly1 NCBI30
               -species2 \"Mus musculus\"
               -assembly2 MGSC3
               -conf_file Compara.conf

$0 [-help]
   -host compara_db_host_server
   -user username (default = 'ensro')
   -dbname compara_database_name
   -chr_names \"20,21,22\" (default = \"all\")
   -species1 (e.g. \"Homo sapiens\") from which alignments are queried and chr_names refer to
   -assembly1 (e.g. NCBI30) assembly version of species1
   -species2 (e.g. \"Mus musculus\") to which alignments are queried
   -assembly2 (e.g. MGSC3) assembly version of species2
   -conf_file comparadb_configuration_file
              (see an example in ensembl-compara/modules/Bio/EnsEMBL/Compara/Compara.conf.example)

";

my $help = 0;
my $host = 'ecs2d.internal.sanger.ac.uk';
my $user = 'ensro';
my $pass = '';
my $dbname = 'ensembl_compara_15_1';

my $species1 = 'Homo sapiens';
my $species1_assembly = 'NCBI33';
my $species2 = 'Mus musculus';
my $species2_assembly = 'MGSC3';
my $assembly_type = "WGA";

my $chr_names = "all";
my $conf_file = "./Compara.conf";

$| = 1;

&GetOptions('help' => \$help,
            'host:s' => \$host,
            'user:s' => \$user,
            'dbname:s' => \$dbname,
            'pass:s' => \$pass,
            'species1:s' => \$species1,
            'assembly1:s' => \$species1_assembly,
            'species2:s' => \$species2,
            'assembly2:s' => \$species2_assembly,
            'chr_names=s' => \$chr_names,
            'conf_file=s' => \$conf_file);

if ($help) {
  print $usage;
  exit 0;
}

my $compdb = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (-host        => $host,
                                                          -user        => $user,
                                                          -dbname      => $dbname,
                                                          -pass        => $pass,
                                                          -conf_file   => $conf_file);

my $coredb = $compdb->get_db_adaptor($species1,$species1_assembly);

my $sa = $compdb->get_SyntenyAdaptor;
$species1 =~ s/ /_/;
$species2 =~ s/ /_/;
$sa->setSpecies(undef, $species1, $species2);
my $ca = $coredb->get_ChromosomeAdaptor;

my @chromosomes;

if (defined $chr_names and $chr_names ne "all") {
  my @chr_names = split /,/, $chr_names;
  foreach my $chr_name (@chr_names) {
    push @chromosomes, $ca->fetch_by_chr_name($chr_name);
  }
} else {
  @chromosomes = @{$ca->fetch_all}
}

foreach my $chr (@chromosomes) {
  my $length = $chr->length;

  print STDERR "Got chr ".$chr->chr_name." length $length\n";
  
  my $start = 1;
  my $end = $length;
  
  my $chr_name = $chr->chr_name;
  open SYN,"> $chr_name.dbsyn.gff";
  
  my $synteny = $sa->get_synteny_for_chromosome($chr_name,$start,$end);

  print STDERR "Got features " . scalar(@{$synteny}) . "\n";
    
  foreach my $sr (@{$synteny}) {

    my ($strand,$hstrand) = qw(+ +);

    if ($sr->{rel_ori} < 0) {
      $hstrand = "-";
    }
      
    # print out a in gff format
    print SYN  
        $sr->{chr_name} . "\t" .
        "synteny\t" .
        "similarity\t" .
        $sr->{chr_start} . "\t" .
        $sr->{chr_end} . "\t" .
        "0.0" . "\t" .
        $strand . "\t" .
        ".\t" .
        $sr->{hit_chr_name} . "\t" .
        $sr->{hit_chr_start} . "\t" .
        $sr->{hit_chr_end} . "\t" .
        $hstrand . "\t" .
        ".\n" 
  }
  close SYN;
}
