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

Bio::EnsEMBL::Compara::Production::EPOanchors::LoadDnaFragRegion

=head1 SYNOPSIS

$self->fetch_input();
$self->run();
$self->write_output(); writes to database

=head1 DESCRIPTION

Module to set up the production database for generating multiple alignments usng Ortheus.


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

package Bio::EnsEMBL::Compara::Production::EPOanchors::LoadDnaFragRegion;

use strict;
use warnings;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my (%DF,%SEG,%Zero_st,%StartEnd,@Zero_st,$synteny_region_id);
	open(IN, $self->param('enredo_output_file')) or die;
	{
		local $/ = "block";
		while(<IN>){
			next if /#/;
			$synteny_region_id++;
			foreach my $seg(split("\n", $_)){
				next unless $seg=~/:/;
				my($species,$chromosome,$start,$end,$strand) =
				$seg=~/^([\w:]+):([^\:]+):(\d+):(\d+) \[(.*)\]/;
				# %StartEnd : this is a hack, as not all adjacent enredo blocks have a 2 bp overlap (~20% dont), 
				# so we cant just say "($start,$end) = ($start+1,$end-1);"
				my$loc_string =  join(":", $species,$chromosome,$start,$end,$strand);
				push( @{ $StartEnd{$species}{$chromosome} }, 
					[ $start, $end, $strand, $synteny_region_id, $loc_string ] );
				$DF{$species}++;
				$Zero_st{$synteny_region_id}++ unless $strand; # catch the synteny_region_id if there is a least one zero strand
				$SEG{$synteny_region_id}{$loc_string}++; 
	    		}
	   	}
	}
	# fix the start and ends of genomic coordinates with overlaps	
	foreach my $species(sort keys %StartEnd){
		foreach my $chromosome(sort keys %{ $StartEnd{$species} }){
			our $arr;
			*arr = \$StartEnd{$species}{$chromosome};
			@$arr = sort {$a->[0] <=> $b->[0]} @$arr;
			for(my$i=1;$i<@$arr;$i++){
				if($arr->[$i]->[0] == $arr->[$i-1]->[1] - 1){
					$arr->[$i-1]->[1] -= 1;
					$arr->[$i]->[0] += 1;
				}
			}
		}
	}
	# replace the original coordinates with a 2 bp overlap with the non-overlapping coordinates
	foreach my $species(sort keys %StartEnd){
		foreach my $chromosome(sort keys %{ $StartEnd{$species} }){
			our $arr;
			*arr = \$StartEnd{$species}{$chromosome};
			for(my$i=0;$i<@$arr;$i++){
				my $new_coords = join(":", $species, $chromosome, @{ $arr->[$i] }[0..2]);
				unless($new_coords eq $arr->[$i]->[4]){
					delete( $SEG{$arr->[$i]->[3] }{ $arr->[$i]->[4] } ); # remove the original overlapping segment 
					$SEG{ $arr->[$i]->[3] }{ $new_coords }--; # replace it with the the non-ovelapping segment
				}
			} 
		}
	}
	$self->param('genome_dbs', [ keys %DF ]);
	$self->param('synteny_regions', \%SEG);
	$self->param('zero_st_sy_ids', \%Zero_st); # hack to filter out zero strand synteny_region_ids
	foreach my $synteny_region_id(keys %Zero_st){	
		push(@Zero_st, { zero_st_synteny_region_id => $synteny_region_id });
	}
	$self->param('dfrs_with_zero_st', \@Zero_st);
}

sub write_output {
	my ($self) = @_;
	# sort the species names from the enredo output files
	my $genome_dbs_names_from_file = join(":", sort {$a cmp $b} @{ $self->param('genome_dbs') }) . ":";

	# get the genome_db names from the genome_db table in the production db
	my $genome_db_adaptor = $self->compara_dba()->get_adaptor("GenomeDB");
	my $genome_db_names_from_db;
	foreach my $genome_db(sort {$a->name cmp $b->name} @{ $genome_db_adaptor->fetch_all }){
		$genome_db_names_from_db .= $genome_db->name.":" if $genome_db->taxon_id;
	}
	# check the species names from the file against those from the db
	die "species from enredo file ($genome_dbs_names_from_file) are not the same as the set of species in the database ($genome_db_names_from_db)", $! 
	unless ( "$genome_dbs_names_from_file" eq "$genome_db_names_from_db" );
	my (%DNAFRAGS, @synteny_region_ids);
	my $dnafrag_adaptor = $self->compara_dba->get_DnaFragAdaptor;
	# populate dnafrag_region table
        $self->dbc->do('DELETE FROM dnafrag_region');
        $self->dbc->do('DELETE FROM synteny_region');
	my $sth1 = $self->dbc->prepare("INSERT INTO dnafrag_region VALUES (?,?,?,?,?)");
	my $sth2 = $self->dbc->prepare("INSERT INTO synteny_region VALUES (?,?)");
	foreach my $synteny_region_id(sort {$a <=> $b} keys %{ $self->param('synteny_regions') }){
		$sth2->execute($synteny_region_id,$self->param('mlss_id'));
		foreach my $dnafrag_region(keys %{ $self->param('synteny_regions')->{$synteny_region_id} }){
			my($species_name,$dnafrag_name,$start,$end,$strand)=split(":", $dnafrag_region);
			# we have the dnafrag_name from the file but we need the dnafrag_id from the db
			# get only the dnafrags used by enredo
			unless (exists($DNAFRAGS{$species_name}{$dnafrag_name})) {
				my $gdb = $genome_db_adaptor->fetch_by_name_assembly( $species_name );
				my $df = $dnafrag_adaptor->fetch_by_GenomeDB_and_name( $gdb, $dnafrag_name );
				$DNAFRAGS{ $species_name }{ $dnafrag_name } = $df->dbID;
			}
			$sth1->execute($synteny_region_id,$DNAFRAGS{$species_name}{$dnafrag_name},$start,$end,$strand);		
		}
		unless(exists($self->param('zero_st_sy_ids')->{$synteny_region_id})){ # dont create ortheus jobs for the synteny_regions with one or more zero strands
			push(@synteny_region_ids, {synteny_region_id => $synteny_region_id});
		}
	}
	# add the MTs to the dnafrag_region table
	if($self->param('add_non_nuclear_alignments')) {
		my $max_synteny_region_id = $synteny_region_ids[-1]->{'synteny_region_id'} + 1;
		$sth2->execute($max_synteny_region_id, $self->param('mlss_id'));
		my $sth_mt = $self->dbc->prepare("SELECT dnafrag_id, length FROM dnafrag WHERE cellular_component =\"MT\"");
		$sth_mt->execute;
		foreach my $dnafrag_region ( @{ $sth_mt->fetchall_arrayref } ) {
			$sth1->execute($max_synteny_region_id, $dnafrag_region->[0], 1, $dnafrag_region->[1], 1);
		}
		push(@synteny_region_ids, {synteny_region_id => $max_synteny_region_id});
	}
	$self->dataflow_output_id( $self->param('dfrs_with_zero_st'), 2 ); # zero strand, so flow to a job factory to set up bl2seq jobs
	$self->dataflow_output_id( \@synteny_region_ids, 3 ); # no zero strand, so flow to a job factory to set up ortheus
}

1;

