=head1 LICENSE

See the NOTICE file distributed with this work for additional information
regarding copyright ownership.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::FTPDumps::CreateDumpJobs

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
        #'alignment_dump_options' => {
                #EPO              => {format => 'emf+maf'},
                #EPO_EXTENDED     => {format => 'emf+maf'},
                #PECAN            => {format => 'emf+maf'},
                #LASTZ_NET        => {format => 'maf', make_tar_archive => 1},
        #},

        # define which method_link_types should be dumpable (only used to
        # trigger the copy from the previous release)
        dumpable_method_types => {
        	'LASTZ_NET' => 1, 'EPO' => 1, 'EPO_EXTENDED' => 1, 'PECAN' => 1,
        	'GERP_CONSTRAINED_ELEMENT' => 1, 'GERP_CONSERVATION_SCORE' => 1,
        },
    };
}

sub fetch_input {
	my $self = shift;

	my $curr_release = $self->param_required('curr_release');

	my $mlssa = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my @release_mlsses;
	my %mlss_id_to_dump;

	my $mlss_ids = $self->param('mlss_ids');
	if ( $mlss_ids ) {
		# only those mlss_ids
		foreach my $mlss_id ( @$mlss_ids ) {
			push( @release_mlsses, $mlssa->fetch_by_dbID($mlss_id) );
			$mlss_id_to_dump{$mlss_id} = 1;
		}
	} else {
		@release_mlsses = @{ $mlssa->fetch_all };
		foreach my $mlss (@release_mlsses) {
                    if (($mlss->first_release == $curr_release) || $mlss->has_tag("rerun_in_${curr_release}")) {
                        $mlss_id_to_dump{$mlss->dbID} = 1;
                    }
                }
		my $updated_mlss_ids = $self->param('updated_mlss_ids'); #for the productions pipelines that we have decided to run again. hence the first release has not been updated but the data may have changed
		if ( $updated_mlss_ids ) {
			foreach my $updated_mlss_id ( @$updated_mlss_ids ) {
				$mlss_id_to_dump{$updated_mlss_id} = 1;
			}
		}	
	}

	# first, split new mlsses into categories
	my (%dumps, @copy_jobs, %method_types);
	foreach my $mlss ( @release_mlsses ) {
		my $method_class = $mlss->method->class;
		if ( $mlss_id_to_dump{$mlss->dbID} ) {
			# new analysis/user defined mlss! must be dumped
			if ( $method_class =~ /^GenomicAlign/ ) { # all alignments
				next if ($mlss->method->type =~ /^(CACTUS_HAL|CACTUS_HAL_PW)$/);  # ... except for Cactus
				push( @{$dumps{DumpMultiAlign}}, $mlss );
				# only dump ancestors when EPO primates has been run
				$self->param( 'dump_ancestral_alleles', 1 ) if ( $mlss->method->type eq 'EPO' && $mlss->species_set->name eq 'primates' );
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
			if ( $method_class =~ /tree_node$/ ) { # gene trees
				push( @{$dumps{DumpTrees}}, $mlss );
				next;
			}
			# old analysis! can be copied from prev release FTP location
			push( @copy_jobs, $mlss->dbID ) if defined $self->param('dumpable_method_types')->{$mlss->method->type};
		}
	}

	# generate job lists for each dump type
	my %all_dump_jobs;
	$all_dump_jobs{DumpMultiAlign}          = $self->_dump_multialign_jobs( $dumps{DumpMultiAlign} ) if $dumps{DumpMultiAlign};
	$all_dump_jobs{DumpTrees}               = $self->_dump_trees_jobs( $dumps{DumpTrees} ) if $dumps{DumpTrees};
	$all_dump_jobs{DumpConstrainedElements} = $self->_dump_constrainedelems_jobs( $dumps{DumpConstrainedElements} ) if $dumps{DumpConstrainedElements};
	$all_dump_jobs{DumpConservationScores}  = $self->_dump_conservationscores_jobs( $dumps{DumpConservationScores} ) if $dumps{DumpConservationScores};
	
	# always add these when mlss_ids have not been defined
	unless ( $mlss_ids ) {
		$all_dump_jobs{DumpSpeciesTrees}        = $self->_dump_speciestree_job; # doesn't require mlsses
		$all_dump_jobs{DumpAncestralAlleles}    = $self->_dump_anc_allele_jobs if $self->param('dump_ancestral_alleles'); 
	}
	
	if ( !$mlss_ids && $self->param('lastz_patch_dbs') ) {
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
	$self->dataflow_output_id( $dump_jobs->{DumpMultiAlign}, 9 ) if $dump_jobs->{DumpMultiAlign};
	$self->dataflow_output_id( $dump_jobs->{DumpTrees}, 2 ) if $dump_jobs->{DumpTrees};
	$self->dataflow_output_id( $dump_jobs->{DumpConstrainedElements}, 3 ) if $dump_jobs->{DumpConstrainedElements};
	$self->dataflow_output_id( $dump_jobs->{DumpConservationScores},  4 ) if $dump_jobs->{DumpConservationScores};
	$self->dataflow_output_id( $dump_jobs->{DumpSpeciesTrees}, 5 ) if $dump_jobs->{DumpSpeciesTrees};
	$self->dataflow_output_id( $dump_jobs->{DumpAncestralAlleles}, 6 ) if $dump_jobs->{DumpAncestralAlleles};

	$self->dataflow_output_id( $dump_jobs->{DumpMultiAlignPatches}, 7 ) if ( $dump_jobs->{DumpMultiAlignPatches} && $self->param('lastz_patch_dbs'));

	return 1 unless ( $self->param_required('reuse_prev_rel') );

	my $copy_jobs = $self->param('copy_jobs');
    my $copy_ancestral_alleles = (($self->param_required('division') eq 'vertebrates') && ! $self->param('dump_ancestral_alleles')) || 0;
    return 1 unless (@$copy_jobs || $copy_ancestral_alleles);
	print "\n\nTO COPY: \n";
	print '(' . join(', ', @$copy_jobs) . ")\n";
    print "ancestral alleles\n" if $copy_ancestral_alleles;
    $self->dataflow_output_id( { mlss_ids => $copy_jobs, copy_ancestral_alleles => $copy_ancestral_alleles }, 8 );
}

sub _dump_multialign_jobs {
	my ($self, $mlss_list) = @_;
	my %alignment_dump_options = %{$self->param_required('alignment_dump_options')};

	my @jobs;

	# if the mlss_ids have been user-defined, don't bundle them by method_link_type
	if ( $self->param('mlss_ids') ) {
		foreach my $mlss ( @$mlss_list ) {
			my %this_job = %{ $self->param('default_dump_options')->{DumpMultiAlign} };
			my $this_type = $mlss->method->type;
			$this_job{mlss_id} = $mlss->dbID;
			$this_job{add_conservation_scores} = 0 unless ( $this_type eq 'PECAN' || $this_type eq 'EPO_EXTENDED' );
			foreach my $opt ( keys %{$alignment_dump_options{$this_type}} ) {
				$this_job{$opt} = $alignment_dump_options{$this_type}->{$opt};
			}
			push( @jobs, \%this_job );
		}
		return \@jobs;
	}

	# otherwise, group by method_link_type, flowing only 1 job per type
	# uniqify the list of method link types
	my %aln_types;
	foreach my $mlss ( @$mlss_list ) {
		$aln_types{$mlss->method->type} = 1;
	}

	foreach my $type ( keys %aln_types ) {
		my %this_job = %{ $self->param('default_dump_options')->{DumpMultiAlign} };
		$this_job{method_link_types} = $type;
		$this_job{add_conservation_scores} = 0 unless ( $type eq 'PECAN' || $type eq 'EPO_EXTENDED' );
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
	my ( $self, $copy_jobs ) = @_;

	my (@patch_dump_jobs, %pruned_copy_jobs);
	foreach my $patch_db ( @{$self->param('lastz_patch_dbs')} ) {
		my $patch_mlss_ids = $self->_find_mlsses_with_alignment( $patch_db );
		foreach my $mlss_id ( @$patch_mlss_ids ) {
			my %this_job = %{$self->param('default_dump_options')->{DumpMultiAlign}};
			$this_job{compara_db} = $patch_db;
			$this_job{mlss_id} = $mlss_id->[0];
			$this_job{format} = 'maf'; # don't add make_tar_archive - will be adding to dir and tarring later
			push( @patch_dump_jobs, \%this_job );
		}

		# remove MLSSes from copy jobs if adding patches
		# don't want to copy directly from prev FTP - need to top up the tar.gz first
		my %patch_mlss_hash = map { $_ => 1 } @$patch_mlss_ids;
		foreach my $copy_mlss_id ( @$copy_jobs ) {
			$pruned_copy_jobs{$copy_mlss_id} = 1 unless $patch_mlss_hash{$copy_mlss_id};
		}
	}

	my @new_copy_mlsses = keys %pruned_copy_jobs;
	return ( \@patch_dump_jobs, \@new_copy_mlsses );	
}

sub _find_mlsses_with_alignment {
	my ( $self, $aln_db ) = @_;

	my $aln_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $aln_db );
	my $curr_release = $self->param('curr_release'); # add filter for old mlsses only - new ones will be dumped from scratch
	my $sql = "SELECT method_link_species_set_id FROM method_link_species_set WHERE method_link_species_set_id IN (SELECT DISTINCT(method_link_species_set_id) FROM genomic_align_block) and method_link_id = 16 and first_release < $curr_release";
        return $aln_dba->dbc->db_handle->selectall_arrayref($sql);
}

1;
