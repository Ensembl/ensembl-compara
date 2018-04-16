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

=pod

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::CreateDumpJobs

=head1 SYNOPSIS

	Detect all new method_link_species_sets and generate dump jobs for each. Also, create a bash script
	to copy all old data from the previous release.

=cut

package Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CreateDumpJobs;

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Data::Dumper;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub param_defaults {
    my $self = shift;
    return {
        %{$self->SUPER::param_defaults},
        'alignment_dump_options' => {
        	EPO              => {format => 'emf+maf'},
        	EPO_LOW_COVERAGE => {format => 'emf+maf'},
        	PECAN            => {format => 'emf+maf'},
        	LASTZ_NET        => {format => 'maf', make_tar_archive => 1},
        },

        # define which method_link_types should be dumpable
        dumpable_method_types => {
        	'LASTZ_NET' => 1, 'EPO' => 1, 'EPO_LOW_COVERAGE' => 1, 'PECAN' => 1,
        	'GERP_CONSTRAINED_ELEMENT' => 1, 'GERP_CONSERVATION_SCORE' => 1,
        },
        
        target_dir => '#dump_dir#',
        # work_dir   => '#dump_dir#/dump_hash',
    };
}

sub fetch_input {
	my $self = shift;

	my $curr_release = $self->param_required('curr_release');

	my $registry = 'Bio::EnsEMBL::Registry';
	$registry->load_all($self->param('reg_conf'), 0, 0, 0, "throw_if_missing") if $self->param('reg_conf');
	my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $self->param_required('compara_db') );

	my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $release_mlsses = $mlssa->fetch_all_by_release($curr_release);

	# first, split new mlsses into categories
	my (%dumps, @copy_jobs);
	foreach my $mlss ( @$release_mlsses ) {
		my $method_class = $mlss->method->class;
		if ( $mlss->first_release == $curr_release ) {
			# new analysis! must be dumped
			if ( $method_class =~ /^GenomicAlign/ ) { # all alignments
				push( @{$dumps{DumpMultiAlign}}, $mlss )
			}
			elsif ( $method_class =~ /tree_node$/ ) { # gene trees
				push( @{$dumps{DumpTrees}}, $mlss );
			}
			elsif ( $method_class =~ /^ConstrainedElement/ ) {
				push( @{$dumps{DumpConstrainedElements}}, $mlss );
			}
			elsif ( $method_class =~ /^ConservationScore/ ) {
				push( @{$dumps{DumpConservationScores}}, $mlss );
			}
		} else {
			# don't flow trees for copying - they are always dumped fresh
			next if $mlss->method->class =~ /tree_node$/;
			# old analysis! can be copied from prev release FTP location
			push( @copy_jobs, $mlss->dbID ) if defined $self->param('dumpable_method_types')->{$mlss->method->type};
		}
	}

	# generate job lists for each dump type
	my %all_dump_jobs;
	$all_dump_jobs{DumpMultiAlign}          = $self->_dump_multialign_jobs( $dumps{DumpMultiAlign} );
	$all_dump_jobs{DumpTrees}               = $self->_dump_trees_jobs( $dumps{DumpTrees} );
	$all_dump_jobs{DumpConstrainedElements} = $self->_dump_constrainedelems_jobs( $dumps{DumpConstrainedElements} );
	$all_dump_jobs{DumpConservationScores}  = $self->_dump_conservationscores_jobs( $dumps{DumpConservationScores} );
	
	# always add these
	$all_dump_jobs{DumpSpeciesTrees}        = $self->_dump_speciestree_job; # doesn't require mlsses
	$all_dump_jobs{DumpAncestralAlleles}    = $self->_dump_anc_allele_jobs; 

	if ( $self->param('lastz_patch_dbs') ) {
		my ( $lastz_patch_jobs, $copy_jobs_no_patches ) = $self->_add_lastz_patches( \@copy_jobs );
		$all_dump_jobs{DumpMultiAlignPatches} = $lastz_patch_jobs;
		@copy_jobs = @$copy_jobs_no_patches;
	}

	$self->param('dump_jobs', \%all_dump_jobs);
	@copy_jobs = sort { $a <=> $b } @copy_jobs;
	$self->param('copy_jobs', \@copy_jobs);
}

sub write_output {
	my $self = shift;

	my $dump_jobs = $self->param('dump_jobs');
	print "TO DUMP: \n";
	print Dumper $dump_jobs;
	$self->dataflow_output_id( $dump_jobs->{DumpMultiAlign}, 1 );
	$self->dataflow_output_id( $dump_jobs->{DumpTrees}, 2 );
	$self->dataflow_output_id( $dump_jobs->{DumpConstrainedElements}, 3 );
	$self->dataflow_output_id( $dump_jobs->{DumpConservationScores},  4 );
	$self->dataflow_output_id( $dump_jobs->{DumpSpeciesTrees}, 5 );
	$self->dataflow_output_id( $dump_jobs->{DumpAncestralAlleles}, 6 );

	if ( $self->param('lastz_patch_dbs') ) {
		$self->dataflow_output_id( $dump_jobs->{DumpMultiAlignPatches}, 7 );
		$self->dataflow_output_id( {}, 8 ); # to patch mlss factory
	}

	my $copy_jobs = $self->param('copy_jobs');
	print "\n\nTO COPY: \n";
	print '(' . join(', ', @$copy_jobs) . ")\n";
	$self->dataflow_output_id( { mlss_ids => $copy_jobs }, 9 );
}

sub _dump_multialign_jobs {
	my ($self, $mlss_list) = @_;
	my %alignment_dump_options = %{$self->param_required('alignment_dump_options')};

	# uniqify the list of method link types
	my %aln_types;
	foreach my $mlss ( @$mlss_list ) {
		$aln_types{$mlss->method->type} = 1;
	}

	my @jobs;
	foreach my $type ( keys %aln_types ) {
		my %this_job = %{ $self->param('default_dump_options')->{DumpMultiAlign} };
		$this_job{method_link_type} = $type;
		foreach my $opt ( keys %{$alignment_dump_options{$type}} ) {
			$this_job{$opt} = $alignment_dump_options{$type}->{$opt};
		}
		push( @jobs, \%this_job );
	}

	return \@jobs;
}

sub _dump_trees_jobs {
	my ($self, $mlss_list) = @_;

	my @jobs;
	# foreach my $mlss ( @$mlss_list ) {
	# 	my ( $member_type, $clusterset_id ) = $self->_member_type_clusterset_from_mlss($mlss);

	# 	# store to a job datastructure
	# 	my %this_job = %{ $self->param('default_dump_options')->{DumpTrees} };
	# 	$this_job{member_type}   = $member_type;
	# 	$this_job{clusterset_id} = $clusterset_id;
	# 	push( @jobs, \%this_job );
	# }
	push( @jobs, $self->param('default_dump_options')->{DumpTrees} );
	return \@jobs;
}

sub _dump_constrainedelems_jobs {
	my ($self, $mlss_list) = @_;

	my @jobs;
	foreach my $mlss ( @$mlss_list ) {
		my %this_job = %{ $self->param('default_dump_options')->{DumpConstrainedElements} };
		$this_job{mlss_id} = $mlss->dbID;

		push( @jobs, \%this_job );
	}

	return \@jobs;
}

sub _dump_conservationscores_jobs {
	my ($self, $mlss_list) = @_;

	my @jobs;
	foreach my $mlss ( @$mlss_list ) {
		my %this_job = %{ $self->param('default_dump_options')->{DumpConservationScores} };
		$this_job{mlss_id} = $mlss->dbID;

		push( @jobs, \%this_job );
	}

	return \@jobs;
}

sub _dump_speciestree_job {
	my $self = shift;

	return $self->param('default_dump_options')->{DumpSpeciesTrees};	
}

sub _dump_anc_allele_jobs {
	my $self = shift;

	return $self->param('default_dump_options')->{DumpAncestralAlleles};
}

sub _member_type_clusterset_from_mlss {
	my ($self, $mlss) = @_;
	my ( $member_type, $clusterset_id );

	# get member_type from method_type
	my $method_type = $mlss->method->type;
	if ( $method_type eq 'PROTEIN_TREES' ) {
		$member_type = 'protein';
	} elsif ( $method_type eq 'NC_TREES' ) {
		$member_type = 'ncrna';
	} else {
		die "Cannot determine tree member type (protein/ncrna) from method_type '$method_type'\n";
	}

	# get clusterset_id from species set name
	$clusterset_id = $mlss->species_set->name;
	$clusterset_id =~ s/collection-//;

	return ( $member_type, $clusterset_id );
}

sub _add_lastz_patches {
	my ($self, $copy_jobs) = @_;

	my (@patch_dump_jobs, %pruned_copy_jobs);
	foreach my $patch_db ( @{$self->param('lastz_patch_dbs')} ) {
		# first, create a DumpMultiAlign job for each db
		my %this_job = %{$self->param('default_dump_options')->{DumpMultiAlign}};
		$this_job{compara_db} = $patch_db;
		$this_job{method_link_type} = 'LASTZ_NET';
		$this_job{format} = 'maf'; # don't add make_tar_archive - will be adding to dir and tarring later
		push( @patch_dump_jobs, \%this_job );

		# remove MLSSes from copy jobs if adding patches
		# don't want to copy directly from prev FTP - need to top up the tar.gz first
		if ($self->param('reg_conf')) {
			my $registry = 'Bio::EnsEMBL::Registry';
		  	$registry->load_all($self->param('reg_conf'));
		}
		my $patch_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $patch_db );
		my $patch_mlss_adap = $patch_dba->get_MethodLinkSpeciesSetAdaptor;
		my %patch_mlss_ids = map { $_->dbID => 1 } @{ $patch_mlss_adap->fetch_all_by_method_link_type("LASTZ_NET") };

		foreach my $copy_mlss_id ( @$copy_jobs ) {
			$pruned_copy_jobs{$copy_mlss_id} = 1 unless $patch_mlss_ids{$copy_mlss_id};
		}
	}

	my @new_copy_mlsses = keys %pruned_copy_jobs;
	return ( \@patch_dump_jobs, \@new_copy_mlsses );
}

1;
