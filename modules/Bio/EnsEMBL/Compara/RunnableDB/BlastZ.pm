#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::BlastZ

=cut

=head1 SYNOPSIS

my $db      = Bio::EnsEMBL::Compara::DBAdaptor->new($locator);
my $repmask = Bio::EnsEMBL::Pipeline::RunnableDB::BlastZ->new ( 
                                                    -db      => $db,
                                                    -input_id   => $input_id
                                                    -analysis   => $analysis );
$repmask->fetch_input(); #reads from DB
$repmask->run();
$repmask->output();
$repmask->write_output(); #writes to DB

=cut

=head1 DESCRIPTION

This object wraps Bio::EnsEMBL::Pipeline::Runnable::Blast to add
functionality to read and write to databases.
The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. A Bio::EnsEMBL::Pipeline::DBSQL::Obj is
required for databse access.

=cut

=head1 CONTACT

Describe contact details here

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::BlastZ;

use strict;

use Bio::EnsEMBL::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Pipeline::Runnable::Blastz;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Time::HiRes qw(time gettimeofday tv_interval);

use vars qw(@ISA);

@ISA = qw(Bio::EnsEMBL::Pipeline::RunnableDB);
my $g_compara_BlastZ_workdir;

=head2 fetch_input
    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none
=cut

sub fetch_input {
  my( $self) = @_;

  $self->{'debug'} = 0;
  
  $self->throw("No input_id") unless defined($self->input_id);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with the Pipeline::DBAdaptor that is based into this runnable
  $self->{'comparaDBA'} = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc);
  $self->{'comparaDBA'}->dbc->disconnect_when_inactive(1);

  print("input_id = ", $self->input_id,"\n");
  my $input_hash = eval($self->input_id);
  print("$input_hash\n");
  $self->throw("No input_id") unless defined($input_hash);
  my $qy_chunk_id = $input_hash->{'qyChunk'};
  my $db_chunk_id = $input_hash->{'dbChunk'};

  my $qyChunk = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->fetch_by_dbID($qy_chunk_id);
  my $dbChunk = $self->{'comparaDBA'}->get_DnaFragChunkAdaptor->fetch_by_dbID($db_chunk_id);

  $self->{'qyChunk'} = $qyChunk;
  $self->{'dbChunk'} = $dbChunk;
  
  print("have chunks\n  ",$qyChunk->display_id,"\n  ", $dbChunk->display_id,"\n");
  my $starttime = time();

  my $qySeq = $qyChunk->bioseq;
  unless($qySeq) {
    printf("fetching chunk %s on-the-fly\n", $qyChunk->display_id);
    $qySeq = $qyChunk->fetch_masked_sequence(2);  #soft masked
    print STDERR (time()-$starttime), " secs to fetch qyChunk seq\n";
  }

  my $dbSeq = $dbChunk->bioseq;
  unless($dbSeq) {
    printf("fetching chunk %s on-the-fly\n", $dbChunk->display_id);
    $dbSeq = $dbChunk->fetch_masked_sequence(2);  #soft masked
    print STDERR (time()-$starttime), " secs to fetch dbChunk seq\n";
  }

  #print("running with analysis '".$self->analysis->logic_name."'\n");
  my $runnable =  new Bio::EnsEMBL::Pipeline::Runnable::Blastz (
                  -query     => $qySeq,
                  -database  => $dbSeq,
                  -options   => 'T=2 H=2200');

  $self->runnable($runnable);

  #
  # create method_link_species_set
  #
  my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
  $mlss->method_link_type("BLASTZ_RAW");
  $mlss->species_set([$qyChunk->dnafrag->genome_db, $dbChunk->dnafrag->genome_db]);
  $self->{'comparaDBA'}->get_MethodLinkSpeciesSetAdaptor->store($mlss);
  $self->{'method_link_species_set'} = $mlss;
  
  return 1;
}


sub run
{
  my $self = shift;

  my $starttime = time();
  foreach my $runnable ($self->runnable) {
    throw("Runnable module not set") unless($runnable);
    $runnable->run();
  }
  print STDERR (time()-$starttime), " secs to BlastZ\n";
  return 1;
}


sub write_output {
  my( $self) = @_;

  my $starttime = time();

  #since the Blast runnable takes in analysis parameters rather than an
  #analysis object, it creates new Analysis objects internally
  #(a new one for EACH FeaturePair generated)
  #which are a shadow of the real analysis object ($self->analysis)
  #The returned FeaturePair objects thus need to be reset to the real analysis object
  foreach my $fp ($self->output) {
    if($fp->isa('Bio::EnsEMBL::FeaturePair')) {
      $fp->analysis($self->analysis);

      $self->store_featurePair_as_genomicAlignBlock($fp);
    }
  }

  #$self->{'comparaDBA'}->get_PeptideAlignFeatureAdaptor->store($self->output);

  printf("%d FeaturePairs found\n", scalar($self->output));
  print STDERR (time()-$starttime), " secs to write_output\n";

}


sub global_cleanup {
  my $self = shift;
  if($g_compara_BlastZ_workdir) {
    unlink(<$g_compara_BlastZ_workdir/*>);
    rmdir($g_compara_BlastZ_workdir);
  }
  return 1;
}

##########################################
#
# internal methods
#
##########################################


sub store_featurePair_as_genomicAlignBlock
{
  my $self = shift;
  my $fp   = shift;

  my $qyChunk = $self->{'qyChunk'};
  my $dbChunk = $self->{'dbChunk'};

  if($self->{'debug'}) {
    print("qyChunk : ",$qyChunk->display_id,"\n");
    print("dbChunk : ",$dbChunk->display_id,"\n");
    print STDOUT $fp->seqname."\t".
                 $fp->start."\t".
                 $fp->end."\t".
                 $fp->strand."\t".
                 $fp->hseqname."\t".
                 $fp->hstart."\t".
                 $fp->hend."\t".
                 $fp->hstrand."\t".
                 $fp->score."\t".
                 $fp->percent_id."\t".
                 $fp->cigar_string."\n";
  }                 

  $fp->slice($qyChunk->slice);
  $fp->hslice($dbChunk->slice);               

  #
  # test if I'm getting the indexes right
  #
  if($self->{'debug'}) {
    print_simple_align($fp->get_SimpleAlign, 80);

    my $testChunk = new Bio::EnsEMBL::Compara::DnaFragChunk();
    $testChunk->dnafrag($qyChunk->dnafrag);
    $testChunk->seq_start($qyChunk->seq_start+$fp->start-1);
    $testChunk->seq_end($qyChunk->seq_start+$fp->end-1);
    my $bioseq = $testChunk->fetch_masked_sequence('soft');
    print($bioseq->seq, "\n");
  }


  my $genomic_align1 = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align1->method_link_species_set($self->{'method_link_species_set'});
  $genomic_align1->dnafrag($qyChunk->dnafrag);
  $genomic_align1->dnafrag_start($qyChunk->seq_start + $fp->start -1);
  $genomic_align1->dnafrag_end($qyChunk->seq_start + $fp->end -1);
  $genomic_align1->dnafrag_strand($fp->strand);
  $genomic_align1->level_id(1);
  
  my $cigar1 = $fp->cigar_string;
  $cigar1 =~ s/I/M/g;
  $cigar1 = compact_cigar_line($cigar1);
  $cigar1 =~ s/D/G/g;
  $genomic_align1->cigar_line($cigar1);


  my $genomic_align2 = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align2->method_link_species_set($self->{'method_link_species_set'});
  $genomic_align2->dnafrag($dbChunk->dnafrag);
  $genomic_align2->dnafrag_start($dbChunk->seq_start + $fp->hstart -1);
  $genomic_align2->dnafrag_end($dbChunk->seq_start + $fp->hend -1);
  $genomic_align2->dnafrag_strand($fp->hstrand);
  $genomic_align2->level_id(1);

  my $cigar2 = $fp->cigar_string;
  $cigar2 =~ s/D/M/g;
  $cigar2 =~ s/I/D/g;
  $cigar2 = compact_cigar_line($cigar2);
  $cigar2 =~ s/D/G/g;
  $genomic_align2->cigar_line($cigar2);

  if($self->{'debug'}) {
    print("original cigar_line ",$fp->cigar_string,"\n");
    print("   $cigar1\n");
    print("   $cigar2\n");
  }

  my $GAB = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
  $GAB->method_link_species_set($self->{'method_link_species_set'});
  $GAB->genomic_align_array([$genomic_align1, $genomic_align2]);
  $GAB->score($fp->score);
  $GAB->perc_id($fp->percent_id);
  $GAB->length($fp->alignment_length);

  $self->{'comparaDBA'}->get_GenomicAlignBlockAdaptor->store($GAB);

  if($self->{'debug'}) { print_simple_align($GAB->get_SimpleAlign, 80);}

  return $GAB;
}


sub compact_cigar_line
{
  my $cigar_line = shift;

  #print("cigar_line '$cigar_line' => ");
  my @pieces = ( $cigar_line =~ /(\d*[MDI])/g );
  my @new_pieces = ();
  foreach my $piece (@pieces) {
    $piece =~ s/I/M/;
    if (! scalar @new_pieces || $piece =~ /D/) {
      push @new_pieces, $piece;
      next;
    }
    if ($piece =~ /\d*M/ && $new_pieces[-1] =~ /\d*M/) {
      my ($matches1) = ($piece =~ /(\d*)M/);
      my ($matches2) = ($new_pieces[-1] =~ /(\d*)M/);
      if (! defined $matches1 || $matches1 eq "") {
        $matches1 = 1;
      }
      if (! defined $matches2 || $matches2 eq "") {
        $matches2 = 1;
      }
      $new_pieces[-1] = $matches1 + $matches2 . "M";
    } else {
      push @new_pieces, $piece;
    }
  }
  my $new_cigar_line = join("", @new_pieces);
  #print(" '$new_cigar_line'\n");
  return $new_cigar_line;
}


sub print_simple_align
{
  my $alignment = shift;
  my $aaPerLine = shift;
  $aaPerLine=40 unless($aaPerLine and $aaPerLine > 0);
  
  my ($seq1, $seq2)  = $alignment->each_seq;
  my $seqStr1 = "|".$seq1->seq().'|';
  my $seqStr2 = "|".$seq2->seq().'|';

  my $enddiff = length($seqStr1) - length($seqStr2);
  while($enddiff>0) { $seqStr2 .= " "; $enddiff--; }
  while($enddiff<0) { $seqStr1 .= " "; $enddiff++; }

  my $label1 = sprintf("%40s : ", $seq1->id);
  my $label2 = sprintf("%40s : ", "");
  my $label3 = sprintf("%40s : ", $seq2->id);

  my $line2 = "";
  for(my $x=0; $x<length($seqStr1); $x++) {
    if(substr($seqStr1,$x,1) eq substr($seqStr2, $x,1)) { $line2.='|'; } else { $line2.=' '; }
  }

  my $offset=0;
  my $numLines = (length($seqStr1) / $aaPerLine);
  while($numLines>0) {
    printf("$label1 %s\n", substr($seqStr1,$offset,$aaPerLine));
    printf("$label2 %s\n", substr($line2,$offset,$aaPerLine));
    printf("$label3 %s\n", substr($seqStr2,$offset,$aaPerLine));
    print("\n\n");
    $offset+=$aaPerLine;
    $numLines--;
  }
}

1;
