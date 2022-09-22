#!/usr/bin/env perl
# See the NOTICE file distributed with this work for additional information
# regarding copyright ownership.
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
use Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf;
use Bio::EnsEMBL::Compara::Utils::JIRA;
use Getopt::Long;
use POSIX;
use List::Util qw(sum);
use Number::Format 'format_number';

my $max_jobs = 2000000; # max 2 million rows allowed in job table

my @intervals_in_mbp = (
	[0, 5, 0.01],
	[5, 10, 0.05],
	[10, 25, 0.1],
	[25, 500, 0.25],
	[500, 1000000, 0.95],
);

my $method_link = 'LASTZ_NET';
my $index = 1;

my ( $help, $reg_conf, $master_db, $release, $include_mlss_ids, $exclude_mlss_ids, $exclude_mlss_ids_file, $jira_off, $dry_run );
my ( $verbose, $very_verbose );
$jira_off = 0;
$dry_run = 0;
GetOptions(
    "help"               => \$help,
    "reg_conf=s"         => \$reg_conf,
    "master_db=s"        => \$master_db,
    "release=i"          => \$release,
    "max_jobs=i"         => \$max_jobs,
    'include_mlss_ids=s' => \$include_mlss_ids,
    'exclude_mlss_ids=s' => \$exclude_mlss_ids,
    'exclude_mlss_ids_file=s' => \$exclude_mlss_ids_file,
    'method_link=s'      => \$method_link,
    'start_index=i'      => \$index,
    'jira_off|jira-off!' => \$jira_off,
    'dry_run|dry-run!'   => \$dry_run,
    'v|verbose!'         => \$verbose,
    'vv|very_verbose!'   => \$very_verbose,
);

die "WARNING: this script is not tailored for $method_link yet\n" if ($method_link ne 'LASTZ_NET');

$release = $ENV{CURR_ENSEMBL_RELEASE} unless $release;
die &helptext if ( $help || ($reg_conf && !$master_db) || !$master_db );

my $registry = 'Bio::EnsEMBL::Registry';
$registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing") if $reg_conf;
my $dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $master_db );

# fetch the newest method_link MLSSs
print STDERR "Fetching current $method_link MethodLinkSpeciesSets from the database..\n";
my $mlss_adaptor = $dba->get_MethodLinkSpeciesSetAdaptor();
my $all_lastz_mlsses = $mlss_adaptor->fetch_all_by_method_link_type($method_link);

my %mlss_ids_to_include;
if (defined $include_mlss_ids) {
    %mlss_ids_to_include = map {$_ => 1} split(/[\s,]+/, $include_mlss_ids);
}

my %mlss_ids_to_exclude;
if (defined $exclude_mlss_ids) {
    if (defined $exclude_mlss_ids_file) {
        die "Options '--exclude_mlss_ids' and '--exclude_mlss_ids_file' are mutually exclusive - please choose one.";
    }
    %mlss_ids_to_exclude = map {$_ => 1} split(/[\s,]+/, $exclude_mlss_ids);
} elsif (defined $exclude_mlss_ids_file) {
    open(my $fh, '<', $exclude_mlss_ids_file) or die("Could not open file [$exclude_mlss_ids_file]");
    chomp(my @exclude_mlss_ids_list = <$fh>);
    %mlss_ids_to_exclude = map {$_ => 1} @exclude_mlss_ids_list;
    close($fh) or die("Could not close file [$exclude_mlss_ids_file]");
}

my (@current_lastz_mlsses, %genome_dbs);
foreach my $this_mlss ( @$all_lastz_mlsses ) {
    if ((($this_mlss->first_release || 0) == $release)
        || $mlss_ids_to_include{$this_mlss->dbID}
        || (defined $this_mlss->get_tagvalue("rerun_in_$release"))) {
		next if exists $mlss_ids_to_exclude{$this_mlss->dbID} && $mlss_ids_to_exclude{$this_mlss->dbID};
		push @current_lastz_mlsses, $this_mlss;
		foreach my $this_gdb ( @{ $this_mlss->species_set->genome_dbs } ) {
			$genome_dbs{$this_gdb->dbID} = $this_gdb;
		}
	}
}
print STDERR "Found " . scalar(@current_lastz_mlsses) . "!\n\n";

# calculate number of jobs per-mlss
print STDERR "Estimating number of jobs for each method_link_species_set..\n";
my (%mlss_job_count, %chunk_counts, %chain_job_count, %dnafrag_interval_counts, %nets_job_count);
foreach my $mlss ( @current_lastz_mlsses ) {
    my @mlss_gdbs = $mlss->find_pairwise_reference;
    my ($ref_chunk_count, $non_ref_chunk_count, $filter_dups_job_count);
    if (scalar(@mlss_gdbs) == 1) {
        # Self-alignment

        # everything other than human now uses group_set_size, so is
        # chunked like non-reference
        $ref_chunk_count = $mlss_gdbs[0]->name eq 'homo_sapiens' ? get_ref_chunk_count($mlss_gdbs[0]) : get_non_ref_chunk_count($mlss_gdbs[0]);
        $non_ref_chunk_count = get_non_ref_chunk_count($mlss_gdbs[0]);

        if ($mlss_gdbs[0]->is_polyploid) {
            my $num_components = scalar(@{$mlss_gdbs[0]->component_genome_dbs});
            $filter_dups_job_count = $ref_chunk_count * ($num_components - 1);
        } else {
            $filter_dups_job_count = $ref_chunk_count * 2;
        }
    } else {
        # everything other than human now uses group_set_size, so is
        # chunked like non-reference
        $ref_chunk_count = $mlss_gdbs[0]->name eq 'homo_sapiens' ? get_ref_chunk_count($mlss_gdbs[0]) : get_non_ref_chunk_count($mlss_gdbs[0]);
        $non_ref_chunk_count = get_non_ref_chunk_count($mlss_gdbs[1]);

        # For polyploid PWAs of the same genus, this makes an overestimate as
        # they will not share all the components
        $filter_dups_job_count = $ref_chunk_count + get_ref_chunk_count($mlss_gdbs[1]);
    }
    # Only non-polyploid self-alignments do not produce chain or net jobs
    if ((scalar(@mlss_gdbs) > 1) || $mlss_gdbs[0]->is_polyploid) {
        my $chains_job_count = chains_job_count( $mlss );
        $mlss_job_count{$mlss->dbID}->{analysis}->{aln_chains} = $chains_job_count;
        $mlss_job_count{$mlss->dbID}->{analysis}->{aln_nets} = nets_job_count($mlss_gdbs[0]);
    }
	my $lastz_job_count = ($ref_chunk_count * $non_ref_chunk_count);
    $mlss_job_count{$mlss->dbID}->{analysis}->{lastz} = $lastz_job_count;
    $mlss_job_count{$mlss->dbID}->{analysis}->{filter_dups} = $filter_dups_job_count;
    # dump_large_nib_for_chains and coding_exon_stats are usually around the same value
    $mlss_job_count{$mlss->dbID}->{analysis}->{dump_nibs} = $filter_dups_job_count;
    $mlss_job_count{$mlss->dbID}->{analysis}->{exon_stats} = $filter_dups_job_count;

    $mlss_job_count{$mlss->dbID}->{all} = sum(values %{ $mlss_job_count{$mlss->dbID}->{analysis} });

	print_verbose_summary(\%mlss_job_count, $mlss) if ($verbose);
	print_very_verbose_summary(\%mlss_job_count, $mlss) if ($very_verbose);
}

print STDERR "Splitting method_link_species_sets into groups (max jobs per group: $max_jobs)..\n";
my $mlss_groups = split_mlsses(\%mlss_job_count);
# print "\n\n\nMLSS GROUPS: \n";
# print Dumper $mlss_groups;

# Get the division from the given master database
my $division = $dba->get_division();
my $division_pkg_name = Bio::EnsEMBL::Compara::PipeConfig::ComparaGeneric_conf->get_division_package_name($division);

my ($jira_adaptor, %ticket_tmpl);
unless ($jira_off) {
    # Get a new Utils::JIRA object to create the tickets for the given division and
    # release
    $jira_adaptor = new Bio::EnsEMBL::Compara::Utils::JIRA(-DIVISION => $division, -RELEASE => $release);
    # Get the parent JIRA ticket key, i.e. the production pipelines JIRA ticket for
    # the given division and release
    my $jql = 'labels=Production_anchor';
    my $existing_tickets = $jira_adaptor->fetch_tickets($jql);
    # Check that we have actually found the ticket (and only one)
    die 'Cannot find any ticket with the label "Production_anchor"' if (! $existing_tickets->{total});
    die 'Found more than one ticket with the label "Production_anchor"' if ($existing_tickets->{total} > 1);
    my $jira_prod_key = $existing_tickets->{issues}->[0]->{key};
    # Create the subtask JIRA ticket template
    %ticket_tmpl = (
        'parent'        => $jira_prod_key,
        'name_on_graph' => 'LastZ',
        'components'    => ['Pairwise pipeline', 'Production tasks']
    );
}
# Generate the command line of each batch and build its corresponding ticket
my ( @cmd_list, $ticket_list );
foreach my $group ( @$mlss_groups ) {
    my $this_mlss_list = '"[' . join(',', @{$group->{mlss_ids}}) . ']"';
    my $cmd = "ibsub init_pipeline.pl Bio::EnsEMBL::Compara::PipeConfig::${division_pkg_name}::Lastz_conf -mlss_id_list $this_mlss_list -pipeline_name ${division}_lastz_batch${index}_${release} -host mysql-ens-compara-prod-X -port XXXX";
    push @cmd_list, $cmd;
    unless ($jira_off) {
        # Copy the template and add the specific details for this group
        my $ticket = { %ticket_tmpl };
        $ticket->{'summary'} = "LastZ batch $index";
        $ticket->{'description'} = sprintf("{code:bash}%s{code}", $cmd);
        push @$ticket_list, $ticket;
    }
    $index++;
}
my $subtask_keys;
unless ($jira_off) {
    # Create all JIRA tickets
    $subtask_keys = $jira_adaptor->create_tickets(
        -JSON_OBJ           => $ticket_list,
        -DEFAULT_ISSUE_TYPE => 'Sub-task',
        -DRY_RUN            => $dry_run
    );
}
# Finally, print each batch command line
print "\nPipeline commands:\n------------------\n";
for my $i (0 .. $#cmd_list) {
    my $cmd = $cmd_list[$i];
    if ($jira_off) {
        print "$cmd\n";
    } else {
        my $jira_key = $subtask_keys->[$i];
        print "[$jira_key] $cmd\n";
    }
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

sub n_dnafrags_by_interval {
	my $gdb = shift;

	return $dnafrag_interval_counts{$gdb->dbID} if $dnafrag_interval_counts{$gdb->dbID};

	# fetch list of dnafrag lengths for this genome
	my $sql = "select length from dnafrag where genome_db_id = ? and is_reference = 1 order by length asc";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute( $gdb->dbID );
	my $gdb_dnaf_lens = $sth->fetchall_arrayref();
	$sth->finish;

	# partition and count dnafrags
	my $interval_counts;
	foreach my $g_len ( @$gdb_dnaf_lens ) {
		$interval_counts->{ interval_type($g_len->[0]) }++;
	}

	$dnafrag_interval_counts{$gdb->dbID} = $interval_counts;
	return $interval_counts;
}


sub chains_job_count {
	my $mlss = shift;

	return $chain_job_count{$mlss->dbID} if $chain_job_count{$mlss->dbID};

	my ( $gdb1, $gdb2 ) = @{$mlss->species_set->genome_dbs};

	# partition and count dnafrags
	my $paired_interval_counts;
	my $interval_counts1 = n_dnafrags_by_interval( $gdb1 );
	my $interval_counts2 = $gdb2 ? n_dnafrags_by_interval( $gdb2 ) : $interval_counts1;
	foreach my $int1 ( keys %$interval_counts1 ) {
		foreach my $int2 ( keys %$interval_counts2 ) {
			#print "$int1:$int2 -> ", $interval_counts1->{$int1} * $interval_counts2->{$int2}, "\n";
			$paired_interval_counts->{ "$int1;$int2" } += $interval_counts1->{$int1} * $interval_counts2->{$int2};
		}
	}

	# assign probabilities and estimate job numbers
	my $total_count;
	foreach my $type ( keys %$paired_interval_counts ) {
		$total_count += ceil($paired_interval_counts->{$type} * combined_interval_probability( $type ));
	}

	return $total_count;
}

sub interval_type {
	my ( $len ) = @_;

	# print Dumper [$len];

	my $type;
	foreach my $interval ( @intervals_in_mbp ) {
		my ( $this_min, $this_max ) = ( $interval->[0], $interval->[1] );
		$type = "$this_min mb - $this_max mb" if $len > $this_min*1000 and $len <= $this_max*1000;
	}
	return $type;
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


sub nets_job_count {
	my ($genome_db) = @_;

	return $nets_job_count{$genome_db->dbID} if $nets_job_count{$genome_db->dbID};

	my $chunk_size = 500000;
	my $sql = "select sum(ceil(length/$chunk_size)) from dnafrag where genome_db_id = ? and is_reference = 1";
	# print "NETTING_SQL : '$sql' on " . $genome_db->dbID . "\n";
	my $sth = $dba->dbc->prepare($sql);
	$sth->execute($genome_db->dbID);
	my ($count) = $sth->fetchrow_array();
	$nets_job_count{$genome_db->dbID} = $count;
	return $count;
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

sub print_verbose_summary {
    my ($mlss_job_count, $mlss) = @_;

    my $this_mlss_total = $mlss_job_count->{$mlss->dbID}->{all};
    print $mlss->name . " (dbID: " . $mlss->dbID . "):\t$this_mlss_total\n";
}

sub print_very_verbose_summary {
    my ($mlss_job_count, $mlss) = @_;

    print $mlss->name . " (dbID: " . $mlss->dbID . "):\n";
    my $this_mlss_total = $mlss_job_count->{$mlss->dbID}->{all};
    foreach my $logic_name ( keys %{ $mlss_job_count->{$mlss->dbID}->{analysis} } ) {
        my $this_count = $mlss_job_count->{$mlss->dbID}->{analysis}->{$logic_name};
        print "\t$logic_name:\t$this_count\n";
    }
    print "Total:\t$this_mlss_total\n\n";
}

sub helptext {
	my $msg = <<HELPEND;

Usage: batch_lastz.pl --master_db <master url or alias> --release <release number>

Options:
	master_db         : url or registry alias of master db containing the method_link MLSSes (required)
	release           : current release version (required). The standard criteria for choosing which
	                    LASTZ MLSSes to batch are that the 'first_release' attribute of the MLSS matches
	                    the current release, or that a 'rerun_in_XXX' MLSS tag is defined for the MLSS,
	                    (where 'XXX' is the current release).
	reg_conf          : registry config file (required if using alias for master)
	max_jobs          : maximum number of jobs allowed per-database (default: 6,000,000)
	include_mlss_ids  : comma-separated list of MLSS IDs to batch IN ADDITION to those selected
	                    by the standard criteria
	exclude_mlss_ids  : comma-separated list of MLSS IDs to ignore (e.g. if they've already been run).
	exclude_mlss_ids_file : text file listing MLSS IDs (one per line) which should be ignored
	method_link       : method used to select MLSSes (default: LASTZ_NET)
	start_index       : number to assign to the first batch (default: 1)
	jira_off|jira-off : do not submit JIRA tickets to the JIRA server (default: tickets are submitted)
	dry_run|dry-run   : in dry-run mode, the JIRA tickets will not be submitted to the JIRA
	                    server (default: off)
	v|verbose         : print out per-mlss job count estimates
	vv|very_verbose   : print out per-analysis, per-mlss job count estimates

HELPEND
	return $msg;
}
