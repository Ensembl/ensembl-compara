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

# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::FindStrand

=head1 SYNOPSIS

$self->fetch_input();
$self->run();
$self->write_output(); writes to database

=head1 DESCRIPTION

this module finds the strand of the dnafrag_region rows taken from the enredo output file, 
where those dnafrag_regions have been designated 0 by enredo. It uses bl2seq to work out the strand.

=head1 AUTHOR - compara

This modules is part of the Ensembl project http://www.ensembl.org

Email http://lists.ensembl.org/mailman/listinfo/dev

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
http://lists.ensembl.org/mailman/listinfo/dev


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut

package Bio::EnsEMBL::Compara::Production::EPOanchors::FindDfrStrand;

use strict;
use warnings;
no warnings "uninitialized";

use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::SearchIO;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my ($query_set, $target_set, $q_files, $t_files, $blastResults, $matches, $query_index);
	my $synteny_region_id = $self->param('zero_st_synteny_region_id');
	print $synteny_region_id, " ***********\n" if $self->debug;

	my $sth1 = $self->dbc->prepare("SELECT df.coord_system_name, dfr.dnafrag_id, df.name, gdb.name, dfr.dnafrag_start, ".
			"dfr.dnafrag_end, dfr.dnafrag_strand FROM dnafrag_region dfr INNER JOIN dnafrag df ON df.dnafrag_id = ".
			"dfr.dnafrag_id INNER JOIN genome_db gdb ON gdb.genome_db_id = df.genome_db_id WHERE dfr.synteny_region_id = ?");
	$sth1->execute($synteny_region_id);
	my ($z,$query_offset)=(0,0);
	while( my $dnafrag_data = $sth1->fetchrow_arrayref ){
		my($coord_sys, $dnafrag_id, $dnafrag_name, $species_name, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = @{ $dnafrag_data };
		my $dnafrag_obj = $self->compara_dba()->get_adaptor("DnaFrag")->fetch_by_dbID($dnafrag_id);
            $dnafrag_obj->genome_db->db_adaptor->dbc->prevent_disconnect( sub {
		if($dnafrag_strand){
			my $slice = $dnafrag_obj->slice()->sub_Slice($dnafrag_start, $dnafrag_end, $dnafrag_strand);
                        $slice->{'seq'} = $slice->seq;
			push(@$target_set, [ $dnafrag_id, $dnafrag_start, $dnafrag_end, $slice, $dnafrag_strand ]); 
		} else {
			my $slice = $dnafrag_obj->slice()->sub_Slice($dnafrag_start, $dnafrag_end, 1);
                        $slice->{'seq'} = $slice->seq;
			push(@$query_set, [ $dnafrag_id, $dnafrag_start, $dnafrag_end, $slice ]);
			eval { $query_index->{ $slice->name } = $z++ };
			if($@){
				print $@, join(":", $coord_sys, $dnafrag_id, $dnafrag_name, $species_name, $dnafrag_start, $dnafrag_end, $dnafrag_strand), "\n";
			}
		}
            } );
	}
	# if all the sequences have 0 strand, use the first one as the target
	unless(ref($target_set)){
		@$target_set = splice(@$query_set,0,1);
		push(@{ $target_set->[0] }, 1);
		$query_offset--;
	}
	my $file_stem = $self->param('bl2seq_file') . ".$synteny_region_id.";
	($q_files, $t_files) = $self->write_files($query_set, $target_set, $file_stem);
	foreach my $query_file (@$q_files) {
		foreach my $target_file (@$t_files) {
			my $command = $self->_bl2seq_command( $query_file, $target_file );
			my $bl2seq_fh;
			open($bl2seq_fh, "$command |") or throw("Error opening command: $command"); # run the command
			# parse_bl2seq returns a hashref of the scores and the number of hits to each query strand
			push(@$blastResults, $self->parse_bl2seq($bl2seq_fh));
		}   
	} 
	foreach my $this_result ( @$blastResults ) {
		foreach my $query_name ( sort keys %$this_result ) {
			foreach my $target_name ( sort keys %{ $this_result->{ $query_name } }) {
				foreach my $strand (sort keys %{ $this_result->{ $query_name }{ $target_name } } ) {
					foreach my $num_of_results (sort keys %{ $this_result->{ $query_name }{ $target_name }{ $strand } } ) {
						# get an average score for each query strand
						$matches->{ $query_name }{ $strand } +=
						$this_result->{ $query_name }{ $target_name }{ $strand }{ $num_of_results } / $num_of_results;
					}
				}
			}
		}
	}
	# set the query strand to -1 or 1 depending on the average score from the blast results
	if( keys %$matches) {
		foreach my $query_name ( sort keys %{ $query_index } ) {
			push(@{ $query_set->[ $query_index->{ $query_name } + $query_offset ] }, 
				$matches->{ $query_name }{ "1" } > $matches->{ $query_name }{ "-1" } ? 1 : -1);
		}
	}
	my $dnafrag_region_strands;
	foreach my $dnafrag_region_res(@$query_set, @$target_set){
		push(@$dnafrag_region_strands, [ $synteny_region_id, @{ $dnafrag_region_res }[0,1,2,4] ]);
	}

	$self->param('dnafrag_regions_strands', $dnafrag_region_strands);
# uncomment lines below if you want to remove the bl2seq input files
#	foreach my $blast_file(@$q_files, @$t_files){
#		unlink($blast_file) or die "cant remove file: $blast_file\n";	
#	}
}


#
# bl2seq is kind of deprecated. functionality has been rolled into blastn. (https://www.biostars.org/p/17580/)
# we will continue to support bl2seq as well as new blastn command for legacy reasons.
# adjust the command depending on whether bl2seq_exe or blastn_exe is defined (preference for bl2seq)
#

sub _bl2seq_command {
	my ($self, $query_file, $target_file) = @_;

	my $command;
	if ( defined $self->param('bl2seq_exe') ) {
		$command = $self->param('bl2seq') . " -i $query_file -j $target_file -p blastn";
	} elsif ( defined $self->param('blastn_exe') ) {
		$command = $self->param('blastn_exe') . " -query $query_file -subject $target_file -outfmt 6";
	} else {
		die "'bl2seq_exe' or 'blastn_exe' must be defined!\n";
	}

	print " --- BL2SEQ CMD : $command\n" if $self->debug;

	return $command;
}

sub write_output {
	my ($self) = @_;
	my ($synt_region_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand);
	
	foreach my $dnafrag_regions (@{ $self->param('dnafrag_regions_strands') }) {
		($synt_region_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = @$dnafrag_regions;
		my $sql = "UPDATE dnafrag_region SET dnafrag_strand = $dnafrag_strand WHERE synteny_region_id = $synt_region_id " .
				"AND dnafrag_id = $dnafrag_id AND dnafrag_start = $dnafrag_start AND dnafrag_end = $dnafrag_end";
		my $sth = $self->dbc->prepare($sql);
		print " --- SQL : $sql\n" if $self->debug;
		# print " --- DNAFRAG : $dnafrag_strand\n" if $self->debug;
		$sth->execute();
	}
	$self->dataflow_output_id( [ { synteny_region_id => $synt_region_id } ], 2 ); # flow to a job factory to set up ortheus
}

sub write_files {
        my ($self, $queries, $targets, $file_stem) = @_;
        my ($q_fh, $t_fh);
        foreach my $this_query (@$queries) {
                push(@$q_fh, $self->print_to_file($this_query, "Q", $file_stem));
        }   
        foreach my $this_target (@$targets) {
                push(@$t_fh, $self->print_to_file($this_target, "T", $file_stem));
        }   
        return($q_fh, $t_fh);
}

sub print_to_file {
    my($self, $slice_info, $type, $file_stem) = @_;
	my $file_name = $file_stem . join("_", @{ $slice_info }[0..2] ) . ".$type";
	my $slice = $slice_info->[3]; 
	my $seq = $slice->seq;
	# format the sequence 
	$seq =~ s/(.{60})/$1\n/g;
	$self->_spurt($file_name, ">" . $slice->name . "\n$seq", 'append');
	return $file_name;
}

sub parse_bl2seq {
	my ($self, $file2parse) = @_;
	my $hits;
	local $/ = "\n";

	# die gracefully if blast file is empty
	if ( -z $file2parse ) {
		$self->dataflow_output_id(undef, $self->param('escape_branch'));
		$self->input_job->autoflow(0);
		$self->complete_early( "No blast results found - skipping" );
	}

	# parser was not playing nice with blastn output format
	# use tabular output if using blastn
	my $blast_fmt = ( defined $self->param('blastn_exe') ) ? 'blasttable' : 'blast';
	print " --- BLAST_FMT : $blast_fmt\n" if $self->debug;

	my $blast_io = new Bio::SearchIO(-format => $blast_fmt, -fh => $file2parse);
	my $count;
	while( my $result = $blast_io->next_result ) {
		while( my $hit = $result->next_hit ) {
			while( my $hsp = $hit->next_hsp ) {
				$hits->{ $result->query_name }{ $hit->name }{ $hsp->strand('hit') }{ ++$count } += $hsp->score;
			}
		}
	}

	return $hits;
}

1;

