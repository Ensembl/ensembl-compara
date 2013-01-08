=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastFactory 

=head1 SYNOPSIS


=head1 DESCRIPTION

Fetch sorted list of member_ids and create jobs for BlastAndParsePAF. 
Supported keys:
   'genome_db_id' => <number>
       Genome_db id. Obligatory

   'step' => <number>
       How many sequences to write into the blast query file. Default 1000



=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastFactory;

use strict;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
    my $self = shift @_;

	my $genome_db_id = $self->param('genome_db_id') || $self->param('genome_db_id', $self->param('gdb'))        # for compatibility
	  or die "'genome_db_id' is an obligatory parameter";

    if (!defined $self->param('step')) {
	$self->param('step', 1000);
    }
}


sub write_output {
    my $self = shift @_;


    #Fetch members for genome_db_id
    my $sql = 'SELECT member_id FROM member WHERE genome_db_id = ?';
    my $sth = $self->compara_dba->dbc->prepare( $sql );
    $sth->execute($self->param('genome_db_id'));
    
    my $member_id_list;
    while( my ($member_id) = $sth->fetchrow() ) {
	push @$member_id_list, $member_id;
    }

    my $step = $self->param('step');

    #Sort on member_id
    my $sorted_list;
    @$sorted_list = sort {$a <=> $b} @$member_id_list;
    
    my $start_member_id = $sorted_list->[0];
    my $offset = 0;
    my $batch_size;

    #Create jobs for BlastAndParsePAF
    for (my $i = 0; $i < @$sorted_list; $i++) {
	my $member_id = $sorted_list->[$i];

	if ($batch_size == $step) {
	    my $output_id = {'genome_db_id' => $self->param('genome_db_id'), 'start_member_id' => $start_member_id, 'offset' => $offset, 'batch_size' => $batch_size};
	    
	    $self->dataflow_output_id($output_id, 2);

	    $offset += $batch_size;
	    $batch_size = 0;
	    $start_member_id= $member_id;
	}
	$batch_size++;
    }

    my $output_id = {'genome_db_id' => $self->param('genome_db_id'), 'start_member_id' => $start_member_id, 'offset' => $offset, 'batch_size' => $batch_size};

    
   $self->dataflow_output_id($output_id, 2);


}
return 1;
