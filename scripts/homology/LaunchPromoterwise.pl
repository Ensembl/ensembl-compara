#!/usr/local/ensembl/bin/perl -w

use strict;
#use Bio::EnsEMBL::Pipeline::Tools::Promoterwise;
use Bio::EnsEMBL::Pipeline::Runnable::Promoterwise;



use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::AlignIO;
use Bio::Seq;
use Bio::SeqIO;

my $host;
my $port;
my $dbname;
my $dbuser = "ensro";
my $dbpass;
my $conf_file;
my $homology_id;
my $bits_cutoff = 25;
my $pw_options = "-lhreject both";
my $upstream_length = 5000;
my $id_file;

GetOptions('host=s' => \$host,
           'port=i' => \$port,
	   'dbname=s' => \$dbname,
	   'dbuser=s' => \$dbuser,
	   'dbpass=s' => \$dbpass,
	   'conf_file=s' => \$conf_file,
           'upstream_length=i' => \$upstream_length,
           'bits_cutoff=i' => \$bits_cutoff,
           'pw_options=s' => \$pw_options,
           'id_file=s' => \$id_file);


my $db = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(-host   => $host,
                                                     -port   => $port,
                                                     -user   => $dbuser,
                                                     -pass   => $dbpass,
                                                     -dbname => $dbname,
                                                     -conf_file => $conf_file);

my $ma = $db->get_MemberAdaptor;
my $ha = $db->get_HomologyAdaptor;

open DBID, $id_file;

while (<DBID>) {
  my $member_id;
  if (/^(\d+)$/) {
    $member_id = $1;
  } else {
    die "id_file $id_file has wrong format\n";
  }
  
  my $member = $ma->fetch_by_dbID($member_id);
  
  unless (defined $member) {
    print "no member in db\n";
    next;
  }

  my $homologies = $ha->fetch_by_Member($member);
  print "# ",$member->stable_id," ", scalar @{$homologies},"\n";

  foreach my $homology (@{$homologies}) {
    my $query;
    my $query_slice;
    my $target;
    my $target_slice;
    
    foreach my $member_attribute (@{$homology->get_all_Member_Attribute}) {
      my ($member, $attribute) = @{$member_attribute};
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
    
      my $bioseq = Bio::Seq->new( -display_id => $gene->stable_id . "_".$upstream_length ."bp_upstream",
                                  -seq => $seq);
      unless (defined $query) {
        $query = $bioseq;
        $query_slice = $slice
      } else {
        $target = $bioseq;
        $target_slice = $slice
      }
    }

    my $runnable = new Bio::EnsEMBL::Pipeline::Runnable::Promoterwise(-QUERY => $query,
                                                                      -TARGET => $target,
                                                                      -OPTIONS => $pw_options);

    $runnable->run;
#    print "track name=\"PW vs ",$target_slice->adaptor->db->get_MetaContainer->get_Species->binomial,"\" description=\"promoterwise on orthologues upstream regions\" color=000000 url=http://www.ebi.ac.uk/~abel\n";
    foreach my $aln (@{$runnable->output}) {
      next if ($aln->score < $bits_cutoff);
      $aln->slice($query_slice);
      $aln->hslice($target_slice);
#      my $strand;
#      if ($aln->slice->strand > 0) {
#        $strand = "+";
#      } else {
#        $strand = "-";
#      }
      print $aln->slice->seq_region_name . " " .
        $aln->seq_region_start . " " .
          $aln->seq_region_end . " " .
            $aln->slice->strand . " " .

#                $aln->score . " " .
#                  $strand . " " .

                $aln->hslice->seq_region_name . " " .
                  $aln->hseq_region_start . " " .
                    $aln->hseq_region_end . " " .
                      $aln->hslice->strand . " " .
#                          $aln->score . " " .
#                            $aln->cigar_string . " " .
      $aln->seqname . " " .
        $aln->start . " " .
          $aln->end . " " .
            $aln->strand . " " .
              $aln->hseqname . " " .
                $aln->hstart . " " .
                  $aln->hend . " " .
                    $aln->hstrand . " " .
                      $aln->score . " " .
                        $aln->cigar_string . " " .
                          "\n";
    }
  }
}

close DBID;


