=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2018] EMBL-European Bioinformatics Institute

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=cut


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

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
use warnings;

use Time::HiRes qw(time gettimeofday tv_interval);
use File::Basename;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Bio::EnsEMBL::Analysis::RunnableDB;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'max_alignments'    => undef,
    }
}

##########################################
#
# subclass override methods
# 
##########################################

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

  my $query_DnaFragChunkSet = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param_required('qyChunkSetID'));
  $self->param('query_DnaFragChunkSet',$query_DnaFragChunkSet);
  throw("Missing qyChunkSet") unless($query_DnaFragChunkSet);

  my $db_DnaFragChunkSet = $self->compara_dba->get_DnaFragChunkSetAdaptor->fetch_by_dbID($self->param_required('dbChunkSetID'));
  $self->param('db_DnaFragChunkSet',$db_DnaFragChunkSet);
  throw("Missing dbChunkSet") unless($db_DnaFragChunkSet);

  my %chunks_lookup;
  map {$chunks_lookup{$_->dbID} = $_} @{$db_DnaFragChunkSet->get_all_DnaFragChunks};
  map {$chunks_lookup{$_->dbID} = $_} @{$query_DnaFragChunkSet->get_all_DnaFragChunks};
  $self->param('chunks_lookup', \%chunks_lookup);

  #$db_DnaFragChunkSet->load_all_sequences();
  $query_DnaFragChunkSet->load_all_sequences() unless $query_DnaFragChunkSet->dna_collection->dump_loc && (-s $query_DnaFragChunkSet->dump_loc_file);

  throw("Missing method_link_type") unless($self->param('method_link_type'));

  my $mlss = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->param_required('mlss_id'));
  $self->param('method_link_species_set', $mlss);

  if (defined $self->param('max_alignments')) {
      my $sth = $self->compara_dba->dbc->prepare("SELECT count(*) FROM genomic_align_block".
						 " WHERE method_link_species_set_id = ".$mlss->dbID);
      $sth->execute();
      my ($num_alignments) = $sth->fetchrow_array();
      $sth->finish();
      if ($num_alignments >= $self->param('max_alignments')) {
	  throw("Too many alignments ($num_alignments) have been stored already for MLSS ".$mlss->dbID."\n".
		"  Try changing the parameters or increase the max_alignments option if you think\n".
		"  your system can cope with so many alignments.");
      }
  }
  $self->compara_dba->dbc->disconnect_if_idle();

  #
  # execute subclass configure_runnable method
  #
  $self->configure_runnable();

  return 1;
}


sub run
{
  my $self = shift;

  $self->compara_dba->dbc->disconnect_if_idle();

  my $starttime = time();
  my $work_dir = $self->worker_temp_directory;
  foreach my $runnable (@{$self->param('runnable')}) {
      throw("Runnable module not set") unless($runnable);
      $runnable->run($work_dir);
  }

  if($self->debug){printf("%1.3f secs to run %s pairwise\n", (time()-$starttime), $self->param('method_link_type'));}

  return 1;
}

sub delete_fasta_dumps_but_these {
  my $self = shift;
  my $fasta_files_not_to_delete = shift;

  my $work_dir = $self->worker_temp_directory;

  foreach my $file (glob('*.fasta')) {
    my $delete = 1;
    foreach my $fasta_file (@{$fasta_files_not_to_delete}) {
      if ($file eq basename($fasta_file)) {
        $delete = 0;
        last;
      }
    }
    unlink "$work_dir/$file" if ($delete);
  }
}

sub write_output {
  my( $self) = @_;

  #
  #Start transaction
  #
  $self->call_within_transaction( sub {
      $self->_write_output;
  } );

  return 1;
}

sub _write_output {
    my ($self) = @_;
    my $fake_analysis     = Bio::EnsEMBL::Analysis->new;
  my $starttime = time();

  foreach my $runnable (@{$self->param('runnable')}) {
      foreach my $fp ( @{ $runnable->output() } ) {
          if($fp->isa('Bio::EnsEMBL::FeaturePair')) {
              #since the Blast runnable takes in analysis parameters rather than an
              #analysis object, it creates new Analysis objects internally
              #(a new one for EACH FeaturePair generated)
              #which are a shadow of the real analysis object ($self->analysis)
              #The returned FeaturePair objects thus need to be reset to the real analysis object

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

  if ($chunkSet->dna_collection->dump_loc) {
      my $fastafile = $chunkSet->dump_loc_file;
      if (-s $fastafile) {
          if($self->debug){print("dumpChunkSetToWorkdir : $fastafile already dumped\n");}
          return $fastafile
      }
  }

  my $starttime = time();

  my $fastafile = $self->worker_temp_directory. "/chunk_set_". $chunkSet->dbID .".fasta";

  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);

  if($self->debug){printf("dumpChunkSetToWorkdir : %s : %d chunks\n", $fastafile, $chunkSet->count());}

  $chunkSet->dump_to_fasta_file($fastafile);

  if($self->debug){printf("  %1.3f secs to dump\n", (time()-$starttime));}
  return $fastafile
}

sub dumpChunkToWorkdir
{
  my $self = shift;
  my $chunk = shift;
  my $dna_collection = shift;

  if ($dna_collection->dump_loc) {
      my $fastafile = $chunk->dump_loc_file($dna_collection);
      if (-s $fastafile) {
          if($self->debug){print("dumpChunkToWorkdir : $fastafile already dumped\n");}
          return $fastafile
      }
  }

  my $starttime = time();

  my $fastafile = $self->worker_temp_directory . "/chunk_" . $chunk->dbID . ".fasta";
  $fastafile =~ s/\/\//\//g;  # converts any // in path to /
  return $fastafile if(-e $fastafile);

  if($self->debug){print("dumpChunkToWorkdir : $fastafile\n");}

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
    $qyChunk = $self->param('chunks_lookup')->{$chunk_id};
  }
  if($fp->hseqname =~ /chunkID(\d*):/) {
    my $chunk_id = $1;
    #printf("%s => %d\n", $fp->hseqname, $chunk_id);
    $dbChunk = $self->param('chunks_lookup')->{$chunk_id};
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

  #
  # test if I'm getting the indexes right
  #
  if($self->debug > 2) {
    $fp->slice($qyChunk->slice);
    $fp->hslice($dbChunk->slice);
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

  # Don't store self-alignments
  return undef if ($genomic_align1->dnafrag_id == $genomic_align2->dnafrag_id)
                    && ($genomic_align1->dnafrag_start == $genomic_align2->dnafrag_start)
                    && ($genomic_align1->dnafrag_end == $genomic_align2->dnafrag_end)
                    && ($genomic_align1->dnafrag_strand == $genomic_align2->dnafrag_strand);

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
