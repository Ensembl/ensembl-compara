#!/usr/local/ensembl/bin/perl

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Getopt::Long;

my $usage = "
This script dumps ALL peptide isoforms for each gene present in an ensembl core database.
The output format is FASTA and the header is

>translation_stable_id Transcript:transcript_stable_id Gene:gene_stable_id Chr:1 Start:6706 End:7227

Chr:, Start and End: refers to the gene specifically, e.g.

>ENSP00000317668 Transcript:ENST00000326632 Gene:ENSG00000146556 Chr:1 Start:6706 End:7227

NB1: the core database you are using, must have stable_ids loaded in.

It is also generating a taxon information file with one line per peptide

ensemblpep\ttranslation_stable_id\t\ttaxon_information

e.g.

ensemblpep      ENSP00000317668         taxon_id=9606;taxon_genus=Homo;taxon_species=sapiens;taxon_sub_species=;taxon_common_name=Human;taxon_classification=sapiens:Homo:Hominidae:Catarrhini:Primates:Eutheria:Mammalia:Vertebrata:Chordata:Metazoa:Eukaryota;

NB2: the core database must have the meta table filled with species information.

$0
 --help                            # give this help menu
 --host ecs4                       # MySQL host server
 --user ensro                      # MySQL username (default = ensro)
 --port 3350                       # MySQL port
 --dbname homo_sapiens_core_20_34b # ensembl core database
 --coordinate_system scaffold      # (default = toplevel)
 --file myfilename                 # name for the output FASTA file
 --taxon_file taxon_file_name      # name of the output taxon information file

EXIT STATUS
1 No transcript with longest translation for a particular gene
2 The database does not contain translation stable ids

";

my $host;
my $user = 'ensro';
my $port = "";
my $dbname;
my $file;
my $taxon_file;
my $coordinate_system = "toplevel";
my $help = 0;

$| = 1;

&GetOptions(
  'help'     => \$help,
  'host=s'   => \$host,
  'port=i' => \$port,
  'user=s'   => \$user,
  'dbname=s' => \$dbname,
  'coordinate_system=s' => \$coordinate_system,
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

my $taxon_id = $db->get_MetaContainer->get_taxonomy_id;
my $species = $db->get_MetaContainer->get_Species;
my ($genus_string, $species_string) = split " ", $species->binomial;
my $taxon_info = "taxon_id=$taxon_id;";
$taxon_info .= "taxon_genus=$genus_string;";
$taxon_info .= "taxon_species=$species_string;";
$taxon_info .= "taxon_sub_species=;taxon_common_name=" . $species->common_name . ";";
$taxon_info .= "taxon_classification=" . join(":",$species->classification) .";";

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

my $SliceAdaptor = $db->get_SliceAdaptor;
my $GeneAdaptor = $db->get_GeneAdaptor;

my @slices = @{$SliceAdaptor->fetch_all($coordinate_system)};


foreach my $slice (@slices) {
  foreach my $gene (@{$GeneAdaptor->fetch_all_by_Slice($slice)}) {
    fasta_output($gene, \*FP, \*TX);
  }
}

close TX;
close FP;

sub fasta_output {
  my ($gene, $fh, $tx) = @_;

  return 1 if (lc($gene->type) eq 'pseudogene');

  foreach my $transcript (@{$gene->get_all_Transcripts}) {

    unless (defined $transcript) {
      warn "No transcript with longest translation for gene_id" . $gene->dbID . "
EXIT 1\n";
      exit 1;
    }

    my $translation = $transcript->translation;
    unless (defined $translation->stable_id) {
      warn "$dbname does not contain translation stable id for translation_id ".$translation->dbID."
EXIT 2\n";
      exit 2;
    }
    
    my $seq = $transcript->translate->seq;
    
    if ($seq =~ /^X+$/) {
      warn "X+ in sequence from translation_id " . $translation->dbID."\n";
      next;
    }
    
    $seq =~ s/(.{72})/$1\n/g;
    
    print $fh ">" .     $translation->stable_id .
              " Transcript:" . $transcript->stable_id .
              " Gene:" .       $gene->stable_id .
              " Chr:" .        $gene->seq_region_name .
              " Start:" .      $gene->seq_region_start .
              " End:" .        $gene->seq_region_end .
              "\n" .
              $seq . "\n";
    print $tx "ensemblpep\t" .
              $translation->stable_id .
              "\t\t" .$taxon_info ."\n";
  }
}

exit 0;
