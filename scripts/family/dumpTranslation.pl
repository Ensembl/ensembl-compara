#!/usr/local/ensembl/bin/perl

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::ExternalData::Family::FamilyConf;

use Getopt::Long;

my $usage = "
$0 [-help]
   -host mysql_host_server
   -user username (default = 'ensro')
   -port port_number
   -dbname ensembl_database
   -path assembly_type (e.g. NCBI33)
   -file fasta_file_name
   -taxon_file taxon_file_name

";

my $host;
my $user = 'ensro';
my $port = "";
my $dbname;
my $file;
my $taxon_file;
my $path;
my $help = 0;

$| = 1;

&GetOptions(
  'help'     => \$help,
  'host=s'   => \$host,
  'port=i' => \$port,
  'user=s'   => \$user,
  'dbname=s' => \$dbname,
  'path=s'   => \$path,
  'file=s' => \$file,
  'taxon_file=s' => \$taxon_file
);

if ($help) {
  print $usage;
  exit 0;
}

my $db = new Bio::EnsEMBL::DBSQL::DBAdaptor(
					    -host   => $host,
					    -user   => $user,
					    -dbname => $dbname,
					    -port => $port
);

$db->assembly_type($path);


my $taxon_id = $db->get_MetaContainer->get_taxonomy_id;
my %TaxonConf = %Bio::EnsEMBL::ExternalData::Family::FamilyConf::TaxonConf;

if (defined $file) {
  open FP,">$file";
} else {
  open FP,">$dbname.pep";
}

if (defined $taxon_file) {
  open TX,">$taxon_file";
} else {
  open TX,">$dbname.tax";
}

my $slice_adaptor = $db->get_SliceAdaptor;
my $gene_adaptor = $db->get_GeneAdaptor;

my @geneIDs = @{$gene_adaptor->list_geneIds()};

foreach my $gid (@geneIDs) {
  my $gene = $gene_adaptor->fetch_by_dbID($gid, 1); #fetch in chromosomal crds

  #pseudogenes have no translations so cannot dump their peptides
  next if(lc($gene->type) eq 'pseudogene'); 

  foreach my $transcript (@{$gene->get_all_Transcripts}) { 
    my $gene_start = $gene->start();
    my $gene_end   = $gene->end();
	
    my $translation = $transcript->translation;
    my $seq = $transcript->translate->seq;

    #if the peptide is all Xs do not dump it
    if ($seq =~ /^X+$/) {
      print STDERR "X+ Translation:" . $translation->stable_id .
        " Transcript:" . $transcript->stable_id .
          " Gene:" . $gene->stable_id . "\n";
      next;
    }
	  
    #use stable ids in the headers if available, otherwise use dbIDs
    if (defined $translation->stable_id) {
      print TX "ensemblpep\t" , $translation->stable_id ,
               "\t\t" .$TaxonConf{$taxon_id} ."\n";
      print FP ">" , $translation->stable_id ," Transcript:" , 
               $transcript->stable_id , " Gene:" . $gene->stable_id;
    } else {
      print TX "ensemblpep\t" , $translation->dbID , "\t\t" ,
               $TaxonConf{$taxon_id} ."\n";
      print FP ">" , $translation->dbID ," Transcript:" . $transcript->dbID ,
          " Gene:" , $gene->dbID; 
    }
    print FP " Chr:" , $gene->chr_name ," Start:", 
             $gene_start , " End:" , $gene_end , "\n";
	  
    $seq =~ s/(.{72})/$1\n/g;
	  
    print FP $seq , "\n";
  }
}
    
close FP;
close TX;
