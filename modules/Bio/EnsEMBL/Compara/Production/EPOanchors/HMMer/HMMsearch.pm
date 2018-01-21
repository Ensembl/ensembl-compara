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

package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::HMMsearch;

use strict;
use warnings;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use File::Basename;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub run {
	my ($self) = @_;

	my $self_dba = $self->compara_dba;

	my $dnafrag_adaptor = $self_dba->get_adaptor("DnaFrag");
	my $gab_adaptor = $self_dba->get_adaptor("GenomicAlignBlock");
	my $genome_db_adaptor = $self_dba->get_adaptor("GenomeDB");
	my $target_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('target_genome')->{"name"});
	my ($gab_id) = $self->param('gab_id');
	my $self_gab_adaptor = $self_dba->get_adaptor("GenomicAlignBlock");
	my @hits = ();
	my $gab = $self_gab_adaptor->fetch_by_dbID($gab_id);
	my $stk_file = $self->worker_temp_directory."$gab_id.stk";
	my $hmm_file = $self->worker_temp_directory."$gab_id.hmm";

	# Preload the GenomicAlign objects
	$gab->get_all_GenomicAligns;
	$self_dba->dbc->disconnect_if_idle;

	open(IN, ">$stk_file") or throw("can not open stockholm file $stk_file for writing");
	print IN "# STOCKHOLM 1.0\n";
	foreach my $genomic_align( @{$gab->get_all_GenomicAligns} ){
		my $aligned_seq = $genomic_align->aligned_sequence;
		next if($aligned_seq=~/^[N-]+[N-]$/);
		$aligned_seq=~s/\./-/g;
		print IN $gab_id, "\/", $genomic_align->dnafrag_start, ":", $genomic_align->dnafrag_end,
			"\/", $genomic_align->dnafrag->genome_db->name, "\t",
			$aligned_seq, "\n"; 
	}
	print IN "//";
	close(IN);

	my $genome_seq_file = $self->param('target_genome')->{"genome_seq"};
	#Copy genome_seq to local disk only if md5sum parameter is set. 
	if ($self->param('md5sum')) {
	    #Copy genome_seq to local disk if it doesn't already exist
	    my $name = basename($self->param('target_genome')->{"genome_seq"});
	    my $tmp_file = $self->worker_temp_directory.$self->param('target_genome')->{name} . "_" . $name;
	    
	    if (-e $tmp_file) {
		print "$tmp_file already exists\n";
		$genome_seq_file = $tmp_file;
	    } else {
		print "Need to copy file\n";

		my $rsync_cmd = ['rsync', $genome_seq_file, $tmp_file];
		my $runCmd = $self->run_command($rsync_cmd, { die_on_failure => 1 });
		print "Time to rsync " . $runCmd/1000 . "\n";

		#Check md5sum
		my $start_time = time;
		my $md5sum = `md5sum $tmp_file`;
		if ($md5sum == $self->param('md5sum')) {
		    $genome_seq_file = $tmp_file;
		} else {
		    print "md5sum failed. Use $genome_seq_file\n";
		}
		print "Time to md5sum " . (time - $start_time) . "\n";
	    }
	}

	my $hmm_build_command = [$self->param('hmmbuild'), $hmm_file, $stk_file];
	$self->run_command($hmm_build_command);

	unlink($stk_file);
	
	return unless(-e $hmm_file); # The sequences in the alignment are probably too short
	my $hmm_len = `egrep "^LENG  " $hmm_file`;
	chomp($hmm_len);
	$hmm_len=~s/^LENG  //;
#	my $nhmmer_command = $self->param('nhmmer') . " --cpu 1 --noali" ." $hmm_file " . $self->param('target_genome')->{"genome_seq"};

	my $nhmmer_command = $self->param('nhmmer') . " --cpu 1 --noali" ." $hmm_file $genome_seq_file";
	print $nhmmer_command, " **\n";
	my $nhmm_fh;
	open( $nhmm_fh, "$nhmmer_command |" ) or throw("Error opening nhmmer command: $? $!"); 
	{ local $/ = ">>";
		while(my $mapping = <$nhmm_fh>){
			next unless $mapping=~/!/;
			push(@hits, [$gab_id, $mapping]);
		}
	}

	my @anchor_align_records;
	foreach my $hit(@hits){
		my $mapping_id = $hit->[0];
		my($target_info, $mapping_info) = (split("\n", $hit->[1]))[0,3];
		my($coor_sys, $species, $seq_region_name) = (split(":", $target_info))[0,1,2];
		my($score,$bias, $evalue, $hmm_from, $hmm_to, $alifrom, $alito) = (split(/ +/, $mapping_info))[2,3,4,5,6,8,9];
		my $strand = $alifrom > $alito ? "-1" : "1";
		($alifrom, $alito) = ($alito, $alifrom) if $strand eq "-1";
		my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($target_genome_db, $seq_region_name);
		next unless($dnafrag);	
		push( @anchor_align_records, [ $self->param('mlssid_of_alignments'), $mapping_id, $dnafrag->dbID, $alifrom, $alito,
						$strand, $score, $hmm_from, $hmm_to, $evalue, $hmm_len ] );  
	}	
	unlink("$stk_file");
	$self->param('mapping_hits', \@anchor_align_records) if scalar( @anchor_align_records );
	unlink($hmm_file);
}

sub write_output{
	my ($self) = @_;
	my $self_anchor_align_adaptor = $self->compara_dba->get_adaptor("AnchorAlign");
	$self_anchor_align_adaptor->store_mapping_hits( $self->param('mapping_hits') ) if $self->param('mapping_hits');
}

1;

