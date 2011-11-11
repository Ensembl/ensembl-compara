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


=head1 AUTHOR - Stephen Fitzgerald

This modules is part of the Ensembl project http://www.ensembl.org

Email compara@ebi.ac.uk

=head1 CONTACT

This modules is part of the EnsEMBL project (http://www.ensembl.org)

Questions can be posted to the ensembl-dev mailing list:
ensembl-dev@ebi.ac.uk


=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut
#
package Bio::EnsEMBL::Compara::Production::EPOanchors::ParseEnredo;

use strict;
use Data::Dumper;
use Bio::EnsEMBL::Registry;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');


sub fetch_input {
	my ($self) = @_;
	my (%DF, %SEG, %Zero_st, $dnafrag_region);
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
	$self->param('dnafrag_regions', [ keys %SEG ]);
	$self->param('dfrs_with_zero_st', [ keys %Zero_st ]);
}

sub write_output {
	my ($self) = @_;
	our $master_db;
	*master_db = \$self->param('compara_master');
	my $master_params = join(" ", "-u", $master_db->{'-user'}, "-h", $master_db->{'-host'}, $master_db->{'-dbname'});
	my $master_select = "mysql ".$master_params.' -NB -e"SELECT ';
	my $master_dump = "mysqldump ".$master_params;

	my $to_db = " | mysql -h".$self->dbc->host." -u".$self->dbc->username.
		" -p".$self->dbc->password." -D".$self->dbc->dbname." -P".$self->dbc->port;
	# sort the species names from the enredo output files
	my $genome_dbs_names_from_file = join("','", sort {$a cmp $b} @{ $self->param('genome_dbs') });

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
		die "species $gdb_from_file from enredo file not in species_set from mlssid", $! unless(exists($gdb_names_from_master{$gdb_from_file}));
		$species_number_from_file++;
	}
 	warn "WARNING : species numbers from enredo file are different from db mlssid ". $self->param('ortheus_mlssid')
		if( $species_number_from_file <=> keys %gdb_names_from_master);
	$genome_dbs_names_from_file=~s/,/','/g;
	my $quoted_gdb_names = '\''.$genome_dbs_names_from_file.'\'';
	my $genome_db_ids_from_names = $master_select.'GROUP_CONCAT(genome_db_id) FROM genome_db WHERE assembly_default AND name IN ('.$quoted_gdb_names.')"';
	my($gdb_ids) = map{ chomp $_;$_ } `$genome_db_ids_from_names`;

	my $dnafrag_where_clause = "genome_db_id in (".$gdb_ids.")";
	my $dnafrag_pipe = $master_dump." -w \"$dnafrag_where_clause\""." dnafrag".$to_db;
	system($dnafrag_pipe);
	my $method_link_pipe = $master_dump." method_link".$to_db;
	system($method_link_pipe);
	my $mlss_clause = "method_link_species_set_id=".$self->param('ortheus_mlssid');
	my $mlss_pipe = $master_dump." -w \"$mlss_clause\""." method_link_species_set".$to_db;
	system($mlss_pipe);
		
#	my $insert_dnafrag_regions_sth = $self->dbc->prepare("INSERT INTO dnafrag_region 
}

1;

