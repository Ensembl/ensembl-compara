#!/usr/local/ensembl/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::Slice;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Taxon;

$| = 1;

my $usage = "
Usage: $0 options redundant_ids_file description_file fasta_file

Options:
-host 
-dbname
-dbuser
-dbpass
-conf_file

\n";


my $help = 0;
my $host;
my $port = "";
my $dbname;
my $dbuser;
my $dbpass;
my $conf_file;

GetOptions('help' => \$help,
	   'host=s' => \$host,
	   'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file);

my ($redunfile, $desc_file, $fasta_file) = @ARGV;

if ($help) {
  print $usage;
  exit 0;
}

# get the redundant ids
if ($redunfile =~ /\.gz/) {
  open REDUN, "gunzip -c $redunfile|" ||
    die "$redunfile: $!";
} else {
  open REDUN, $redunfile ||
    die "$redunfile: $!";
}

my %redun_hash;

while (<REDUN>) {
  chomp;
  my @tab = split;
  my $refid = shift @tab;
  foreach my $id (@tab) {
    next if ($id eq $refid);
    $redun_hash{$id} = $refid;
  }
}

close REDUN;

# get id's type, description and taxon
if ($desc_file =~ /\.gz/) {
  open DESC, "gunzip -c $desc_file|" || 
    die "$desc_file: $!"; 
} else {
  open DESC, $desc_file ||
    die "$desc_file: $!";
}

my %seqinfo;

while (<DESC>) {
  if (/^(.*)\t(.*)\t(.*)\t(.*)$/) {
    my ($type,$seqid,$desc,$taxon) = ($1,$2,$3,$4);
    if(!$taxon || !$seqid) {
      warn("taxon or seqid not defined, skipping description:\n".
           "\t[$type]\t[$seqid]\t\[$desc]\t[$taxon]\n");
      next;
    }
    $desc = "" unless (defined $desc);
    $seqinfo{$seqid}{'type'} = $type;
    $seqinfo{$seqid}{'description'} = $desc;
    $seqinfo{$seqid}{'taxon'} = $taxon;
  } else {
    warn "$desc_file has not the expected format
EXIT 2\n";
    exit 2;
  }
}

close DESC
  || die "$desc_file: $!";


my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname,
                                                     -conf_file => $conf_file);

my $genome_dbs = $db->get_GenomeDBAdaptor->fetch_all;
my %genome_db;
foreach my $gdb (@{$genome_dbs}) {
  $genome_db{$gdb->taxon_id} = $gdb;
}

my $fa = $db->get_FamilyAdaptor;
my $ma = $db->get_MemberAdaptor;
my $aa = $db->get_AttributeAdaptor;

my $FH = IO::File->new();
$FH->open($fasta_file) || die "Could not open alignment file [$fasta_file], $!\n;";

my $member_stable_id;
my $member_seq;

while (<$FH>) {
  if (/^>(\S+)\s*.*$/) {
    my $new_id = $1;
    if (defined $member_stable_id && defined $member_seq) {
      my $refid = $redun_hash{$member_stable_id};
      die "No refid for $member_stable_id\n" unless (defined $refid);

      my $refid_source = uc($seqinfo{$refid}{'type'});
      my $refid_member = $ma->fetch_by_source_stable_id($refid_source, $refid);
      die "No member for $refid_source $refid\n" unless (defined $refid_member);
      
      my $family = $fa->fetch_by_Member($refid_member)->[0];
      die "No family for $refid_source $refid\n" unless (defined $family);
      my $refid_attribute = $aa->fetch_by_Member_Relation($refid_member,$family)->[0];

      my $source = uc($seqinfo{$member_stable_id}{'type'});
      my $member = $ma->fetch_by_source_stable_id($source, $member_stable_id);
      unless (defined $member) {

        my $taxon_hash = parse_taxon($seqinfo{$member_stable_id}{'taxon'});
        my @classification = split(':',$taxon_hash->{'taxon_classification'});
        my $taxon = new Bio::EnsEMBL::Compara::Taxon->new(-classification=>\@classification);
        $taxon->common_name($taxon_hash->{'taxon_common_name'});
        $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
        $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});
        
        $member = Bio::EnsEMBL::Compara::Member->new_fast
          ({'_stable_id' => $member_stable_id,
            '_taxon_id' => $taxon->ncbi_taxid,
            '_taxon' => $taxon,
            '_description' => $seqinfo{$member_stable_id}{'description'},
            '_source_name' => uc $seqinfo{$member_stable_id}{'type'},
            '_genome_db_id' => "NULL",
            '_chr_name' => "NULL",
            '_chr_start' => "NULL",
            '_chr_end' => "NULL",
            '_sequence' => $member_seq});
        
        if ($member->source_name eq "ENSEMBLPEP") {
          #get genome_db_id
          my $genomedb = $genome_db{$member->taxon_id};
          $member->genome_db_id($genomedb->dbID);
          #get chr_name, chr_start, chr_end
          my $core_db = $genomedb->connect_to_genome_locator();
          my $TranscriptAdaptor = $core_db->get_TranscriptAdaptor;
          my $gene;
          my $transcript;
          
          my $empty_slice = new Bio::EnsEMBL::Slice(-empty => 1,
                                                    -adaptor => $core_db->get_SliceAdaptor());
          
          $transcript = $TranscriptAdaptor->fetch_by_translation_stable_id($member->stable_id);
          my %ex_hash;
          foreach my $exon (@{$transcript->get_all_Exons}) {
            $ex_hash{$exon} = $exon->transform($empty_slice);
          }
          $transcript->transform(\%ex_hash);
          $member->chr_name($transcript->get_all_Exons->[0]->contig->chr_name);
          $member->chr_start($transcript->coding_region_start);
          $member->chr_end($transcript->coding_region_end);
          $member->sequence($transcript->translate->seq); 
        }
      } 
      my $attribute = $aa->fetch_by_Member_Relation($member,$family)->[0];
      if (defined $attribute) {
        if ($attribute->cigar_line =~ /^[\dMD]+$/) {
          print STDERR "$source, $member_stable_id family attribute already loaded\n";
        } else {
          $attribute->cigar_line($refid_attribute->cigar_line);
          $fa->update_relation([ $member,$attribute ]);
          print STDERR "$source, $member_stable_id family attribute updated\n";
        }
      } else {
        $attribute = new Bio::EnsEMBL::Compara::Attribute;
        $attribute->cigar_line($refid_attribute->cigar_line);
        $fa->store_relation([ $member,$attribute ],$family);
        print STDERR "$source, $member_stable_id loaded\n";
      }
    }
    $member_stable_id = $new_id;
    undef $member_seq;
  } elsif (/^[a-zA-Z\*]+$/) { ####### add * for protein with stop in it!!!!
    chomp;
    $member_seq .= $_;
  }
}

$FH->close;

if (defined $member_stable_id && defined $member_seq) {
  my $refid = $redun_hash{$member_stable_id};
  die "No refid for $member_stable_id\n" unless (defined $refid);
  
  my $refid_source = uc($seqinfo{$refid}{'type'});
  my $refid_member = $ma->fetch_by_source_stable_id($refid_source, $refid);
  die "No member for $refid_source $refid\n" unless (defined $refid_member);
  
  my $family = $fa->fetch_by_Member($refid_member)->[0];
  die "No family for $refid_source $refid_source $refid\n" unless (defined $family);
  my $refid_attribute = $aa->fetch_by_Member_Relation($refid_member,$family)->[0];
  
  my $source = uc($seqinfo{$member_stable_id}{'type'});
  my $member = $ma->fetch_by_source_stable_id($source, $member_stable_id);
  unless (defined $member) {
    
    my $taxon_hash = parse_taxon($seqinfo{$member_stable_id}{'taxon'});
    my @classification = split(':',$taxon_hash->{'taxon_classification'});
    my $taxon = new Bio::EnsEMBL::Compara::Taxon->new(-classification=>\@classification);
    $taxon->common_name($taxon_hash->{'taxon_common_name'});
    $taxon->sub_species($taxon_hash->{'taxon_sub_species'});
    $taxon->ncbi_taxid($taxon_hash->{'taxon_id'});
    
    $member = Bio::EnsEMBL::Compara::Member->new_fast
      ({'_stable_id' => $member_stable_id,
        '_taxon_id' => $taxon->ncbi_taxid,
        '_taxon' => $taxon,
        '_description' => $seqinfo{$member_stable_id}{'description'},
        '_source_name' => uc $seqinfo{$member_stable_id}{'type'},
        '_genome_db_id' => "NULL",
        '_chr_name' => "NULL",
        '_chr_start' => "NULL",
        '_chr_end' => "NULL",
        '_sequence' => $member_seq});
        
    if ($member->source_name eq "ENSEMBLPEP") {
      #get genome_db_id
      my $genomedb = $genome_db{$member->taxon_id};
      $member->genome_db_id($genomedb->dbID);
      #get chr_name, chr_start, chr_end
      my $core_db = $genomedb->connect_to_genome_locator();
      my $TranscriptAdaptor = $core_db->get_TranscriptAdaptor;
      my $gene;
      my $transcript;
      
      my $empty_slice = new Bio::EnsEMBL::Slice(-empty => 1,
                                                -adaptor => $core_db->get_SliceAdaptor());
      
      $transcript = $TranscriptAdaptor->fetch_by_translation_stable_id($member->stable_id);
      my %ex_hash;
      foreach my $exon (@{$transcript->get_all_Exons}) {
        $ex_hash{$exon} = $exon->transform($empty_slice);
      }
          $transcript->transform(\%ex_hash);
      $member->chr_name($transcript->get_all_Exons->[0]->contig->chr_name);
      $member->chr_start($transcript->coding_region_start);
      $member->chr_end($transcript->coding_region_end);
      $member->sequence($transcript->translate->seq); 
    }
  } 
  my $attribute = new Bio::EnsEMBL::Compara::Attribute;
  $attribute->cigar_line($refid_attribute->cigar_line);
#  print STDERR $member," ",$attribute,"\n";
  $fa->store_relation([ $member,$attribute ],$family);
  print STDERR "$source, $member_stable_id loaded\n";
}

sub parse_taxon {
  my ($str) = @_;

  $str=~s/=;/=NULL;/g;
  my %taxon = map {split '=',$_} split';',$str;

  return \%taxon;
}
