#!/usr/local/ensembl/bin/perl -w

use strict;
use Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::Family;
use Bio::EnsEMBL::Compara::Member;
use Bio::EnsEMBL::Compara::Attribute;
use Bio::EnsEMBL::Compara::Taxon;

my $family_db = new Bio::EnsEMBL::ExternalData::Family::DBSQL::DBAdaptor
  (-host => "ecs2d",
   -user => "ensro",
   -dbname => "ensembl_family_16_1",
   -conf_file => "/nfs/acari/abel/src/ensembl_main/compara-family-merge/modules/Bio/EnsEMBL/Compara/Compara.conf");

my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor
  (-host => "ecs2e",
   -user => "ensadmin",
   -pass => "ensembl",
   -dbname => "ensembl_compara_new_schema",
   -conf_file => "/nfs/acari/abel/src/ensembl_main/compara-family-merge/modules/Bio/EnsEMBL/Compara/Compara.conf");

my $gdb = $compara_db->get_GenomeDBAdaptor;
my %genomedbs;
foreach my $genomedb (@{$gdb->fetch_all}) {
  $genomedbs{$genomedb->taxon_id} = $genomedb;
}


my $fa = $family_db->get_FamilyAdaptor;
my $families = $fa->fetch_all;
#my $families = [ $fa->fetch_by_stable_id("ENSF00000001494") ];
my $fma = $family_db->get_FamilyMemberAdaptor;

foreach my $family (@{$families}) { 
  print STDERR "got family: ",$family->stable_id,"\n";

  my $new_family = Bio::EnsEMBL::Compara::Family->new_fast
    ({
      '_stable_id' => $family->stable_id,
      '_source_name' => "ENSEMBL_FAMILY",
      '_description' => $family->description,
      '_description_score' => $family->annotation_confidence_score
     });
  
  print STDERR "getting members\n";
  
  foreach my $member (@{$family->get_all_members}) {
#    print STDERR "Got member: ",$member->stable_id," $member\n";
    my $new_member = new Bio::EnsEMBL::Compara::Member;
    $new_member->stable_id($member->stable_id);
    $new_member->taxon_id($member->taxon_id);
    $new_member->taxon(bless $member->taxon, "Bio::EnsEMBL::Compara::Taxon");
    $new_member->description("NULL");
    $new_member->genome_db_id("NULL");
    $new_member->chr_name("NULL");
    $new_member->chr_start("NULL");
    $new_member->chr_end("NULL");
    $new_member->sequence("NULL");
    
    
    $new_member->source_name($fma->get_dbname_by_external_db_id($member->external_db_id));
    
    if (defined $member->alignment_string) {
      $new_member->sequence($member->peptide_string);
    }
    
    if ($new_member->source_name eq "ENSEMBLPEP" ||
        $new_member->source_name eq "ENSEMBLGENE") {
      #get genome_db_id
      my $genomedb = $genomedbs{$new_member->taxon_id};
      $new_member->genome_db_id($genomedb->dbID);
      #get chr_name, chr_start, chr_end
      my $core_db = $compara_db->get_db_adaptor($genomedb->name, $genomedb->assembly);
      my $GeneAdaptor = $core_db->get_GeneAdaptor;
      my $TranscriptAdaptor = $core_db->get_TranscriptAdaptor;
      my $gene;
      my $transcript;

      my $empty_slice = new Bio::EnsEMBL::Slice(-empty => 1,
                                                -adaptor => $core_db->get_SliceAdaptor());

      if ($new_member->source_name eq "ENSEMBLPEP") {
        $transcript = $TranscriptAdaptor->fetch_by_translation_stable_id($member->stable_id);
        my %ex_hash;
        foreach my $exon (@{$transcript->get_all_Exons}) {
          $ex_hash{$exon} = $exon->transform($empty_slice);
        }
        $transcript->transform(\%ex_hash);
        $new_member->chr_name($transcript->get_all_Exons->[0]->contig->chr_name);
        $new_member->chr_start($transcript->coding_region_start);
        $new_member->chr_end($transcript->coding_region_end);
      } 
      elsif ($new_member->source_name eq "ENSEMBLGENE") {
        $gene = $GeneAdaptor->fetch_by_stable_id($new_member->stable_id);
        
        unless (defined $gene) {
          print STDERR $new_member->stable_id," ",$new_member->source_name," ",$new_member->taxon_id," is undef!!!\n";
          die;
        }
        $gene->transform( $empty_slice );
        $new_member->chr_name($gene->chr_name);
        $new_member->chr_start($gene->start);
        $new_member->chr_end($gene->end);
      }
    }
    

    my $attribute = new Bio::EnsEMBL::Compara::Attribute;
    $attribute->cigar_line("NULL");
    # need to be modified to generate cigarline....
    if (defined $member->alignment_string) {
      my $alignment_string = $member->alignment_string;
      $alignment_string =~ s/\-([A-Z])/\- $1/g;
      $alignment_string =~ s/([A-Z])\-/$1 \-/g;
      my @cigar_segments = split " ",$alignment_string;
      my $cigar_line = "";
      foreach my $segment (@cigar_segments) {
        my $seglength = length($segment);
        $seglength = "" if ($seglength == 1);
        if ($segment =~ /^\-+$/) {
          $cigar_line .= $seglength . "D";
        } else {
          $cigar_line .= $seglength . "M";
        }
      }
      $attribute->cigar_line($cigar_line);
#      $attribute->cigar_line($member->alignment_string);
    }
    
    $new_family->add_Relation([$new_member, $attribute]);
  }
  
  my $cfa = $compara_db->get_FamilyAdaptor;
  $cfa->store($new_family);
  
  next;
  
  foreach my $member_attribute (@{$new_family->get_all_Member}) {
    my ($member, $attribute) = @{$member_attribute};
    if ($member->source_name eq "ENSEMBLPEP") {
      print $member->stable_id," ",$member->source_name," ",$member->chr_name," ",$member->chr_start," ",$member->chr_end," ",$member->taxon_id," ",length($member->sequence)," ",length($attribute->cigar_line),"\n";
    } else {
      print $member->stable_id," ",$member->source_name," ",$member->chr_name," ",$member->chr_start," ",$member->chr_end," ",$member->taxon_id," ",length($member->sequence)," ",length($attribute->cigar_line),"\n";
    }
  }
}
