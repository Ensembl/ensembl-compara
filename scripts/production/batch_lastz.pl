#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


use warnings;
use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Getopt::Long;
use POSIX;
use List::Util qw(sum);
use Number::Format 'format_number';

use Data::Dumper;
$Data::Dumper::Maxdepth=4;

my $max_jobs = 6000000; # max 6 million rows allowed in job table

my @intervals_in_mbp = (
	[0, 5, 0.01],
	[5, 10, 0.05],
	[10, 25, 0.1],
	[25, 500, 0.25],
	[500, 1000000, 0.95],
);


my ( $help, $reg_conf, $master_db, $release );
GetOptions(
    "help"          => \$help,
    "reg_conf=s"    => \$reg_conf,
    "master_db=s"   => \$master_db,
    "release=i"     => \$release,
    "max_jobs=i"    => \$max_jobs,
);

$release = $ENV{CURR_ENSEMBL_RELEASE} unless $release;
die &helptext if ( $help || ($reg_conf && !$master_db) || !$master_db );

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;
my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $master_db );

# fetch the newest LASTZs and the full list of genome dbs
my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor();
my $all_lastz_mlsses = $mlss_adaptor->fetch_all_by_method_link_type("LASTZ_NET");
my (@current_lastz_mlsses, %genome_dbs);
foreach my $this_mlss ( @$all_lastz_mlsses ) {
	if (($this_mlss->first_release || 0) == $release) {
		push @current_lastz_mlsses, $this_mlss;
		foreach my $this_gdb ( @{ $this_mlss->species_set->genome_dbs } ) {
			$genome_dbs{$this_gdb->dbID} = $this_gdb;
		}
	}
}

# calculate number of jobs per-mlss
print STDERR "Estimating number of jobs for each method_link_species_set..\n";
my (%mlss_job_count, %total_job_count, %chunk_counts, %chain_dnafrag_counts, %chain_job_count);
foreach my $mlss ( @current_lastz_mlsses ) {
	my $ref_name = $mlss->get_tagvalue('reference_species');
	my $mlss_gdbs = $mlss->species_set->genome_dbs;
	my ( $ref_chunk_count, $non_ref_chunk_count );
	if ( $mlss_gdbs->[0]->name eq $ref_name ) {
		$ref_chunk_count = get_ref_chunk_count($mlss_gdbs->[0]);
		$non_ref_chunk_count = get_non_ref_chunk_count($mlss_gdbs->[1]);
	} else {
		$ref_chunk_count = get_ref_chunk_count($mlss_gdbs->[1]);
		$non_ref_chunk_count = get_non_ref_chunk_count($mlss_gdbs->[0]);
	}

	my $lastz_job_count = ($ref_chunk_count * $non_ref_chunk_count);
	$mlss_job_count{$mlss->dbID}->{lastz} = $lastz_job_count;
	$total_job_count{lastz} += $lastz_job_count;

	my $filter_dups_job_count = get_ref_chunk_count($mlss_gdbs->[0]) + get_ref_chunk_count($mlss_gdbs->[1]);
	$mlss_job_count{$mlss->dbID}->{filter_dups} = $filter_dups_job_count;
	$total_job_count{filter_dups} += $filter_dups_job_count;
	# dump_large_nib_for_chains and coding_exon_stats are usually around the same value
	$mlss_job_count{$mlss->dbID}->{dump_nibs} = $filter_dups_job_count;
	$total_job_count{dump_nibs} += $filter_dups_job_count;
	$mlss_job_count{$mlss->dbID}->{exon_stats} = $filter_dups_job_count;
	$total_job_count{exon_stats} += $filter_dups_job_count;

	# my ( $dnaf_count_1, $dnaf_count_2 ) = (chains_dnafrag_count($mlss_gdbs->[0]), chains_dnafrag_count($mlss_gdbs->[1]));
	# my ( $gdb_name_1, $gdb_name_2 ) = ( $mlss_gdbs->[0]->name, $mlss_gdbs->[1]->name );
	# print "dnaf_count $gdb_name_1: $dnaf_count_1; dnaf_count $gdb_name_2: $dnaf_count_2\n";
	# my $chains_job_count = $dnaf_count_1 * $dnaf_count_2;
	my $chains_job_count = chains_job_count( $mlss );
	# my $chains_job_count = ceil($lastz_job_count/3); # generally, this is ~0.3333 of LastZ jobs
	$mlss_job_count{$mlss->dbID}->{aln_chains} = $chains_job_count;
	$total_job_count{aln_chains} += $chains_job_count;
	$mlss_job_count{$mlss->dbID}->{aln_nets} = ceil($chains_job_count/2);
	$total_job_count{aln_nets} += ceil($chains_job_count/2); # alignment_nets = ~ half chain jobs
	

}

foreach my $k ( keys %mlss_job_count ) {
	$mlss_job_count{$k}->{all} = sum(values %{ $mlss_job_count{$k} });
}

# print "\n\n\nMLSS JOB COUNT: \n";
# print Dumper \%mlss_job_count;
# print "\nTOTAL JOB COUNT: \n";
# print Dumper \%total_job_count;
# print "total total : " . format_number(sum(values %total_job_count)) . "\n";

print STDERR "Splitting method_link_species_sets into groups (max jobs per group: $max_jobs)..\n";
my $mlss_groups = split_mlsses(\%mlss_job_count);
print "\n\n\nMLSS GROUPS: \n";
print Dumper $mlss_groups;

print "\nPipeline commands:\n";
foreach my $group ( @$mlss_groups ) {
	my $this_mlss_list = '"[' . join(',', @{$group->{mlss_ids}}) . ']"';
	print "init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::EBI::Ensembl::Lastz_conf -reg_conf \$ENSEMBL_CVS_ROOT_DIR/ensembl-compara/scripts/pipeline/production_reg_eg_conf.pl -master_db $master_db  -mlss_id_list $this_mlss_list -host mysql-ens-compara-prod-X -port XXXX\n";
}

sub helptext {
	my $msg = <<HELPEND;

Usage: batch_lastz.pl --master_db <master url or alias> --release <release number>

Options:
	master_db : url or registry alias of master db containing LASTZ MLSSes
	release   : current release version
	reg_conf  : registry config file (required if using alias for master)
	max_jobs  : maximum number of jobs allowed per-database (default: 6,000,000)

HELPEND
	return $msg;
}

sub get_ref_chunk_count {
	my ($genome_db) = @_;

	return $chunk_counts{$genome_db->dbID}->{ref} if $chunk_counts{$genome_db->dbID}->{ref};

	my $chunk_size = $genome_db->name eq 'homo_sapiens' ? 30000000 : 10000000;
	my $sql = "select sum(ceil(length/$chunk_size)) from dnafrag where genome_db_id = ? and is_reference = 1";
	# print "REF_CHUNK_SQL : '$sql' on " . $genome_db->dbID . "\n";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute($genome_db->dbID);
	my ($count) = $sth->fetchrow_array();
	$chunk_counts{$genome_db->dbID}->{ref} = $count;
	return $count;
}

sub get_non_ref_chunk_count {
	my ($genome_db) = @_;

	return $chunk_counts{$genome_db->dbID}->{non_ref} if $chunk_counts{$genome_db->dbID}->{non_ref};

	my ($chunk_size, $overlap) = (10100000, 100000);
	my $sql = "select ceil(sum(length/($chunk_size-$overlap))) from dnafrag where genome_db_id = ?";
	# print "NON_REF_CHUNK_SQL : '$sql' on " . $genome_db->dbID . "\n";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute($genome_db->dbID);
	my ($count) = $sth->fetchrow_array();
	my $expanded_count = ceil($count * 1.2); # add an extra 20% since predicting grouping is tricky
	$chunk_counts{$genome_db->dbID}->{non_ref} = $expanded_count;
	# print "$count expands to $expanded_count\n";
	return $expanded_count;
}

sub chains_job_count {
	my $mlss = shift;

	return $chain_job_count{$mlss->dbID} if $chain_job_count{$mlss->dbID};

	my ( $gdb1, $gdb2 ) = @{$mlss->species_set->genome_dbs};

	# fetch list of dnafrag lengths for each genome
	my $sql = "select length from dnafrag where genome_db_id = ? and is_reference = 1 order by length asc";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute( $gdb1->dbID );
	my $gdb1_dnaf_lens = $sth->fetchall_arrayref();
	$sth->execute( $gdb2->dbID );
	my $gdb2_dnaf_lens = $sth->fetchall_arrayref();

	# partition and count dnafrags
	my $interval_counts;
	foreach my $g1_len ( @$gdb1_dnaf_lens ) {
		foreach my $g2_len ( @$gdb2_dnaf_lens ) {
			$interval_counts->{ interval_type($g1_len->[0], $g2_len->[0]) }++;
		}
	}

	# assign probabilities and estimate job numbers
	my $total_count;
	foreach my $type ( keys %$interval_counts ) {
		$total_count += ceil($interval_counts->{$type} * combined_interval_probability( $type ));
	}

	return $total_count;
}

sub interval_type {
	my ( $len1, $len2 ) = @_;

	# print Dumper [$len1, $len2];

	my ($type1, $type2);
	foreach my $interval ( @intervals_in_mbp ) {
		my ( $this_min, $this_max ) = ( $interval->[0], $interval->[1] );
		$type1 = "$this_min mb - $this_max mb" if $len1 > $this_min*1000 and $len1 <= $this_max*1000;
		$type2 = "$this_min mb - $this_max mb" if $len2 > $this_min*1000 and $len2 <= $this_max*1000;
	}
	return "$type1;$type2";
}

sub combined_interval_probability {
	my $type = shift;

	my ( $t1, $t2 ) = split(';', $type);
	my ( $t1_min, $t1_max ) = split(/[\s\-mb]+/, $t1);
	my ( $t2_min, $t2_max ) = split(/[\s\-mb]+/, $t2);

	my ( $t1_prob, $t2_prob ) = (0, 0);
	foreach my $interval ( @intervals_in_mbp ) {
		$t1_prob = $interval->[2] if $interval->[0] == $t1_min;
		$t2_prob = $interval->[2] if $interval->[0] == $t2_min;		
	}

	# print "t1_prob = $t1_prob ; t2_prob = $t2_prob\n";

	return $t1_prob*$t2_prob;
}


sub split_mlsses {
	my $mlss_job_count_full = shift;

	# first, filter out any mlsses that exceed the job limit by themselves
	# as these throw off the grouping and they end up uneven
	my ($mlss_job_count, @large_mlss_groups);
	foreach my $k ( keys %$mlss_job_count_full ) {
		if ( $mlss_job_count_full->{$k}->{all} > $max_jobs ) {
			warn "\n** WARNING: MethodLinkSpeciesSet $k exceeds the max_jobs threshold alone **\n";
			push( @large_mlss_groups, { mlss_ids => [$k], job_count => $mlss_job_count_full->{$k}->{all} } );
		} else {
			$mlss_job_count->{$k} = $mlss_job_count_full->{$k};
		}
	}

	# sort ids on number of jobs in desc order as
	# we will want to allocate the largest ones first
	my @sorted_mlss_ids = sort { $mlss_job_count->{$b}->{all} <=> $mlss_job_count->{$a}->{all} } keys %$mlss_job_count;

	# break into nice sets and output mlss id lists with init_pipeline cmds
	# first, guess how many pipelines we'll need
	my $total_jobs = sum(map { $mlss_job_count->{$_}->{all} } keys %$mlss_job_count);
	my $pipelines_required = ceil($total_jobs/$max_jobs);

	# next, split mlsses across the pipelines
	my (@mlss_groups, %reincluded_mlsses);
	my ($continue, $x) = (1, 0);
	while( $continue ) {
		my $pipe_idx = $x % $pipelines_required;
		my $this_mlss_id = shift @sorted_mlss_ids;
		# add the mlss so long as we won't exceed the job limit for the group
		my $predicted_jobs = ($mlss_groups[$pipe_idx]->{job_count} || 0) + $mlss_job_count->{$this_mlss_id}->{all};
		if ( $predicted_jobs <= $max_jobs ) {
			push( @{ $mlss_groups[$pipe_idx]->{mlss_ids} }, $this_mlss_id );
			$mlss_groups[$pipe_idx]->{job_count} += $mlss_job_count->{$this_mlss_id}->{all};
		} else { 
			# add clause for cases where they just won't fit
			$reincluded_mlsses{$this_mlss_id} += 1; # keep count of how many times we've tried to allocate
			if ( $reincluded_mlsses{$this_mlss_id} >= $pipelines_required ) { # tried all groups already
				# add a new group
				push( @mlss_groups, { mlss_ids => [$this_mlss_id], job_count => $mlss_job_count->{$this_mlss_id}->{all} } );
			} else {
				# otherwise, add the mlss back to be grouped on the next iteration
				unshift @sorted_mlss_ids, $this_mlss_id;
			}
		}

		$x++;
		$continue = 0 if scalar @sorted_mlss_ids < 1;
	}

	push( @mlss_groups, @large_mlss_groups );

	return \@mlss_groups;
}
