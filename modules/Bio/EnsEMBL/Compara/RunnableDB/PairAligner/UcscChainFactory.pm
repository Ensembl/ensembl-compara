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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscChainFactory

=head1 SYNOPSIS


=head1 DESCRIPTION

Effectively splits a UCSC chain file into smaller bits by using a seek position and the number of lines to be read, to allow for parallel processing 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscChainFactory;

use strict;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


############################################################

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_; 

  #Read at least this many lines to the next chain
  my $step = $self->param('step');

  #Open Ucsc chain file
  open(FILE, $self->param('chain_file')) or die ("Unable to open " . $self->param('chain_file'));

  my $seek_positions;
  my $prev_pos = 0;
  my $line_num = 1;
  
  my $first_chain = 1;

  #
  #Read through UCSC chain file. Store the position of the first chain tag 
  #(prev_pos) and read $step lines and store the number of lines until you
  #reach the next chain tag ($line_num-1)
  #
  while (<FILE>) {
      my $curr_pos = tell(FILE); #current position in file
      if (/chain /) {
	  if ($first_chain || $line_num >= $step) {
	      my $pos_line;
	      %$pos_line = ('pos' => $prev_pos,
			    'line' => $line_num-1);
	      push @$seek_positions, $pos_line;
	      $line_num = 1;
	      $first_chain = 0;
	  }
      }
      $prev_pos = $curr_pos; 
      $line_num++;
  }

  #Store last position
  my $pos_line;
  %$pos_line = ('pos' => $prev_pos,
		'line' => $line_num-1);
  push @$seek_positions, $pos_line;
  
  close FILE;

  for (my $index = 0;  $index < (@$seek_positions-1); $index++) {
      my $seek_pos = $seek_positions->[$index]->{pos};
      my $num_lines = $seek_positions->[$index+1]->{line};

      my $output_id = "{seek_offset=>" . $seek_pos . ",num_lines=>" .  $num_lines . "}";
      $self->dataflow_output_id($output_id, 2);
  }
}

1;
