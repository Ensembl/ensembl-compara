=head1 LICENSE

  Copyright (c) 1999-2012 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner

=cut

=head1 SYNOPSIS

=cut

=head1 DESCRIPTION

This object is an abstract superclass which must be inherited from.
It uses a runnable which takes sequence as input and returns
FeaturePair objects as output (like Bio::EnsEMBL::Analysis::Runnable::Blastz)

It adds functionality to read and write to a compara databases.
It takes as input (via input_id or analysis->parameters) DnaFragChunk or DnaFragChunkSet
objects (via dbID reference) and stores GenomicAlignBlock entries.

The appropriate Bio::EnsEMBL::Analysis object must be passed for
extraction of appropriate parameters. 

=cut

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::PairAligner;

use strict;
use Time::HiRes qw(time gettimeofday tv_interval);
use File::Basename;
use Bio::EnsEMBL::Utils::Exception;
use Bio::EnsEMBL::Utils::SqlHelper;
use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


##########################################
#
# subclass override methods
# 
##########################################

sub configure_defaults {
  my $self = shift;
  return 0;
}

sub configure_runnable {
  my $self = shift;
  throw("subclass must implement configure_runnable method\n");
}

##########################################
#
# internal RunnableDB methods that should
# not be subclassed
# 
##########################################

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Function:   Fetches input data for repeatmasker from the database
    Returns :   none
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_;

  #
  # run subclass configure_defaults method
  #
  $self->configure_defaults();
  
  my $query_DnaFragChunkSet = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

  if(defined($self->param('qyChunkSetID'))) {
      my $chunkset = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param('qyChunkSetID'));
      $query_DnaFragChunkSet = $chunkset;
  } else {
      throw("Missing qyChunkSetID");
  }
  $self->param('query_DnaFragChunkSet',$query_DnaFragChunkSet);

  my $db_DnaFragChunkSet = new Bio::EnsEMBL::Compara::Production::DnaFragChunkSet;

  if(defined($self->param('dbChunkSetID'))) {
      my $chunkset = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param('dbChunkSetID'));
      $db_DnaFragChunkSet = $chunkset;
  } else {
      throw("Missing dbChunkSetID");
  }
  $self->param('db_DnaFragChunkSet',$db_DnaFragChunkSet);

  #create a Compara::DBAdaptor which shares the same DBI handle
  #with $self->db (Hive DBAdaptor)
  $self->compara_dba->dbc->disconnect_when_inactive(0);

  throw("Missing qyChunkSet") unless($query_DnaFragChunkSet);
  throw("Missing dbChunkSet") unless($db_DnaFragChunkSet);
  throw("Missing method_link_type") unless($self->param('method_link_type'));
  

  my ($first_qy_chunk) = @{$query_DnaFragChunkSet->get_all_DnaFragChunks};
  my ($first_db_chunk) = @{$db_DnaFragChunkSet->get_all_DnaFragChunks};
  
  #
  # create method_link_species_set
  #
  my $method = Bio::EnsEMBL::Compara::Method->new( -type => $self->param('method_link_type') );

  my $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -genome_dbs => ($first_qy_chunk->dnafrag->genome_db->dbID == $first_db_chunk->dnafrag->genome_db->dbID)
                            ? [$first_qy_chunk->dnafrag->genome_db]
                            : [$first_qy_chunk->dnafrag->genome_db, $first_db_chunk->dnafrag->genome_db]
  );
        
  my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method             => $method,
        -species_set_obj    => $species_set_obj,
  );

  $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
  $self->param('method_link_species_set', $mlss);

  if (defined $self->param('max_alignments')) {
      my $sth = $self->compara_dba->dbc->prepare("SELECT count(*) FROM genomic_align_block".
						 " WHERE method_link_species_set_id = ".$mlss->dbID);
      $sth->execute();
      my ($num_alignments) = $sth->fetchrow_array();
      $sth->finish();
      if ($num_alignments >= $self->max_alignments) {
	  throw("Too many alignments ($num_alignments) have been stored already for MLSS ".$mlss->dbID."\n".
		"  Try changing the parameters or increase the max_alignments option if you think\n".
		"  your system can cope with so many alignments.");
      }
  }

  #
  # execute subclass configure_runnable method
  #
  $self->configure_runnable();

  return 1;
}


sub run
{
  my $self = shift;

  $self->compara_dba->dbc->disconnect_when_inactive(1);  

  my $starttime = time();

  foreach my $runnable (@{$self->param('runnable')}) {
      throw("Runnable module not set") unless($runnable);
      $runnable->run();
  }

  if($self->debug){printf("%1.3f secs to run %s pairwise\n", (time()-$starttime), $self->param('method_link_type'));}

  $self->compara_dba->dbc->disconnect_when_inactive(0);
  return 1;
}

sub delete_fasta_dumps_but_these {
  my $self = shift;
  my $fasta_files_not_to_delete = shift;

  my $work_dir = $self->worker_temp_directory;

  open F, "ls $work_dir|";
  while (my $file = <F>) {
    chomp $file;
    next unless ($file =~ /\.fasta$/);
    my $delete = 1;
    foreach my $fasta_file (@{$fasta_files_not_to_delete}) {
      if ($file eq basename($fasta_file)) {
        $delete = 0;
        last;
      }
    }
    unlink "$work_dir/$file" if ($delete);
  }
  close F;
}

sub write_output {
  my( $self) = @_;

  my $starttime = time();

  #since the Blast runnable takes in analysis parameters rather than an
  #analysis object, it creates new Analysis objects internally
  #(a new one for EACH FeaturePair generated)
  #which are a shadow of the real analysis object ($self->analysis)
  #The returned FeaturePair objects thus need to be reset to the real analysis object

  #
  #Start transaction
  #
  if ($self->param('do_transactions'))  {
      my $compara_conn = $self->compara_dba->dbc;
      my $compara_helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $compara_conn);
      $compara_helper->transaction(-CALLBACK => sub {
	  $self->_write_output;
      });
  } else {
      $self->_write_output;
  }

  return 1;
}

sub _write_output {
    my ($self) = @_;
    my $fake_analysis     = Bio::EnsEMBL::Analysis->new;

  #Set use_autoincrement to 1 otherwise the GenomicAlignBlockAdaptor will use
  #LOCK TABLES which does an implicit commit and prevent any rollback
  $self->compara_dba->get_GenomicAlignBlockAdaptor->use_autoincrement(1);
  foreach my $runnable (@{$self->param('runnable')}) {
      foreach my $fp ( @{ $runnable->output() } ) {
          if($fp->isa('Bio::EnsEMBL::FeaturePair')) {
              $fp->analysis($fake_analysis);

              $self->store_featurePair_as_genomicAlignBlock($fp);
          }
      }
      if($self->debug){printf("%d FeaturePairs found\n", scalar(@{$runnable->output}));}
  }

  #print STDERR (time()-$starttime), " secs to write_output\n";
}

##########################################
#
# internal methods
#
##########################################

sub dumpChunkSetToWorkdir
{
  my $self      = shift;
  my $chunkSet   = shift;

  my $starttime = time();

  my $fastafile = $self->worker_temp_directory. "chunk_set_". $chunkSet->dbID .".fasta";

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);

  open(OUTSEQ, ">$fastafile")
    or $self->throw("Error opening $fastafile for write");
  my $output_seq = Bio::SeqIO->new( -fh =>\*OUTSEQ, -format => 'Fasta');
  
  #Masking options are stored in the dna_collection
  my $dna_collection = $chunkSet->dna_collection;

  my $chunk_array = $chunkSet->get_all_DnaFragChunks;
  if($self->debug){printf("dumpChunkSetToWorkdir : %s : %d chunks\n", $fastafile, $chunkSet->count());}
  
  foreach my $chunk (@$chunk_array) {
    $chunk->masking_options($dna_collection->masking_options);
    my $bioseq = $chunk->bioseq;
    if($chunk->sequence_id==0) {
      $self->compara_dba->get_DnaFragChunkAdaptor->update_sequence($chunk);
    }

    $output_seq->write_seq($bioseq);
  }
  close OUTSEQ;
  if($self->debug){printf("  %1.3f secs to dump\n", (time()-$starttime));}
  return $fastafile
}


sub dumpChunkToWorkdir
{
  my $self = shift;
  my $chunk = shift;

  my $starttime = time();

  my $fastafile = $self->worker_temp_directory .
                  "chunk_" . $chunk->dbID . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);

  if($self->debug){print("dumpChunkToWorkdir : $fastafile\n");}


  $chunk->cache_sequence;
  $chunk->dump_to_fasta_file($fastafile);

  if($self->debug){printf("  %1.3f secs to dump\n", (time()-$starttime));}

  return $fastafile
}

sub store_featurePair_as_genomicAlignBlock
{
  my $self = shift;
  my $fp   = shift;

  my $qyChunk = undef;
  my $dbChunk = undef;
  
  if($fp->seqname =~ /chunkID(\d*):/) {
    my $chunk_id = $1;
    #printf("%s => %d\n", $fp->seqname, $chunk_id);
    $qyChunk = $self->compara_dba->get_DnaFragChunkAdaptor->
                     fetch_by_dbID($chunk_id);
  }
  if($fp->hseqname =~ /chunkID(\d*):/) {
    my $chunk_id = $1;
    #printf("%s => %d\n", $fp->hseqname, $chunk_id);
    $dbChunk = $self->compara_dba->get_DnaFragChunkAdaptor->
                     fetch_by_dbID($chunk_id);
  }
  unless($qyChunk and $dbChunk) {
    warn("unable to determine DnaFragChunk objects from FeaturePair");
    return undef;
  }

  if($self->debug > 1) {
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
  if($self->debug > 2) {
    print_simple_align($fp->get_SimpleAlign, 80);

    my $testChunk = new Bio::EnsEMBL::Compara::Production::DnaFragChunk();
    $testChunk->dnafrag($qyChunk->dnafrag);
    $testChunk->seq_start($qyChunk->seq_start+$fp->start-1);
    $testChunk->seq_end($qyChunk->seq_start+$fp->end-1);
    my $bioseq = $testChunk->bioseq;
    print($bioseq->seq, "\n");
  }


  my $genomic_align1 = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align1->method_link_species_set($self->param('method_link_species_set'));
  $genomic_align1->dnafrag($qyChunk->dnafrag);
  $genomic_align1->dnafrag_start($qyChunk->seq_start + $fp->start -1);
  $genomic_align1->dnafrag_end($qyChunk->seq_start + $fp->end -1);
  $genomic_align1->dnafrag_strand($fp->strand);
  $genomic_align1->visible(1);
  
  my $cigar1 = $fp->cigar_string;
  $cigar1 =~ s/I/M/g;
  $cigar1 = compact_cigar_line($cigar1);
  $cigar1 =~ s/D/G/g;
  $genomic_align1->cigar_line($cigar1);

  my $genomic_align2 = new Bio::EnsEMBL::Compara::GenomicAlign;
  $genomic_align2->method_link_species_set($self->param('method_link_species_set'));
  $genomic_align2->dnafrag($dbChunk->dnafrag);
  $genomic_align2->dnafrag_start($dbChunk->seq_start + $fp->hstart -1);
  $genomic_align2->dnafrag_end($dbChunk->seq_start + $fp->hend -1);
  $genomic_align2->dnafrag_strand($fp->hstrand);
  $genomic_align2->visible(1);

  my $cigar2 = $fp->cigar_string;
  $cigar2 =~ s/D/M/g;
  $cigar2 =~ s/I/D/g;
  $cigar2 = compact_cigar_line($cigar2);
  $cigar2 =~ s/D/G/g;
  $genomic_align2->cigar_line($cigar2);

  if($self->debug > 1) {
    print("original cigar_line ",$fp->cigar_string,"\n");
    print("   $cigar1\n");
    print("   $cigar2\n");
  }

  my $GAB = new Bio::EnsEMBL::Compara::GenomicAlignBlock;
  $GAB->method_link_species_set($self->param('method_link_species_set'));
  $GAB->genomic_align_array([$genomic_align1, $genomic_align2]);
  $GAB->score($fp->score);
  $GAB->perc_id($fp->percent_id);
  $GAB->length($fp->alignment_length);
  $GAB->level_id(1);

  $self->compara_dba->get_GenomicAlignBlockAdaptor->store($GAB);
  
  if($self->debug > 2) { print_simple_align($GAB->get_SimpleAlign, 80);}

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
