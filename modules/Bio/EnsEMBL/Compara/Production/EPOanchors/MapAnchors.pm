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

=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome.

=head1 AUTHOR

Stephen Fitzgerald


=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::MapAnchors;

use strict;
use warnings;

use Data::Dumper;
use List::Util qw(shuffle);
use POSIX ":sys_wait_h";

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub pre_cleanup {
    my ($self) = @_;
    if ($self->param('_range_list')) {
        $self->compara_dba->dbc->do(sprintf('DELETE anchor_align FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE anchor_id IN (%s) AND genome_db_id = ?', join(',', @{$self->param('_range_list')})),
            undef, $self->param_required('genome_db_id'));
    } else {
        $self->compara_dba->dbc->do('DELETE anchor_align FROM anchor_align JOIN dnafrag USING (dnafrag_id) WHERE anchor_id BETWEEN ? AND ? AND genome_db_id = ?',
            undef, $self->param_required('min_anchor_id'), $self->param_required('max_anchor_id'), $self->param_required('genome_db_id'));
    }
}

sub fetch_input {
	my ($self) = @_;

        $self->dbc->disconnect_if_idle();
        $self->param_required('mlss_id');
        my $anchor_dba = $self->get_cached_compara_dba('compara_anchor_db');
	my $genome_db_file = $self->param_required('genome_dump_file');
        my $sth;
        my $min_anc_id;
        my $max_anc_id;
        if ($self->param('_range_list')) {
            $sth = $anchor_dba->dbc->prepare(sprintf('SELECT anchor_id, sequence FROM anchor_sequence WHERE anchor_id IN (%s)', join(',', @{$self->param('_range_list')})));
            $min_anc_id = $self->param('_range_list')->[0];
            $max_anc_id = $self->param('_range_list')->[-1];
            $sth->execute;

        } else {
        $sth = $anchor_dba->dbc->prepare("SELECT anchor_id, sequence FROM anchor_sequence WHERE anchor_id BETWEEN  ? AND ?");
        $min_anc_id = $self->param('min_anchor_id');
        $max_anc_id = $self->param('max_anchor_id');
	$sth->execute( $min_anc_id, $max_anc_id );
        }
        my %all_anchor_ids;
	my $query_file = $self->worker_temp_directory  . "anchors." . join ("-", $min_anc_id, $max_anc_id );
	open(my $fh, '>', $query_file) || die("Couldn't open $query_file");
	foreach my $anc_seq( @{ $sth->fetchall_arrayref } ){
                $all_anchor_ids{$anc_seq->[0]} = 1;
		print $fh ">", $anc_seq->[0], "\n", $anc_seq->[1], "\n";
	}
        close($fh);
        $sth->finish;
        $anchor_dba->dbc->disconnect_if_idle;
	$self->param('query_file', $query_file);
        $self->param('all_anchor_ids', [keys %all_anchor_ids]);
        $self->param('target_file', $genome_db_file);

        return unless $self->param('with_server');
        $self->param('index_file', "$genome_db_file.esi");
        $self->param('log_file', $self->worker_temp_directory . "/server_gdb_". $self->param_required('genome_db_id'). '.log.' . ($self->worker->dbID // 'standalone'));
        $self->param('max_connections', 1);
        $self->start_server;
}

sub run {
	my ($self) = @_;
        $self->dbc->disconnect_if_idle();
	my $program = $self->param_required('mapping_exe');
	my $query_file = $self->param_required('query_file');
	my $target_file = $self->param_required('target_file');
	my $option_st;
	while( my ($opt, $opt_value) = each %{ $self->param_required('mapping_params') } ) {
		$option_st .= " --" . $opt . " " . $opt_value; 
	}
	my $command = join(" ", $program, $option_st, $query_file, $target_file); 
	print $command, "\n";
	my $out_fh;
	open( $out_fh, '-|', $command ) or die("Error opening exonerate command: $? $!"); #run mapping program
	$self->param('out_file', $out_fh);

        my $hits;
        while(my $mapping = <$out_fh>) {
	next unless $mapping =~/^vulgar:/;
	my($anchor_info, $targ_strand, $targ_dnafrag, $targ_from, $targ_to, $score) = (split(" ",$mapping))[1,8,5,6,7,9];
	($targ_from, $targ_to) = ($targ_to, $targ_from) if ($targ_from > $targ_to); #exonerate can switch these around
		$targ_strand = $targ_strand eq "+" ? "1" : "-1";
		$targ_from++; #modify the exonerate start position
		my($anchor_name, $anc_org) = split(":", $anchor_info);
		push(@{$hits->{$anchor_name}{$targ_dnafrag}}, [ $targ_from, $targ_to, $targ_strand, $score, $anc_org ]);
	}
        close($out_fh);

        $self->stop_server if $self->param('with_server');

        if ($self->param('retry')) {
            $self->warning('did '.$self->param('retry').' attempts');
        }

        # Since exonerate-server seems to be missing some hits, we fallback
        # to a standard exonerate alignment when a hit is missing
        foreach my $anchor_id (@{$self->param('all_anchor_ids')}) {
            unless ($hits and $hits->{$anchor_id}) {
                $self->dataflow_output_id( { 'anchor_id' => $anchor_id }, 3);
            }
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
    my $netstat_output = `netstat -nt4 | tail -n+3 | awk '{print \$4}' | cut -d: -f2 | sort -nu`;
    my %bad_ports = map {$_ => 1} split(/\n/, $netstat_output);
    my @available_ports = grep {!$bad_ports{$_}} (shuffle 12886..42886);

    # We try one of them
    my $candidate_port = $available_ports[0];
    if ($self->start_server_on_port($candidate_port)) {
        $self->param('target_file', "localhost:$candidate_port");
    } else {
        # If we can't start the server on one port, there is more than 80%
        # chance we'll have to try several more ports. Instead of spending
        # too much time, we just bail out !
        my $retry = $self->param('retry') + 1;
        if ($retry > 20) {
            die "Still failing to start the server after $retry attempts";
        }
        $self->dataflow_output_id( { 'retry' => $retry }, 2);
        $self->input_job->lethal_for_worker(1); # Since the host is not cooperating, we should leave
        $self->complete_early('Port already taken. New job created');
    }
}

sub start_server_on_port {
  my ($self, $port) = @_;

  my $server_exe = $self->param_required('server_exe');
  my $index_file = $self->param_required('index_file');
  my $max_connections = $self->param_required('max_connections');
  my $log_file = $self->param('log_file');
  my $command = "$server_exe $index_file --maxconnections $max_connections --port $port &> $log_file";

  $self->say_with_header("Starting the server: $command");
  my $pid;
  {
    if ($pid = fork) {
      last;
    } elsif (defined $pid) {
      exec("exec $command") == 0 or $self->throw("Failed to run $command: $!");
    }
  }
  $self->param('server_pid', $pid);

  my $cycles = 0;
  while ($cycles < 50) {
      sleep 5;
      # Check if the server has exited
      if (waitpid($pid, WNOHANG)) {
          system('cp', '-a', $log_file, $self->param_required('seq_dump_loc').'/../');
          $self->say_with_header("Server exited by itself (address already in use ?). See log: $log_file");
          return 0;
      }
      $cycles++;
      my $started_message = `tail -1 $log_file`;
      if ($started_message =~ /listening on port/) {
          $self->say_with_header("Server started on port $port");
          return 1;
      } elsif ($started_message =~ /Address already in use/) {
          $self->stop_server;
          $self->say_with_header("Failed to start server: Address already in use");
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

