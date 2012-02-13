#ensembl module for bio::ensembl::compara::production::epoanchors::parseenredo
# you may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
=head1 NAME

Bio::EnsEMBL::Compara::Production::EPOanchors::ParseEnredo

=head1 SYNOPSIS

$self->fetch_input();
$self->run();
$self->write_output(); writes to database

=head1 DESCRIPTION

Module to set up the production database for generating multiple alignments usng Ortheus.


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
package Bio::EnsEMBL::Compara::Production::EPOanchors::ParseEnredo;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my (%DF, %SEG, %Zero_st, @Zero_st, $dnafrag_region);
	open(IN, $self->param('enredo_out_file')) or die;
	{
		local $/ = "block";
		while(<IN>){
			next if /#/;
			$dnafrag_region++;
			foreach my $seg(split("\n", $_)){
				next unless $seg=~/:/;
				my($species,$chromosome,$start,$end,$strand) =
				$seg=~/^([\w:]+):([^\:]+):(\d+):(\d+) \[(.*)\]/;
				($start,$end) = ($start+1,$end-1); # assuming anchors have been split and have a one base overlap
				$DF{$species}++;
				$Zero_st{$dnafrag_region}++ unless $strand; # catch the dnafrag_region_id if there is a least one zero strand
				$SEG{$dnafrag_region}{ join(":", $species,$chromosome,$start,$end,$strand) }++; 
	    		}
	   	}
	}
	$self->param('genome_dbs', [ keys %DF ]);
	$self->param('dnafrag_regions', \%SEG);
	foreach my $dnafrag_region_id(keys %Zero_st){	
		push(@Zero_st, { zero_st_dnafrag_region_id => $dnafrag_region_id });
	}
	$self->param('dfrs_with_zero_st', \@Zero_st);
}

sub write_output {
	my ($self) = @_;
	our $master_db;
	*master_db = \$self->param('compara_master');
	my $master_params = join(" ", "-u", $master_db->{'-user'}, "-h", $master_db->{'-host'}, $master_db->{'-dbname'});
	my $master_select = "mysql ".$master_params.' -NB -e"SELECT ';
	my $master_dump = "mysqldump -t ".$master_params;

	my $to_db = " | mysql -h".$self->dbc->host." -u".$self->dbc->username.
		" -p".$self->dbc->password." -D".$self->dbc->dbname." -P".$self->dbc->port;
	# sort the species names from the enredo output files
	my $ancestor_db = $self->param('ancestor_db');
	my $genome_dbs_names_from_file = join("','", sort {$a cmp $b} @{ $self->param('genome_dbs') }, $ancestor_db->{'-name'});

	my $genomeDB_where_clause = "assembly_default AND name IN ('".$genome_dbs_names_from_file."')";
	my $genomeDB_pipe = $master_dump." -w \"$genomeDB_where_clause\""." genome_db".$to_db;
	system($genomeDB_pipe);
	my $ss_cmd = $master_select.'species_set_id FROM method_link_species_set WHERE method_link_species_set_id ='.
		$self->param('ortheus_mlssid').'"'; # get the species_set_id from the method_link_species_set table
	my ($ss_id) = map{ chomp $_;$_ } `$ss_cmd`;
	my $species_set_where_clause = "species_set_id = ".$ss_id;
	my $species_set_pipe = $master_dump." -w \"$species_set_where_clause\""." species_set".$to_db;
	system($species_set_pipe);
	my $gdb_from_mlssid = $master_select.'GROUP_CONCAT(gdb.name) FROM genome_db gdb INNER JOIN species_set ss ON ss.genome_db_id='.
		'gdb.genome_db_id WHERE ss.species_set_id='.$ss_id.'"';

	my ($gdb_names_from_master) = map{ chop $_;$_ } `$gdb_from_mlssid`; 
	$genome_dbs_names_from_file=~s/\'//g;
	my (%gdb_names_from_master, $species_number_from_file);
	foreach my $master_gdb(split(",", $gdb_names_from_master)){
		$gdb_names_from_master{ $master_gdb }++;
	}
	foreach my $gdb_from_file(split(",", $genome_dbs_names_from_file)){
		die "species $gdb_from_file from enredo file not in species_set from mlssid", $! 
			unless(exists($gdb_names_from_master{$gdb_from_file}) || $gdb_from_file eq $ancestor_db->{'-name'});
		$species_number_from_file++;
	}
 	warn "WARNING : species numbers from enredo file are different from db mlssid ". $self->param('ortheus_mlssid')
		if( $species_number_from_file <=> (keys %gdb_names_from_master) + 1);
	# create the ancestral core db
	my $ancestral_create = "mysql -u" . $ancestor_db->{'-user'} . " -h" . $ancestor_db->{'-host'} . " -p" . $ancestor_db->{'-pass'};
	system($ancestral_create . " -e" . "\"CREATE DATABASE " . $ancestor_db->{'-dbname'} . "\"");
	system($ancestral_create . " " . $ancestor_db->{'-dbname'} . " < " . $self->param('core_cvs_sql_schema'));	
	# set the locator field in the genome_db table
	$self->set_gdb_locator($genome_dbs_names_from_file);
	$genome_dbs_names_from_file=~s/,/','/g;
	my $quoted_gdb_names = '\''.$genome_dbs_names_from_file.'\'';
	my $genome_db_ids_from_names = $master_select.'GROUP_CONCAT(genome_db_id) FROM genome_db WHERE assembly_default AND name IN ('.$quoted_gdb_names.')"';
	my($gdb_ids) = map{ chomp $_;$_ } `$genome_db_ids_from_names`;
	# populate the method_link, method_link_species_set and dnafrag tables
	my $dnafrag_where_clause = "genome_db_id in (".$gdb_ids.")";
	my $dnafrag_pipe = $master_dump." -w \"$dnafrag_where_clause\""." dnafrag".$to_db;
	system($dnafrag_pipe);
	my $method_link_pipe = $master_dump." method_link".$to_db;
	system($method_link_pipe);
	my $mlss_clause = "method_link_species_set_id=".$self->param('ortheus_mlssid');
	my $mlss_pipe = $master_dump." -w \"$mlss_clause\""." method_link_species_set".$to_db;
	system($mlss_pipe);
	my $enredo_name = "ENREDO";
	my $sth1 = $self->dbc->prepare("SELECT method_link_id FROM method_link WHERE type = \"$enredo_name\"");
	$sth1->execute();
	my $sth2 = $self->dbc->prepare("REPLACE INTO method_link_species_set (method_link_id, species_set_id, name) VALUES (" . 
		$sth1->fetchrow_arrayref->[0] . ", $ss_id, \"$enredo_name\")");
	$sth2->execute();
	my (%DNAFRAGS, @synteny_region_ids);
	# populate dnafrag_region table
	my $sth3 = $self->dbc->prepare("INSERT INTO dnafrag_region VALUES (?,?,?,?,?)");
	my $sth4 = $self->dbc->prepare("INSERT INTO synteny_region VALUES (?,?)");
	foreach my $synteny_region_id(sort {$a <=> $b} keys %{ $self->param('dnafrag_regions') }){
		$sth4->execute($synteny_region_id,$self->param('ortheus_mlssid'));
		foreach my $dnafrag_region(keys %{ $self->param('dnafrag_regions')->{$synteny_region_id} }){
			my($species_name,$dnafrag_name,$start,$end,$strand)=split(":", $dnafrag_region);
			# get only the dnafrags used by enredo
			unless (exists($DNAFRAGS{$species_name}{$dnafrag_name})) {
				my $dnaf_sth = $self->dbc->prepare("SELECT df.dnafrag_id FROM dnafrag df INNER JOIN genome_db " . 
					"gdb ON gdb.genome_db_id = df.genome_db_id WHERE gdb.name = ? AND df.name = ?");
				$dnaf_sth->execute($species_name,$dnafrag_name);
				while(my $dnafrag_info = $dnaf_sth->fetchrow_arrayref()) {
					$DNAFRAGS{ $species_name }{ $dnafrag_name } = $dnafrag_info->[0];
				}
			}
			$sth3->execute($synteny_region_id,$DNAFRAGS{$species_name}{$dnafrag_name},$start,$end,$strand);		
		}
		push(@synteny_region_ids, {synteny_region_id => $synteny_region_id})
	}
	# add the MTs to the dnafrag_region table
	if($self->param('addMT')) {
		my $max_synteny_region_id = $synteny_region_ids[-1]->{'synteny_region_id'} + 1;
		$sth4->execute($max_synteny_region_id, $self->param('ortheus_mlssid'));
		my $sth_mt = $self->dbc->prepare("SELECT dnafrag_id, length FROM dnafrag WHERE name =\"MT\"");
		$sth_mt->execute;
		foreach my $dnafrag_region ( @{ $sth_mt->fetchall_arrayref } ) {
			$sth3->execute($max_synteny_region_id, $dnafrag_region->[0], 1, $dnafrag_region->[1], 1);
		}
		push(@synteny_region_ids, {synteny_region_id => $max_synteny_region_id});
	}
	# add the species_tree
	my $compara_master = new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%$master_db);
	my $species_tree = $compara_master->get_SpeciesTreeAdaptor()->create_species_tree( -species_set_id => $ss_id );
	my $newick_tree = lc( $species_tree->newick_format() );
	$newick_tree=~s/ /_/g;
	my $meta_sth = $self->dbc->prepare("REPLACE INTO meta (meta_key, meta_value) VALUES (?,?)");
	$meta_sth->execute("tree_" . $self->param('ortheus_mlssid'), "$newick_tree");
	$self->dataflow_output_id( $self->param('dfrs_with_zero_st'), 1 );
	$self->dataflow_output_id( \@synteny_region_ids, 2 );
}

sub set_gdb_locator { # fill in the locator field in the genome_db table
	my $self = shift;
	my $ancestor_db = $self->param('ancestor_db');
	my $genome_db_names = shift;
	Bio::EnsEMBL::Registry->load_registry_from_multiple_dbs( $self->param('main_core_dbs') );
	my @dbas = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors() };
	foreach my $genome_db_name(split(",", $genome_db_names), $ancestor_db->{'-name'}){
		my $core_genome_db_name = $genome_db_name . "_core_";
		my($host,$port,$db_name,$user,$pass,$locator_string);
		foreach my $dba(@dbas){
			if($dba->dbc->dbname=~m/$core_genome_db_name/) {
				$host = $dba->dbc->host;
				$port = $dba->dbc->port;
				$db_name = $dba->dbc->dbname;
				$user = $dba->dbc->username;
				$locator_string = "Bio::EnsEMBL::DBSQL::DBAdaptor/host=$host;port=$port;user=$user;".
					"dbname=$db_name;species=$genome_db_name;disconnect_when_inactive=1";
				last;
			} 
		} 
		if ($ancestor_db->{'-dbname'}=~m/$core_genome_db_name/){
			$host = $ancestor_db->{'-host'};
			$port = $ancestor_db->{'-port'};
			$db_name = $ancestor_db->{'-dbname'};
			$user = $ancestor_db->{'-user'};
			$pass = $ancestor_db->{'-pass'};
			$locator_string = "Bio::EnsEMBL::DBSQL::DBAdaptor/host=$host;port=$port;user=$user;pass=$pass;". 
				"dbname=$db_name;species=$genome_db_name;disconnect_when_inactive=1";
		}
		my $sth = $self->dbc->prepare("UPDATE genome_db SET locator=\"$locator_string\" WHERE name = \"$genome_db_name\"");
		$sth->execute;
	}
}

1;

