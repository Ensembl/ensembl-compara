=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
Copyright [2016-2020] EMBL-European Bioinformatics Institute

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

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome.

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors;

use strict;
use warnings;

use Data::Dumper;
use List::Util qw(shuffle);
use POSIX ":sys_wait_h";

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;

        my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_dbID($self->param_required('genome_db_id'));
        my $genome_db_file = $genome_db->_get_genome_dump_path($self->param_required('genome_dumps_dir'));
        die "$genome_db_file doesn't exist" unless -e $genome_db_file;
        $self->dbc->disconnect_if_idle() if $self->dbc;
        $self->param_required('mlss_id');
        my $anchor_dba = $self->get_cached_compara_dba('compara_anchor_db');
        my $sth;
        if ($self->param('anchor_ids')) {
            $sth = $anchor_dba->dbc->prepare(sprintf('SELECT anchor_id, sequence FROM anchor_sequence WHERE anchor_id IN (%s)', join(',', @{$self->param('anchor_ids')})));
            $sth->execute;
        } else {
        $sth = $anchor_dba->dbc->prepare("SELECT anchor_id, sequence FROM anchor_sequence WHERE anchor_id BETWEEN  ? AND ?");
            $sth->execute( $self->param_required('min_anchor_id'), $self->param_required('max_anchor_id') );
        }

	my $query_file = $self->worker_temp_directory  . "anchors.fa";
	my $n = 0;
	my @anchor_ids;
	open(my $fh, '>', $query_file) || die("Couldn't open $query_file");
	foreach my $anc_seq( @{ $sth->fetchall_arrayref } ){
		push @anchor_ids, $anc_seq->[0];
		print $fh ">", $anc_seq->[0], "\n", $anc_seq->[1], "\n";
		$n++;
	}
        close($fh);
        $sth->finish;
        $self->die_no_retry("No anchors to align") unless $n;
        $self->param('anchor_ids', \@anchor_ids);
        $anchor_dba->dbc->disconnect_if_idle;
	$self->param('query_file', $query_file);

        $self->param('target_file', $genome_db_file);
        $self->preload_file_in_memory($genome_db_file);

        return unless $self->param('with_server');

        die ".esd index for $genome_db_file doesn't exist" unless -e "$genome_db_file.esd";
        $self->preload_file_in_memory("$genome_db_file.esd");
        die ".esi index for $genome_db_file doesn't exist" unless -e "$genome_db_file.esi";
        $self->preload_file_in_memory("$genome_db_file.esi");

        $self->param('index_file', "$genome_db_file.esi");
        $self->start_server;
}

sub run {
	my ($self) = @_;
        $self->dbc->disconnect_if_idle() if $self->dbc;
	my $program = $self->param_required('mapping_exe');
	my $query_file = $self->param_required('query_file');
	my $target_file = $self->param_required('target_file');
	my $option_st;
	while( my ($opt, $opt_value) = each %{ $self->param_required('mapping_params') } ) {
		$option_st .= " --" . $opt . " " . $opt_value; 
	}
	my $command = join(" ", $program, $option_st, $query_file, $target_file); 
        my $hits;
	$self->read_from_command($command, sub {
	my $out_fh = shift;

        while(my $mapping = <$out_fh>) {
	next unless $mapping =~/^vulgar:/;
	my($anchor_info, $targ_strand, $targ_dnafrag, $targ_from, $targ_to, $score) = (split(" ",$mapping))[1,8,5,6,7,9];
	($targ_from, $targ_to) = ($targ_to, $targ_from) if ($targ_from > $targ_to); #exonerate can switch these around
		$targ_strand = $targ_strand eq "+" ? "1" : "-1";
		$targ_from++; #modify the exonerate start position
		my($anchor_name, $anc_org) = split(":", $anchor_info);
		push(@{$hits->{$anchor_name}{$targ_dnafrag}}, [ $targ_from, $targ_to, $targ_strand, $score, $anc_org ]);
	}

	} );

        $self->stop_server if $self->param('with_server');

        if ($self->param('retry')) {
            $self->warning('Server started after '.$self->param('retry').' attempts');
        }

	if (!$hits) {
		$self->warning("Exonerate didn't find any hits");
		return;
	}
	my $hit_numbers = $self->merge_overlapping_target_regions($hits);

	my $records = $self->process_exonerate_hits($hits, $hit_numbers);
        $self->param('records', $records);
}

sub write_output {
    my ($self) = @_;

    # eHive DBConnections are more resilient to deadlocks, etc
    my $dbc = Bio::EnsEMBL::Hive::DBSQL::DBConnection->new(-dbconn => $self->compara_dba->dbc);
    # Delete the anchors one by one to minimize the amount of row-locking
    # and the risk of creating deadlocks
    my $sql = 'DELETE anchor_align FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE anchor_id = ? AND genome_db_id = ?';
    foreach my $anchor_id (@{$self->param('anchor_ids')}) {
        $dbc->do($sql, undef, $anchor_id, $self->param('genome_db_id'));
    }

    my $anchor_align_adaptor = $self->compara_dba()->get_adaptor("AnchorAlign");
    if (my $records = $self->param('records')) {
        $anchor_align_adaptor->store_exonerate_hits($records);
    }
}

sub process_exonerate_hits {
	my $self = shift;
	my($hits, $hit_numbers) = @_;
	my @records_to_load;
	foreach my $anchor_id (sort keys %{$hits}) {
		foreach my $dnafrag_id (sort keys %{$hits->{$anchor_id}}) {
			foreach my $hit_position (@{$hits->{$anchor_id}->{$dnafrag_id}}) {
				my $index = join(":", $anchor_id, $dnafrag_id, $hit_position->[0]);
				my $number_of_org_hits = keys %{$hit_numbers->{$index}->{anc_orgs}};
				my $number_of_seq_hits = $hit_numbers->{$index}->{seq_nums};
				push @records_to_load, [$self->param('mlss_id'), $anchor_id, $dnafrag_id, @{$hit_position}[0..3], $number_of_org_hits, $number_of_seq_hits];
			}
		}
	}
	return \@records_to_load;
}

sub merge_overlapping_target_regions { #merge overlapping target regions hit by different seqs in the same anchor
	my $self = shift;
	my $mapped_anchors = shift;
	my $HIT_NUMS;
	foreach my $anchor(sort {$a <=> $b} keys %{$mapped_anchors}) {
	        foreach my $targ_info(sort keys %{$mapped_anchors->{$anchor}}) {
	                # $targ_info is in fact a dnafrag_id
	                @{$mapped_anchors->{$anchor}{$targ_info}} = sort {$a->[0] <=> $b->[0]} @{$mapped_anchors->{$anchor}{$targ_info}};
	                for(my$i=0;$i<@{$mapped_anchors->{$anchor}{$targ_info}};$i++) {
	                        my $anc_look_up_name = join(":", $anchor, $targ_info, $mapped_anchors->{$anchor}{$targ_info}->[$i]->[0]);
				if($i < @{$mapped_anchors->{$anchor}{$targ_info}} - 1) {
		                        if($mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] >= $mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[0]) {  
		                                unless($mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] eq 
							$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[2]) {       
		                                        print STDERR "possible palindromic sequences: $anchor ", 
								"$mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] ", 
								$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[2], "\n";
		                                        $mapped_anchors->{$anchor}{$targ_info}->[$i]->[2] = 1; # arbitrarily set the strand to 1 in the merged hit
		                                }       
		                                if($mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] < 
							$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[1]) {
		                                        $mapped_anchors->{$anchor}{$targ_info}->[$i]->[1] = 
								$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[1];
		                                }       
		                                $mapped_anchors->{$anchor}{$targ_info}->[$i]->[3] += $mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[3];
		                                $mapped_anchors->{$anchor}{$targ_info}->[$i]->[3] /= 2; # simplistic scoring
						#count the organisms from which the anchor seqs were derived 
		                                $HIT_NUMS->{$anc_look_up_name}{anc_orgs}{$mapped_anchors->{$anchor}{$targ_info}->[$i+1]->[4]}++;
						#count number of anchor seqs that map
						$HIT_NUMS->{$anc_look_up_name}{seq_nums}++;
		                                splice(@{$mapped_anchors->{$anchor}{$targ_info}}, $i+1, 1);
		                                $i--;   
						next;
		                        }       
				}
				$HIT_NUMS->{$anc_look_up_name}{anc_orgs}{$mapped_anchors->{$anchor}{$targ_info}->[$i]->[4]}++;
				$HIT_NUMS->{$anc_look_up_name}{seq_nums}++;
	                }       
	        }       
	}
	return $HIT_NUMS;
}


## Functions to start and stop the server ##

sub start_server {
    my $self = shift @_;

    # Get the list of ports that are in use
    my $netstat_output = $self->get_command_output("netstat -nt4 | tail -n+3 | awk '{print \$4}' | cut -d: -f2 | sort -nu", { use_bash_pipefail => 1 });
    my %bad_ports = map {$_ => 1} split(/\n/, $netstat_output);
    my @available_ports = grep {!$bad_ports{$_}} (shuffle 12886..42886);

    # We try one of them
    my $candidate_port = $available_ports[0];
    if ($self->start_server_on_port($candidate_port)) {
        $self->param('target_file', "localhost:$candidate_port");
    } else {
        # If we can't start the server on one port, there is more than 80%
        # chance that it won't just work on the next random port, and
        # we'll have to try even more ports. Instead of spending too much
        # time we just give up !
        my $retry = $self->param('retry') + 1;
        if ($retry > 20) {
            die "Still failing to start the server after $retry attempts";
        }
        $self->dataflow_output_id( { 'retry' => $retry }, 2);
        $self->input_job->lethal_for_worker(1); # Since the host is not cooperating, we should leave
        # Note: we do a controlled exit to distinguish from uncaught errors
        $self->complete_early('Port already taken. New job created');
    }
}

sub start_server_on_port {
  my ($self, $port) = @_;

  my $server_exe = $self->param_required('server_exe');
  my $index_file = $self->param_required('index_file');
  my $log_file = $self->worker_temp_directory . "/server_gdb_". $self->param_required('genome_db_id'). '.log.' . ($self->worker->dbID // 'standalone');
  my $command = "$server_exe $index_file --maxconnections 1 --port $port &> $log_file";

  $self->say_with_header("Starting the server: $command");
  my $pid;
  {
    if ($pid = fork) {
      last;
    } elsif (defined $pid) {
      mkdir $self->worker_temp_directory.'/'.$port;
      chdir $self->worker_temp_directory.'/'.$port;
      exec("exec $command") == 0 or $self->throw("Failed to run $command: $!");
    }
  }
  $self->param('server_pid', $pid);

  my $cycles = 0;
  my $seconds_by_cycle = 10;
  while ($cycles*$seconds_by_cycle < 12*3600) { # Half a day ought to be enough
      sleep $seconds_by_cycle;
      $cycles++;
      my $started_message = $self->get_command_output(['tail', '-1', $log_file]);
      if ($started_message =~ /listening on port/) {
          $self->say_with_header("Server started on port $port after $cycles cycles of $seconds_by_cycle seconds");
          return 1;

      } elsif ($started_message =~ /Address already in use/) {
          $self->stop_server;
          $self->warning("Failed to start server: Address already in use");
          return 0;

      } elsif (waitpid($pid, WNOHANG)) {
          $self->warning("Server exited by itself: $started_message");
          return 0;
      }
  }
  $self->say_with_header("Server still not ready. Aborting");
  $self->stop_server;
  return 0;
}

sub stop_server {
  my $self = shift @_;

  my $pid = $self->param('server_pid');
  $self->say_with_header("Killing server process $pid");
  kill('KILL', $pid) or $self->throw("Failed to kill server process $pid: $!");
  waitpid($pid, 0);
}


1;

