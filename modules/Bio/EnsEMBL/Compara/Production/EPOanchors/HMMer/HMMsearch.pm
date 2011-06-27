package Bio::EnsEMBL::Compara::Production::EPOanchors::HMMer::HMMsearch;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw);

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

sub fetch_input {
	my ($self) = @_;
	my $self_dba = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor( 
				-host => $self->dbc->host, 
				-pass => $self->dbc->password, 
				-port => $self->dbc->port, 
				-user => $self->dbc->username,
				-dbname => $self->dbc->dbname);
	$self->param('self_dba', $self_dba);
}

sub run {
	my ($self) = @_;
	my $self_dba = $self->param('self_dba');
	my $dnafrag_adaptor = $self_dba->get_adaptor("DnaFrag");
	my $gab_adaptor = $self_dba->get_adaptor("GenomicAlignBlock");
	my $genome_db_adaptor = $self_dba->get_adaptor("GenomeDB");
	my ($gab_id) = $self->param('gab_id');
	my $self_gab_adaptor = $self->param('self_dba')->get_adaptor("GenomicAlignBlock");
	my @hits = ();
	my $gab = $self_gab_adaptor->fetch_by_dbID($gab_id);
	my $stk_file = "/tmp/sf5_$gab_id.stk";
	my $hmm_file = "/tmp/sf5_$gab_id.hmm";
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
	my $hmm_build_command = $self->param('hmmbuild') . " $hmm_file $stk_file";  
	print $hmm_build_command, " **\n";
	system($hmm_build_command);
	return unless(-e $hmm_file); # The sequences in the alignment are probably too short
	my $nhmmer_command = $self->param('nhmmer') . " --cpu 1 --noali" ." $hmm_file " . $self->param('target_genome')->{"genome_seq"};
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
		my($score, $evalue, $alifrom, $alito) = (split(/ +/, $mapping_info))[2,4,8,9];
		my $strand = $alifrom > $alito ? "-1" : "1";
		($alifrom, $alito) = ($alito, $alifrom) if $strand eq "-1";
		my $taregt_genome_db = $genome_db_adaptor->fetch_by_registry_name($self->param('target_genome')->{"name"});
		my $dnafrag = $dnafrag_adaptor->fetch_by_GenomeDB_and_name($taregt_genome_db, $seq_region_name);
		next unless($dnafrag);	
		push( @anchor_align_records, [ $self->param('mlssid_of_alignments'), $mapping_id, $dnafrag->dbID, $alifrom, $alito,
						$strand, $score, 0, 0, $evalue ] );  
	}	
	$self->param('mapping_hits', \@anchor_align_records) if scalar( @anchor_align_records );
	unlink("$stk_file");
	unlink("$hmm_file");
}

sub write_output{
	my ($self) = @_;
	my $self_anchor_align_adaptor = $self->param('self_dba')->get_adaptor("AnchorAlign");
	$self_anchor_align_adaptor->store_mapping_hits( $self->param('mapping_hits') ) if $self->param('mapping_hits');
}

1;

