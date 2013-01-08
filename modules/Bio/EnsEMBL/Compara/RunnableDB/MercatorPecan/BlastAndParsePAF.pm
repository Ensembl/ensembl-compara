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

Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastAndParsePAF 

=head1 SYNOPSIS


=head1 DESCRIPTION

Create fasta file containing batch_size number of sequences. Run ncbi_blastp and parse the output into
PeptideAlignFeature objects. Store PeptideAlignFeature objects in the compara database
Supported keys:
    'blast_param' => <string>
        ncbi blastp parameters
eg "-num_alignments 20 -seg 'yes' -best_hit_overhang 0.2 -best_hit_score_edge 0.1 -use_sw_tback"
    'fasta_dir' => <directory path>
        Path to fasta files
    'mlss_id' => <number>
        Method link species set id for Pecan. Obligatory
    'genome_db_id' => <number>
        Species genome db id.
    'offset' => <number>
        Offset into ordered array of member_ids. Obligatory
    'start_member_id' => <number>
        Member id of member at 'offset' in order array of member ids. Obligatory
    'batch_size' => <number>
        Number of members to write to fasta file
    'reuse_ss_id' => <number>
        Reuse species set id. Normally stored in the meta table. Obligatory.
    'do_transactions' => <0|1>
        Whether to do transactions. Default is yes.


=cut

package Bio::EnsEMBL::Compara::RunnableDB::MercatorPecan::BlastAndParsePAF;

use strict;
use FileHandle;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Analysis::Tools::FeatureFactory;
use Bio::EnsEMBL::Utils::Exception qw(throw warning info);
use Bio::EnsEMBL::Utils::SqlHelper;

#
# Fetch members and sequences from the database. 
# Return a sorted list based on member_id, starting at $offset and with $batch_size items
#
sub load_members_from_db{
    my ($self, $start_member_id, $offset, $batch_size) = @_;

    my $idprefixed              = $self->param('idprefixed')  || 0;
    my $debug                   = $self->debug() || $self->param('debug') || 0;
    my $genome_db_id            = $self->param('genome_db_id');

    #Get list of members and sequences
    my $sql = "SELECT member_id, sequence_id, stable_id, sequence FROM member JOIN sequence USING (sequence_id) WHERE genome_db_id=?";
    
    my $sth = $self->compara_dba->dbc->prepare( $sql );
    $sth->execute($genome_db_id);

    my $member_list;
    while( my ($member_id, $seq_id, $stable_id, $seq) = $sth->fetchrow() ) {
        $seq=~ s/(.{72})/$1\n/g;
        chomp $seq;
	my $fasta_line = ($idprefixed
                                ? ">seq_id_${seq_id}_${stable_id}\n$seq\n"
                                : ">$stable_id sequence_id=$seq_id member_id=$member_id\n$seq\n") ;
	my $member_sequence;
	%$member_sequence = ( member_id => $member_id,
			      fasta_line => $fasta_line);
	push @$member_list, $member_sequence;
    }
    $sth->finish();
    $self->compara_dba->dbc->disconnect_when_inactive(1);

    #Sort on member_id
    my $sorted_list;
    @$sorted_list = sort {$a->{member_id} <=> $b->{member_id}} @$member_list;

    my $fasta_list;
    #Check start_member_id is the same as the item at offset
    if ($self->param('start_member_id') ne $sorted_list->[$offset]->{member_id}) {
	throw("start_member_id " . $self->param('start_member_id') . " is not the same as offset " . $sorted_list->[$offset]->{member_id});
    }
    for (my $i = $offset; $i < ($offset+$batch_size); $i++) {
	my $member_id = $sorted_list->[$i]->{member_id};
	my $fasta_line = $sorted_list->[$i]->{fasta_line};
	push @$fasta_list, $fasta_line;
    }
    return $fasta_list;
}

#
# Load stable_id name to member_id mappings from the database
#
sub load_name2member_mapping_from_db {
    my ($self) = @_;

    my $sql = qq {
        SELECT member_id, stable_id
          FROM member
    };

    my $sth = $self->compara_dba->dbc->prepare( $sql );
    $sth->execute();

    my %name2index = ();
    while( my ($member_id, $stable_id) = $sth->fetchrow() ) {
        $name2index{$stable_id} = $member_id;
    }
    $sth->finish();
    $self->compara_dba->dbc->disconnect_when_inactive(1);

    return \%name2index;
}

#
# Convert stable_id name to member_id.
#
sub name2member { 
    my ($self, $name) = @_;

    if($name=~/^member_id_(\d+)_/) {
        return $1;
    } else {
        my $name2member;
        unless($name2member = $self->param('name2member')) {
            my $tabfile                 = $self->param('tabfile');

            $name2member = $self->param('name2member', $tabfile
                ? $self->load_name2member_mapping_from_file($tabfile)
                : $self->load_name2member_mapping_from_db()
            );
        }
        return $name2member->{$name} || "UNKNOWN($name)";
    }
}

sub fetch_input {
    my $self = shift @_;

    my $start_member_id = $self->param('start_member_id') || die "'start_member_id' is an obligatory parameter, please set it in the input_id hashref";
    my $offset          = $self->param('offset');
    die "'offset' is an obligatory parameter" if (!defined $offset);

    my $batch_size      = $self->param('batch_size') || 1000;
    my $debug           = $self->debug() || $self->param('debug') || 0;

    my $fasta_list      = $self->load_members_from_db($start_member_id, $offset, $batch_size);

    if (!defined $self->param('genome_db_id')) {
	die "'genome_db_id' is an obligatory parameter";
    }

    #set default to do transactions
    if (!defined $self->param('do_transactions')) {
	$self->param('do_transactions', 1);
    }

    if($debug) {
        print "Loaded ".scalar(@$fasta_list)." sequences\n";
    }

    $self->param('fasta_list', $fasta_list);

    my $reuse_ss_id = $self->param('reuse_ss_id')
                    or die "'reuse_ss_id' is an obligatory parameter dynamically set in 'meta' table by the pipeline - please investigate";

    my $reuse_ss = $self->compara_dba()->get_SpeciesSetAdaptor->fetch_by_dbID($reuse_ss_id);    # this method cannot fail at the moment, but in future it may

    my $reuse_ss_hash = {};

    if ($reuse_ss) {
        $reuse_ss_hash = { map { $_->dbID() => 1 } @{ $reuse_ss->genome_dbs() } };
    }
    $self->param('reuse_ss_hash', $reuse_ss_hash );

     # We get the list of genome_dbs to execute, then go one by one with this member

    my $mlss_id         = $self->param('mlss_id') or die "'mlss_id' is an obligatory parameter";
    my $mlss            = $self->compara_dba()->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($mlss_id) or die "Could not fetch mlss with dbID=$mlss_id";
    my $species_set     = $mlss->species_set_obj->genome_dbs;

    my $genome_db_list;

    #If reusing this genome_db, only need to blast against the 'fresh' genome_dbs
    if ($reuse_ss_hash->{$self->param('genome_db_id')}) {
	foreach my $gdb (@$species_set) {
	    if (!$reuse_ss_hash->{$gdb->dbID}) {
		push @$genome_db_list, $gdb;
	    }
	}
    } else {
	#Using 'fresh' genome_db therefore must blast against everything
	$genome_db_list  = (ref($species_set) eq 'ARRAY') ? $species_set : $species_set->genome_dbs();
    }

    print STDERR "Found ", scalar(@$genome_db_list), " genomes to blast this member against.\n" if ($self->debug);
    $self->param('genome_db_list', $genome_db_list);

}

sub parse_blast_table_into_paf {
    my ($self, $filename, $min_self_dist, $qgenome_db_id, $hgenome_db_id) = @_;

    my $debug                   = $self->debug() || $self->param('debug') || 0;

    my $features;
    my $roundto    = $self->param('roundto') || 0.0001;

    my $curr_name    = '';
    my $curr_index   = 0;

    open(BLASTTABLE, "<$filename") || die "Could not open the blast table file '$filename'";
    
    print "blast $qgenome_db_id $hgenome_db_id $filename\n" if $debug;

    while(my $line = <BLASTTABLE>) {

        unless ($line =~ /^#/) {
            my ($qname, $hname, $evalue, $score, $nident,$pident, $qstart, $qend, $hstart,$hend, $length, $positive, $ppos ) = split(/\s+/, $line);

	    my $source_name = "ENSEMBLPEP";
	    $hname =~ s/[$source_name]*://; #Need to remove "$source_name:" from name. Need to check if this is a general problem or just for
	                     #my old test database
            my $qmember_id = $self->name2member($qname);
            my $hmember_id = $self->name2member($hname);
	    my $analysis_id = $self->analysis->dbID;

	    my $feature;
	    %$feature = (analysis_id       => $analysis_id,
			 qmember_id        => $qmember_id,
			 hmember_id        => $hmember_id,
			 qstable_id        => $qname,
			 hstable_id        => $hname,
			 qgenome_db_id     => $qgenome_db_id,
			 hgenome_db_id     => $hgenome_db_id,
			 perc_ident        => $pident,
			 score             => $score,
			 evalue            => $evalue,
			 qstart            => $qstart,
			 qend              => $qend,
			 hstart            => $hstart,
			 hend              => $hend,
			 length            => $length,
			 perc_ident        => $pident,
			 identical_matches => $nident,
			 positive          => $positive,
			 perc_pos          => $ppos);
			  
	    print "feature query $qgenome_db_id $qmember_id hit $hgenome_db_id $hmember_id $hname $qstart $qend $hstart $hend $length $nident $positive\n" if $debug;
#	    push @$features, $feature;
	    push @{$features->{$qmember_id}}, $feature;
            #$matrix_hash{$curr_index}{$hit_index} = $distance;
        }
    }
    close BLASTTABLE;
    if (!defined $features) {
	return $features;
    }

    #group together by qmember_id and rank the hits
    foreach my $qmember_id (keys %$features) {
	my $qfeatures = $features->{$qmember_id};
	@$qfeatures = sort sort_by_score_evalue_and_pid @$qfeatures;
	my $rank=1;
	my $prevPaf = undef;
	foreach my $paf (@$qfeatures) {
	    $rank++ if($prevPaf and !pafs_equal($prevPaf, $paf));
	    $paf->{hit_rank} = $rank;
	    $prevPaf = $paf;
	}
    }
    return $features;
}

sub sort_by_score_evalue_and_pid {
  $b->{score} <=> $a->{score} ||
    $a->{evalue} <=> $b->{evalue} ||
      $b->{perc_ident} <=> $a->{perc_ident} ||
        $b->{perc_pos} <=> $a->{perc_pos};
}

sub pafs_equal {
  my ($paf1, $paf2) = @_;
  return 0 unless($paf1 and $paf2);
  return 1 if(($paf1->{score} == $paf2->{score}) and
              ($paf1->{evalue} == $paf2->{evalue}) and
              ($paf1->{perc_ident} == $paf2->{perc_ident}) and
              ($paf1->{perc_pos} == $paf2->{perc_pos}));
  return 0;
}

sub run {
    my $self = shift @_;

    my $fasta_list              = $self->param('fasta_list'); # set by fetch_input()
    my $debug                   = $self->debug() || $self->param('debug') || 0;

    unless(scalar(@$fasta_list)) { # if we have no more work to do just exit gracefully
        if($debug) {
            warn "No work to do, exiting\n";
        }
        return;
    }
    my $reuse_db          = $self->param('reuse_db');   # if this parameter is an empty string, there will be no reuse

    my $reuse_ss_hash     = $self->param('reuse_ss_hash');
    my $reuse_this_member = $reuse_ss_hash->{$self->param('genome_db_id')};

    my $blastdb_dir             = $self->param('fasta_dir');
    my $minibatch               = $self->param('minibatch')     || 1;

    my $blast_bin_dir           = $self->param('blast_bin_dir') || ( '/software/ensembl/compara/ncbi-blast-2.2.23+/bin' );
    my $blast_params            = $self->param('blast_params')  || '';  # no parameters to C++ binary means having composition stats on and -seg masking off
    my $evalue_limit            = $self->param('evalue_limit')  || 0.00001;
    my $tophits                 = $self->param('tophits')       || 20;

    my $worker_temp_directory   = $self->worker_temp_directory;

    my $blast_infile  = $worker_temp_directory . 'mercator_blast.in.'.$$;     # only for debugging
    my $blast_outfile = $worker_temp_directory . 'mercator_blast.out.'.$$;    # looks like inevitable evil (tried many hairy alternatives and failed)

    if($debug) {
        open(FASTA, ">$blast_infile") || die "Could not open '$blast_infile' for writing";
        print FASTA @$fasta_list;
        close FASTA;
    }

    $self->compara_dba->dbc->disconnect_when_inactive(1); 

    my $cross_pafs;
    foreach my $genome_db (@{$self->param('genome_db_list')}) {
	my $fastafile = $genome_db->name() . '_' . $genome_db->assembly() . '.fasta';
	$fastafile =~ s/\s+/_/g;    # replace whitespace with '_' characters
	$fastafile =~ s/\/\//\//g;  # converts any // in path to /
	my $cross_genome_dbfile = $blastdb_dir . '/' . $fastafile;   # we are always interested in the 'foreign' genome's fasta file, not the member's

	#Don't blast against self
	unless ($genome_db->dbID == $self->param('genome_db_id')) {
    
	    #Hard code for now
	    #Moved to analysis table
	    #$blast_params = "-num_alignments 20 -seg 'no'";
	    #$blast_params = "-num_alignments 20 -seg 'yes'";
	    #$blast_params = "-num_alignments 20 -seg 'yes' -best_hit_overhang 0.2 -best_hit_score_edge 0.1 -use_sw_tback";

	    #Run blastp
	    my $cmd = "${blast_bin_dir}/blastp -db $cross_genome_dbfile $blast_params -evalue $evalue_limit -num_descriptions $tophits -out $blast_outfile -outfmt '7 qacc sacc evalue score nident pident qstart qend sstart send length positive ppos'";
	    if($debug) {
		warn "CMD:\t$cmd\n";
	    }
	    my $start_time = time();
	    open( BLAST, "| $cmd") || die qq{could not execute "${cmd}", returned error code: $!};
	    print BLAST @$fasta_list;
	    close BLAST;
	    
	    print "Time for blast " . (time() - $start_time) . "\n";

	    my $features = $self->parse_blast_table_into_paf($blast_outfile, -log($evalue_limit)/log(10), $self->param('genome_db_id'), $genome_db->dbID);
	    if (defined $features) {
		foreach my $qmember_id (keys %$features) {
		    my $qfeatures = $features->{$qmember_id};
		    push @$cross_pafs, @$qfeatures;
		}
	    }
	    unless($debug) {
		unlink $blast_outfile;
	    }
	}
    }
     $self->compara_dba->dbc->disconnect_when_inactive(0); 

    unless($debug) {
	$self->param('cross_pafs', $cross_pafs);
    }

}

sub write_output {
    my ($self) = @_;
    
    if ($self->param('do_transactions')) {
	my $compara_conn = $self->compara_dba->dbc;

	my $compara_helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $compara_conn);
	$compara_helper->transaction(-CALLBACK => sub {
					 $self->_write_output;
				     });
    } else {
	$self->_write_output;
    }

}


sub _write_output {
    my $self = shift @_;

    my $cross_pafs = $self->param('cross_pafs');
    #foreach my $genome_db_id (keys %$cross_pafs) {
    #    $self->compara_dba->get_PeptideAlignFeatureAdaptor->store(@{$cross_pafs->{$genome_db_id}});
    #}
    print "numbers pafs " . scalar(@$cross_pafs) . "\n";
    foreach my $feature (@$cross_pafs) {
	my $peptide_table = $self->get_table_name_from_dbID($feature->{qgenome_db_id});

	#AWFUL HACK to insert into the peptide_align_feature table but without going through the API. Only fill in
	#some the of fields
	my $sql = "INSERT INTO $peptide_table (qmember_id, hmember_id, qgenome_db_id, hgenome_db_id, qstart, qend, hstart, hend, score, evalue, hit_rank,identical_matches, perc_ident,align_length,positive_matches, perc_pos) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?, ?,?)";
	my $sth = $self->compara_dba->dbc->prepare( $sql );

	#print "INSERT INTO $peptide_table (qmember_id, hmember_id, qgenome_db_id, hgenome_db_id, analysis_id, qstart, qend, hstart, hend, score, evalue, hit_rank,identical_matches, perc_ident,align_length,positive_matches, perc_pos) VALUES ('" . $feature->{qmember_id} , "','" . $feature->{hmember_id} . "'," . $feature->{qgenome_db_id} . "," . $feature->{hgenome_db_id} . "," . $feature->{analysis_id} . "," . $feature->{qstart} . "," . $feature->{qend} . "," . $feature->{hstart} . "," . $feature->{hend} . "," . $feature->{score} . "," . $feature->{evalue} . "," . $feature->{hit_rank} . "," . $feature->{identical_matches} . "," . $feature->{perc_ident} . "," . $feature->{length} . "," . $feature->{positive} . "," . $feature->{perc_pos} . "\n";

	$sth->execute($feature->{qmember_id},
		      $feature->{hmember_id},
		      $feature->{qgenome_db_id},
		      $feature->{hgenome_db_id},
		      #$feature->{analysis_id},
		      $feature->{qstart},
		      $feature->{qend},
		      $feature->{hstart},
		      $feature->{hend},
		      $feature->{score},
		      $feature->{evalue},
		      $feature->{hit_rank},
		      $feature->{identical_matches},
		      $feature->{perc_ident},
		      $feature->{length},
		      $feature->{positive},
		      $feature->{perc_pos});
    }
}

sub get_table_name_from_dbID {
  my ($self, $gdb_id) = @_;
  my $table_name = "peptide_align_feature";

  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;
  my $gdb = $gdba->fetch_by_dbID($gdb_id);
  return $table_name if (!$gdb);

  $table_name .= "_" . lc($gdb->name) . "_" . $gdb_id;
  $table_name =~ s/ /_/g;

  return $table_name;
}


1;

