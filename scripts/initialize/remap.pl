#!/usr/local/bin/perl -w

use strict;
use Getopt::Long;
use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DnaFrag;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::AlignBlockSet;
use Bio::EnsEMBL::Compara::AlignBlock;
use Bio::EnsEMBL::DnaDnaAlignFeature;

my $host = 'ecs1d.sanger.ac.uk';
my $dbname = 'homo_sapiens_core_4_28';
my $dbuser = 'ensro';
my $dbpass = "";

&GetOptions('h=s' => \$host,
	    'd=s' => \$dbname,
	    'u=s' => \$dbuser);

$| = 1;

my $human_db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $host,
						   -user => $dbuser,
						   -dbname => $dbname);
$host = 'ecs1f.sanger.ac.uk';
$dbname = 'alistair_mouse_si_Nov01';
$dbuser = 'ensro';
$dbpass = "";

my $mouse_db = new Bio::EnsEMBL::DBSQL::DBAdaptor (-host => $host,
						   -user => $dbuser,
						   -dbname => $dbname);

$host = 'ecs1b.sanger.ac.uk';
$dbname = 'abel_test3';
$dbuser = 'ensro';
$dbpass = "";

my $compara_db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host => $host,
							     -dbname => $dbname,
							     -user => $dbuser,
							     -pass => $dbpass);

my $ga = $compara_db->get_GenomicAlignAdaptor();

foreach my $gid ($ga->list_align_ids()) {
#  next if ($gid != 11);
#next if ($gid != 491);
#print $gid,"\n";

my $galn = new Bio::EnsEMBL::Compara::GenomicAlign(-align_id => $gid,
						   -adaptor => $ga);

#print $galn->align_name,"\n";
foreach my $abs ($galn->each_AlignBlockSet) {
  foreach my $ab ($abs->get_AlignBlocks) {
#    next if ($ab->score < 50 ||
#	     $ab->perc_id < 75);
#    print "debut ab\n";
#    print $galn->align_name," ",$ab->align_start," ",$ab->align_end," ",$ab->start," ",$ab->end," ",$ab->strand," ",$ab->score," ",$ab->perc_id," ",$ab->cigar_string,"\n\n";
    my $DnaDnaAlignFeature = $ab->return_DnaDnaAlignFeature($galn->align_name);
#    foreach my $ungapped_feature ($DnaDnaAlignFeature->ungapped_features) {
#      print $ungapped_feature->seqname," ",$ungapped_feature->start," ",$ungapped_feature->end," ",$ungapped_feature->hseqname," ",$ungapped_feature->hstart," ",$ungapped_feature->hend," ",$ungapped_feature->hstrand," ",$ungapped_feature->score," ",$ungapped_feature->percent_id,"\n";
#    }
    
#    print $DnaDnaAlignFeature->start," ",$DnaDnaAlignFeature->end," ",$DnaDnaAlignFeature->strand," ",$DnaDnaAlignFeature->hstart," ",$DnaDnaAlignFeature->hend," ",$DnaDnaAlignFeature->hstrand," ","\n";
    
    my $human_contig = $human_db->get_Contig($DnaDnaAlignFeature->seqname);
#    print  $human_contig->chromosome,":",$human_contig->chr_start," ",$human_contig->chr_end," ",$human_contig->static_golden_start," ",$human_contig->static_golden_end," ",$human_contig->static_golden_ori," ",$human_contig->static_golden_type,"\n";
    my $mouse_contig = $mouse_db->get_Contig($DnaDnaAlignFeature->hseqname);
#    print  $mouse_contig->chromosome,":",$mouse_contig->chr_start," ",$mouse_contig->chr_end," ",$mouse_contig->static_golden_start," ",$mouse_contig->static_golden_end," ",$mouse_contig->static_golden_ori," ",$mouse_contig->static_golden_type,"\n";
#    print "---\n";
    $DnaDnaAlignFeature = $DnaDnaAlignFeature->restrict_between_positions($human_contig->static_golden_start,$human_contig->static_golden_end,'seqname');
    unless (defined $DnaDnaAlignFeature) {
#      print "--->bin\n";
      next;
    }
#    foreach my $ungapped_feature ($DnaDnaAlignFeature->ungapped_features) {
#      print $ungapped_feature->seqname," ",$ungapped_feature->start," ",$ungapped_feature->end," ",$ungapped_feature->hseqname," ",$ungapped_feature->hstart," ",$ungapped_feature->hend," ",$ungapped_feature->hstrand," ",$ungapped_feature->score," ",$ungapped_feature->percent_id,"\n";
#    }
#    print "---\n";
    $DnaDnaAlignFeature = $DnaDnaAlignFeature->restrict_between_positions($mouse_contig->static_golden_start,$mouse_contig->static_golden_end,'hseqname');
    unless (defined $DnaDnaAlignFeature) {
#      print "--->bin\n";
      next;
    }
#    print $DnaDnaAlignFeature->cigar_string,"\n";
    
#    print $DnaDnaAlignFeature->start," ",$DnaDnaAlignFeature->end," ",$DnaDnaAlignFeature->strand," ",$DnaDnaAlignFeature->hstart," ",$DnaDnaAlignFeature->hend," ",$DnaDnaAlignFeature->hstrand," ","\n";

    my ($chr_start,$chr_end,$chr_strand,$chr_hstart,$chr_hend,$chr_hstrand);
    ($chr_start,$chr_strand) = $human_contig->chromosome_position($DnaDnaAlignFeature->start,$DnaDnaAlignFeature->strand);
    ($chr_end,$chr_strand) = $human_contig->chromosome_position($DnaDnaAlignFeature->end,$DnaDnaAlignFeature->strand);
    ($chr_hstart,$chr_hstrand) = $mouse_contig->chromosome_position($DnaDnaAlignFeature->hstart,$DnaDnaAlignFeature->hstrand);
    ($chr_hend,$chr_hstrand) = $mouse_contig->chromosome_position($DnaDnaAlignFeature->hend,$DnaDnaAlignFeature->hstrand);

    print $human_contig->chromosome," ",$chr_start," ",$chr_end," ",$chr_strand," ",$mouse_contig->chromosome," ",$chr_hstart," ",$chr_hend," ",$chr_hstrand," ",$DnaDnaAlignFeature->score," ",$DnaDnaAlignFeature->percent_id,"\n";

#    foreach my $ungapped_feature ($DnaDnaAlignFeature->ungapped_features) {
#      print $ungapped_feature->seqname," ",$ungapped_feature->start," ",$ungapped_feature->end," ",$ungapped_feature->hseqname," ",$ungapped_feature->hstart," ",$ungapped_feature->hend," ",$ungapped_feature->hstrand," ",$ungapped_feature->score," ",$ungapped_feature->percent_id,"\n";
#    }
 #   last;
#    print "---\n";
  }
#  last;
}

#exit;
  
}
