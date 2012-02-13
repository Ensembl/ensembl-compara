#Ensembl module for Bio::EnsEMBL::Compara::Production::EPOanchors::TrimStoreAnchors
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::TrimStoreAnchors

=head1 SYNOPSIS

$exonate_anchors->fetch_input();
$exonate_anchors->run();
$exonate_anchors->write_output(); writes to database

=head1 DESCRIPTION

Given a database with anchor sequences and a target genome. This modules exonerates 
the anchors against the target genome. The required information (anchor batch size,
target genome file, exonerate parameters are provided by the analysis, analysis_job 
and analysis_data tables  

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
dev@ensembl.org


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::TrimStoreAnchors;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Hive::Process;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Analysis;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_all;
Bio::EnsEMBL::Registry->no_version_check(1);

our @ISA = qw(Bio::EnsEMBL::Hive::Process);


sub configure_defaults {
 	my $self = shift;
	$self->gab_batch_size(1000);
  	return 1;
}

sub fetch_input {
	my ($self) = @_;
	$self->configure_defaults();
	$self->get_parameters($self->parameters);
	#create a Compara::DBAdaptor which shares the same DBI handle with $self->db (Hive DBAdaptor)
	$self->{'comparaDBA'} = Bio::EnsEMBL::Compara::Production::DBSQL::DBAdaptor->new(-DBCONN=>$self->db->dbc) or die "cant connect\n";
	$self->{'comparaDBA'}->dbc->disconnect_if_idle();
	$self->{'hiveDBA'} = Bio::EnsEMBL::Hive::DBSQL::DBAdaptor->new(-DBCONN => $self->{'comparaDBA'}->dbc) or die "cant connect\n";
	$self->{'hiveDBA'}->dbc->disconnect_if_idle();
	
	return 1;
}

sub run {
	my ($self) = @_;
	#find all genomic_align_blocks with the minimum size and minimum number of seqs
	my %sql_statements = (
		select_constrained_elements => "SELECT constrained_element_id, dnafrag_id, dnafrag_start,
			dnafrag_end, dnafrag_strand FROM constrained_element WHERE (dnafrag_end - dnafrag_start + 1) >= ?  
				AND method_link_species_set_id = ?",
		select_analysis_data => "SELECT data FROM analysis_data WHERE analysis_data_id = ?",
		select_genome_db_ids => "SELECT ss.genome_db_id, gdb.name FROM genome_db gdb INNER JOIN species_set ss 
				ON gdb.genome_db_id = ss.genome_db_id WHERE species_set_id = 
				(SELECT species_set_id FROM method_link_species_set WHERE method_link_species_set_id = ?)",
		select_dnafrag_info => "SELECT df.genome_db_id, df.dnafrag_id, df.name, df.coord_system_name FROM dnafrag df INNER JOIN 
				constrained_element ce ON df.dnafrag_id = ce.dnafrag_id WHERE ce.method_link_species_set_id = ? 
				AND (ce.dnafrag_end - ce.dnafrag_start + 1) >= ? GROUP BY df.dnafrag_id",
		insert_anchor_seq => "INSERT INTO anchor_sequence (method_link_species_set_id, anchor_id, dnafrag_id, start, end, 
				strand, sequence, length) VALUES (?,?,?,?,?,?,?,?)",
	);
	foreach my$sql_statement(keys %sql_statements) {#prepare all the sql statements
		$sql_statements{$sql_statement} = $self->{'comparaDBA'}->dbc->prepare($sql_statements{$sql_statement});
	}
	$sql_statements{select_genome_db_ids}->execute($self->method_link_species_set_id);
	my(%org_hash, $dnafrag_hashref);
	while(my@row = $sql_statements{select_genome_db_ids}->fetchrow_array) {
		$org_hash{$row[0]} = $row[1];	
	}
	foreach my$genome_db_id(sort keys %org_hash) { #get slice adaptors for all the species used to generate the anchors
		$org_hash{$genome_db_id} = Bio::EnsEMBL::Registry->get_adaptor("$org_hash{$genome_db_id}", "core", "Slice");
	}
	$sql_statements{select_analysis_data}->execute($self->analysis_data_id);
	my $analysis_struct = eval ( ($sql_statements{select_analysis_data}->fetchrow_array)[0] );
	$sql_statements{select_dnafrag_info}->execute($self->previous_mlssid, $analysis_struct->{min_anc_size});
	$dnafrag_hashref = $sql_statements{select_dnafrag_info}->fetchall_hashref("dnafrag_id");
	$sql_statements{select_constrained_elements}->execute($analysis_struct->{min_anc_size}, $self->previous_mlssid);
	while(my($constrained_element_id, $dnafrag_id, $dnafrag_start, $dnafrag_end, $dnafrag_strand)
			 = $sql_statements{select_constrained_elements}->fetchrow_array) {
		my $slice = $org_hash{ $dnafrag_hashref->{$dnafrag_id}->{genome_db_id} }->fetch_by_region(
						$dnafrag_hashref->{$dnafrag_id}->{coord_system_name},
						$dnafrag_hashref->{$dnafrag_id}->{name},
						$dnafrag_start,
						$dnafrag_end,
						$dnafrag_strand,
		);
		next if $slice->length < $analysis_struct->{min_anc_size};
			$sql_statements{insert_anchor_seq}->execute($self->method_link_species_set_id,
					$constrained_element_id, $dnafrag_id, $dnafrag_start,
					$dnafrag_end, $dnafrag_strand,
					$slice->seq, length($slice->seq));
	}
	return 1;
}

sub write_output {
	my ($self) = @_;
	return 1;
}

sub previous_mlssid { #this should be the constrained_element mlssid

	my $self = shift;
	if (@_) {
		$self->{_previous_mlssid} = shift;
	}
	return $self->{_previous_mlssid};
}

sub gab_batch_size {
	my $self = shift;
	if (@_) {
		$self->{_gab_batch_size} = shift;
	}
	return $self->{_gab_batch_size};
}

sub analysis_data_id {
	my $self = shift;
	if (@_) {
		$self->{_analysis_data_id} = shift;
	}
	return $self->{_analysis_data_id};
}

sub trim_and_store_analysis_id {
	my $self = shift;
	if (@_) {
		$self->{_trim_and_store_analysis_id} = shift;
	}
	return $self->{_trim_and_store_analysis_id};
}

sub method_link_species_set_id {
	my $self = shift;
	if (@_){
		$self->{_method_link_species_set_id} = shift;
	}
	return $self->{_method_link_species_set_id};
}

sub get_parameters {
	my $self = shift;
	my $param_string = shift;
	
	return unless($param_string);
	my $params = eval($param_string);
	if(defined($params->{'method_link_species_set_id'})) {
		$self->method_link_species_set_id($params->{'method_link_species_set_id'});
	}
	if(defined($params->{'analysis_data_id'})) {
		$self->analysis_data_id($params->{'analysis_data_id'});
	}
	if(defined($params->{'previous_mlssid'})) {
		$self->previous_mlssid($params->{'previous_mlssid'});
	}
}

sub get_input_id {
	my $self = shift;
	my $input_id_string = shift;

	return unless($input_id_string);
	print("parsing input_id string : ",$input_id_string,"\n");
	return 1;
}

1;

