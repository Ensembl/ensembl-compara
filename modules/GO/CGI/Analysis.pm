
package GO::CGI::Analysis;

use GO::Utils qw(rearrange);
use strict;

use WebReports::BlastMarkup qw(markup);
use WebReports::BlastRunner qw(run_blast make_fasta is_na is_aa blast_okay);

=head1 SYNOPSIS

package GO::CGI::Analysis




=head2 launchJobFromFile


=cut

=head2 launchJob


=cut

sub launchJob {
  my $self = shift;
  my ($session, $mode) =
    rearrange([qw(session mode)], @_);

  require DirHandle;
  require FileHandle;

  my $seq = $session->get_param('sequence');
  my $session_id = $session->get_param('session_id');
  my $blast_dir = $session_id."_blast";
  #  if ($seq =~ m/^>/) {
  # Make a session#_blast dir.
  my $data_dir = $session->get_param('data_dir');

  if (!new DirHandle("$data_dir/$blast_dir")) {
    eval {
      mkdir("$data_dir/$blast_dir");
      `chmod a+rw $data_dir/$blast_dir`;
    };
  }

  # Create the sequence file.
  eval {
    	  `rm -rf $data_dir/$blast_dir/*`;
  };
  my $file = new FileHandle("> $data_dir/$blast_dir/current_seq");
  my $program;

      if ($session->get_param('seq_id')) {
	$program = "blastp";
	my $apph = $session->apph;
	my $seq_id = $session->get_param('seq_id');
	$seq_id =~ s/.*\|//;
	my $product = $apph->get_product({acc=>$seq_id});
	$file->print ($product->to_fasta);
      } elsif ($session->get_param('sptr_id')) {
	$program = "blastp";
	  my $product = $session->apph->get_product({seq_acc=>$session->get_param('sptr_id')});
	$file->print ($product->to_fasta);

      } elsif ($session->get_param('seq')) {
	$program = $self->get_program($session);
	
	my $seq = $session->get_param('seq');
	$file->print($seq);
    }	

  $file->close;
  `chmod a+r $data_dir/$blast_dir/current_seq`;


  # create the blast command
  my $file = new FileHandle("> $data_dir/$blast_dir/command.pbs");
  $file->print('#!/bin/sh'."\n");
  my $program_bin = $session->get_param($program);
  my $fasta_db = $session->get_param('fasta_db');
  my $seq_file = "$data_dir/$blast_dir/current_seq";
  my $threshhold = $session->get_param('threshhold') || 0.001;
  my $result = "$data_dir/$blast_dir/result";
  my $error = "$data_dir/$blast_dir/error";
  $file->print("($program_bin $fasta_db $seq_file  -e$threshhold -v50 > $result) >& $error\n");
  $file->print("chmod a+r $result\n");
  $file->print("chmod a+r $error\n");
  $file->close;
  `chmod a+r $data_dir/$blast_dir/command.pbs`;

  #launch the job
  my $qsub = $session->get_param('qsub');
  my $command = "$data_dir/$blast_dir/command.pbs";
  my $queue = $session->get_param('queue');
  my $job = `$qsub -u public -q $queue $command`;

  $session->__set_param(-field=>'last_job',
			      -query=>'1',
			      -values=>[$job]
		       );
  $session->__save_params(-query=>'1',
			  -params=>['last_job']);
}

sub get_fasta {
    my $self = shift;
    my $session = shift;
    my $session_id = $session->get_param('session_id');
    my $blast_dir = $session_id."_blast";

    my $sequence = $session->get_param('seq');
    if ($sequence =~ m/^>/) {
      if ($sequence =~ m/\n>.*/s) {
	$sequence =~ s/\n>.*//s;
	$session->__set_param(-field=>'sequence',
			      -query=>'current_query',
			      -values=>[$sequence]
			     );
	$session->__set_param(-field=>'seq_input_error',
			      -query=>'current_query',
			      -values=>['too_many_seqs']
			     );
      }
      $sequence =~ s/\s$//g;
      $sequence =~ s/\ //g;  
      $session->__set_param(-field=>'seq',
			    -query=>'current_query',
			    -values=>[$sequence]
			   );
    } else {
      $sequence = ">\n$sequence";
      $sequence =~ s/\s$//g;
      $session->__set_param(-field=>'seq',
			    -query=>'current_query',
			    -values=>[$sequence]
			   );
    }
}



sub checkSequence {
    my $self = shift;
    my ($session) =
	rearrange([qw(session)], @_);

    require GO::Model::Seq;

    if (!$session->get_param('upfile') &&
	!$session->get_param('seq') &&
	!$session->get_param('seq_id') &&
	!$session->get_param('sptr_id')
	) {
	$session->__set_param(-field=>'deadly_seq_input_error',
			      -values=>['no_input']);
    }
    
    if ($session->get_param('seq') ||
	$session->get_param('upfile') ||
	$session->get_param('seq_id') |
	$session->get_param('sptr_id')
	) {
	## make sure the sequence is cool.
	$self->get_sequence($session);
	$self->get_fasta($session);
	$self->has_one_sequence($session);
    }

    my $program = $self->get_program($session);
    my $t;
    if ($session->get_param('seq_id')) {

      ## There may be issues here.  Are all gene product id's unique?
	my $id = $session->get_param('seq_id');
	$id =~ s/^.*\|//;
	my $qseq = $session->apph->get_product({acc=>$id});
	if ($qseq) {
	    $session->__set_param(-field=>'sequence',
				  -query=>'current_query',
				  -values=>[$qseq->to_fasta]
				  );
	    $session->__set_param(-field=>'seq_id',
				  -query=>'current_query',
				  -values=>[uc($qseq->speciesdb).'|'.$qseq->acc]
				  );
	} else {
	    $session->__set_param(-field=>'deadly_seq_input_error',
				  -values=>['bad_seq_id']);
	}
    } elsif ($session->get_param('sptr_id')) {
	
	## There may be issues here.  Are all gene product id's unique?
	my $id = $session->get_param('sptr_id');
	$id =~ s/^.*\|//;

	my $qseq = $session->apph->get_product({seq_acc=>$id});
	if ($qseq) {
	    $session->__set_param(-field=>'sequence',
				  -query=>'current_query',
				  -values=>[$qseq->to_fasta]
				  );
	    $session->__set_param(-field=>'seq_id',
				  -query=>'current_query',
				  -values=>[uc($qseq->speciesdb).'|'.$qseq->acc]
				  );
	} else {
	    $session->__set_param(-field=>'deadly_seq_input_error',
				  -values=>['bad_seq_id']);
	}
    } elsif ($session->get_param('seq') ||
	     $session->get_param('upfile')) {
	
	my $sequence = $session->get_param('seq');
	$sequence =~ s/^>.*?\n//;
	$sequence =~ s/\n>.*//s;
	eval {
	    my $new_seq = $sequence;
	    $new_seq =~ s/\s//g;
	    chomp($new_seq);
	    my $seq = GO::Model::Seq->new(-seq=>$new_seq);
	    if ($seq->length > $session->get_param('max_seq_length')) {
		$session->__set_param(-field=>'deadly_seq_input_error',
				      -values=>['seq_too_long']);
	    }
	};
	if($@) {
	    $session->__set_param(-field=>'deadly_seq_input_error',
				  -values=>['bad_seq']);
	    
	}
    }
}


sub get_sequence {
    my $self = shift;
    my $session = shift;
    my $sequence;

    my $count = 0;
    if ($session->get_param('upfile')) {
	$count += 1;
    }
    if ($session->get_param('seq')) {
	$count += 1;
    }
    if ($session->get_param('seq_id')) {
	$count += 1;
    }
    if ($session->get_param('sptr_id')) {
	$count += 1;
    }

    if ($count > 1) {
    $session->__set_param(-field=>'seq_input_error',
                          -values=>['too_many_seqs']);
}

  if ($session->get_param('upfile') &&
      $session->get_param('seq')) {
    $session->__set_param(-field=>'seq_input_error',
                          -values=>['upfile_and_seq']);
}
    if ($session->get_param('upfile')) {
	my $file = $session->get_cgi->param('upfile');
	$sequence = "";
	my $size = 0;
	my $seqline;
	while (defined($seqline = <$file>)) {
	    $seqline =~ s/^[ \t]*//;
	    $seqline =~ s/[ \t]*$//;
	    $sequence .= $seqline;
	}
    # remove line feeds.
	$sequence =~ s/\x0D//g;
    $session->__set_param(-field=>'seq',
                          -query=>'current_query',
                          -values=>[$sequence]
			  );
    $session->__set_param(-field=>'sequence',
                          -values=>[$sequence]
			  );
    } elsif ($session->get_param('seq')) {
	$sequence = "";
	my $seq = $session->get_param('seq');
	foreach my $line(split "\n", $seq) {
	    $line =~ s/^[ \t]*//;
	    $line =~ s/[ \t]*$//;

	    $sequence .= $line;
	}
    $session->__set_param(-field=>'seq',
                          -values=>[$sequence]
			  );
    $session->__set_param(-field=>'sequence',
                          -values=>[$sequence]
			  );
    }

    return 0;

}


sub has_one_sequence {
    my $self = shift;
    my $session = shift;

#  my $num_seqs = 0;
#  my $seq = $session->get_param('seq');
#  foreach my $line(split "\n", $seq) {
#    if ($line =~ /^>/) {
#    }
#  }



}

sub get_program {
    my $self = shift;
    my $session = shift;
    my @lines = split '\n', $session->get_param('seq');
    foreach my $line (@lines) {
	if ($line !~ /^>/) {
	    if (is_na($line)) {
		return "blastx";
	    } else {
		return "blastp";
	    }
	}
    }
}



1;






