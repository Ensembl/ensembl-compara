#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::Seq;
use Bio::SeqIO;

my $host;
my $port;
my $dbname;
my $dbuser = "ensro";
my $dbpass;
my $conf_file;
my $homology_id;
my $upstream_length = 5000;
my $taxon_id;

GetOptions('host=s' => \$host,
           'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file,
           'upstream_length=i' => \$upstream_length,
           'taxon_id=i' => \$taxon_id);


my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname,
                                                     -conf_file => $conf_file);

my $ma = $db->get_MemberAdaptor;
my $ha = $db->get_HomologyAdaptor;



my $members = $ma->fetch_by_source_taxon('ENSEMBLGENE',$taxon_id);

foreach my $member (@{$members}) {
  
  my $ga = $member->genome_db->db_adaptor->get_GeneAdaptor;
  my $gene = $ga->fetch_by_stable_id($member->stable_id);
  $gene->transform('toplevel');
  my $sa = $member->genome_db->db_adaptor->get_SliceAdaptor;
  my $slice;
  if ($gene->strand > 0) {
    $slice = $sa->fetch_by_region('toplevel',$gene->slice->seq_region_name,$gene->seq_region_start-$upstream_length,$gene->seq_region_start-1);
  } else {
    $slice = $sa->fetch_by_region('toplevel',$gene->slice->seq_region_name,$gene->seq_region_end+1, $gene->seq_region_end+$upstream_length,-1);
  }
    
  my $seq = $slice->get_repeatmasked_seq->seq;

  foreach my $exon (@{$slice->get_all_Exons}) {
    my $length = $exon->end-$exon->start+1;
    my $padstr = 'N' x $length;
    substr ($seq,$exon->start,$length) = $padstr;
  }
  
  my $seqIO = Bio::SeqIO->newFh(-interleaved => 0,
                                -fh => \*STDOUT,
                                -format => "fasta",
                                -idlength => 20);
    
    
  my $bioseq = Bio::Seq->new( -display_id => $gene->stable_id . "_".$upstream_length ."bp_upstream",
                              -seq => $seq);

  print $seqIO $bioseq;
}
