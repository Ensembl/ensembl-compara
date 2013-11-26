=head1 LICENSE

Copyright [1999-2013] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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

Email dev@ensembl.org

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::FindStrand;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::SearchIO;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	# add the dbs that are on non-standard servers
        foreach my $additional_species_db(@{ $self->param('other_core_dbs') }){ 
                my $additional_species_dba = Bio::EnsEMBL::DBSQL::DBAdaptor->new(%{ $additional_species_db }); 
                Bio::EnsEMBL::Registry->add_DBAdaptor( $additional_species_db->{'-species'}, "core", $additional_species_dba );  
        }   

	Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( @{ $self->param('main_core_dbs') } );
	my ($query_set, $target_set, $q_files, $t_files, $blastResults, $matches, $query_index);
	my $synteny_region_id = $self->param('zero_st_dnafrag_region_id');
	my $sth1 = $self->dbc->prepare("SELECT df.coord_system_name, dfr.dnafrag_id, df.name, gdb.name, dfr.dnafrag_start, dfr.dnafrag_end, dfr.dnafrag_strand FROM ". 
			"dnafrag_region dfr INNER JOIN dnafrag df ON df.dnafrag_id = dfr.dnafrag_id INNER JOIN genome_db gdb ON gdb.genome_db_id = ".
			"df.genome_db_id WHERE dfr.synteny_region_id = ?");
	$sth1->execute($synteny_region_id);
	my ($z,$query_offset)=(0,0);
	while( my $dnafrag_data = $sth1->fetchrow_arrayref ){
		my($coord_sys, $dnafrag_id, $dnafrag_name, $species_name, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = @{ $dnafrag_data };
		my $slice_a = Bio::EnsEMBL::Registry->get_adaptor("$species_name", "core", "Slice");
		if($dnafrag_strand){
			my $slice = $slice_a->fetch_by_region( "$coord_sys", "$dnafrag_name", $dnafrag_start, $dnafrag_end, $dnafrag_strand);	
			push(@$target_set, [ $dnafrag_id, $dnafrag_start, $dnafrag_end, $slice, $dnafrag_strand ]); 
		} else {
			my $slice = $slice_a->fetch_by_region( "$coord_sys", "$dnafrag_name", $dnafrag_start, $dnafrag_end, 1);
			push(@$query_set, [ $dnafrag_id, $dnafrag_start, $dnafrag_end, $slice ]);
			eval { $query_index->{ $slice->name } = $z++ };
			if($@){
				print $@, join(":", $coord_sys, $dnafrag_id, $dnafrag_name, $species_name, $dnafrag_start, $dnafrag_end, $dnafrag_strand), "\n";
			}
		}
	}
	# if all the sequences have 0 strand, use the first one as the target
	unless(ref($target_set)){
		@$target_set = splice(@$query_set,0,1);
		push(@{ $target_set->[0] }, 1);
		$query_offset--;
	}
	my $file_root = $self->param('bl2seq_file') . ".$synteny_region_id.";
	($q_files, $t_files) = write_files($query_set, $target_set, $file_root);
	foreach my $query_file (@$q_files) {
		foreach my $target_file (@$t_files) {
			my $command = $self->param('bl2seq') . " -i $query_file -j $target_file -p blastn";
			my $bl2seq_fh;
			open($bl2seq_fh, "$command |") or throw("Error opening command: $command"); # run the command
			# parse_bl2seq returns a hashref of the scores and the number of hits to each query strand
			push(@$blastResults, parse_bl2seq($bl2seq_fh));
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
	foreach my $blast_file(@$q_files, @$t_files){
		unlink($blast_file) or die "cant remove file: $blast_file\n";	
	}
}

sub write_output {
	my ($self) = @_;
	foreach my $dnafrag_regions (@{ $self->param('dnafrag_regions_strands') }) {
		my ($synt_region_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand) = @$dnafrag_regions;
		my $sth = $self->dbc->prepare("UPDATE dnafrag_region SET dnafrag_strand = ? WHERE synteny_region_id = $synt_region_id " .
				"AND dnafrag_id = $dnafrag_id AND dnafrag_start = $dnafrag_start AND dnafrag_end = $dnafrag_end");
		$sth->execute($dnafrag_strand);
	}
}

sub write_files {
        my ($queries, $targets, $file_root) = @_; 
        my ($q_fh, $t_fh);
        foreach my $this_query (@$queries) {
                push(@$q_fh, print_to_file($this_query, "Q", $file_root));
        }   
        foreach my $this_target (@$targets) {
                push(@$t_fh, print_to_file($this_target, "T", $file_root));
        }   
        return($q_fh, $t_fh);
}

sub print_to_file {
        my($slice_info, $type, $file_root) = @_; 
	my $file_name = $file_root . join("_", @{ $slice_info }[0..2] ) . ".$type";
	my $slice = $slice_info->[3]; 
	my $seq = $slice->seq;
	# format the sequence 
	$seq =~ s/(.{60})/$1\n/g;
	open(FH, ">>$file_name") or die "cant open $file_name";
	print FH ">" . $slice->name . "\n$seq";
	return $file_name;
}

sub parse_bl2seq {
	my $file2parse = shift;
	my $hits;
	local $/ = "\n";
	my $blast_io = new Bio::SearchIO(-format => 'blast', -fh => $file2parse);
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

