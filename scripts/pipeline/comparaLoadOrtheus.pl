#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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

=pod

=head1 PROGRAM: 

comparaLoadOrtheus.pl 
 
=head1  DESCRIPTION: 

This software allows you to store the output of Enredo in an Ensembl Compara db
 
=head1 SYNOPSIS: 

  perl comparaLoadOrtheus.pl [options] -i enredo.out

=head1 OPTIONS:

=over

=item --reg-conf <registry configuration file> [default: -none-] 

This should contain all the core databases of the species in the
enredo.out file (the species names in the enredo.out file must be
aliased in the reg-conf file). Also include the master db and the
ancestral core db.
	
=item --master <registry name of the master db> [default: compara_master] 

This should correspond to "-species" value for the master db in the
registry configuration file.
  
=item --to_db <registry name of the compara database to populate> [default: -none-] 

This database should be new (no pre-existing data) There should also be
an new core ancestral database referenced in the registry configuration
file.
	
=item --mlss_id <method_link_species_set_id for ortheus> [default: -none-]

Should be present in the master 

=item --species_tree <newick format species tree> [default: -none-]

Can be presented as a string or a file

=item --addMT <1> [default: 0]

if set, will add rows to job/dnafrag_region/synteny_region tables for MT
alignments

=back

=head1 EXAMPLE: 

  comparaLoadOrtheus.pl --reg-conf <ensembl_registry_file> --master <compara_master> \
  --to_db <to_db> --mlss_id <mlss_id> --species_tree <species_tree> --addMT 1 -i enredo.out

=head1 INTERNAL FUNCTIONS:
=cut

use strict;

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Compara::SyntenyRegion;
use Bio::EnsEMBL::Compara::DnaFragRegion;
use Bio::SearchIO;
use Cwd qw(realpath);
use Sys::Hostname;
use Getopt::Long;
use Pod::Usage;
use Data::Dumper;
use DBI;

my $reg_conf;
my $compara_hive_conf;
my $master = "compara_master";
my $to_db;
my $ortheus_mlss_id;
my $species_tree;
my $input_file;
my $bl2seq = "/software/bin/bl2seq";
my $logic_name = "Ortheus";
my $parameters = "{max_block_size=>1000000,java_options=>'-server -Xmx1000M',}";
my $module = "Bio::EnsEMBL::Compara::Production::GenomicAlignBlock::Ortheus";
my $ancestral_seqs = "ancestral_sequences";
my $addMT = 0;

##tables to change to innodb (I) or autoincrement (A) or both (AI). 
my %tables2change = (
	A  => ["dnafrag"],
	AI => ["genomic_align", "genomic_align_block", "genomic_align_tree"],
	I  => ["dna", "seq_region"],
);

GetOptions(
    "reg-conf=s" => \$reg_conf,
    "master=s" => \$master,
    "to_db=s" => \$to_db,
    "mlss_id=s" => \$ortheus_mlss_id,
    "species_tree=s" => \$species_tree,
    "i=s" => \$input_file,
    "addMT=i" => \$addMT,
  );

unless(( -f $reg_conf) && defined($to_db) && defined($ortheus_mlss_id) 
	&& defined($species_tree) && ( -f $input_file)) {
        pod2usage( -exitstatus => 0, -verbose => 2 );
}

my ($master_db, $db_to_populate, $ancestral_db);
my (%core_db_data, $genome_dbs);

Bio::EnsEMBL::Registry->no_version_check(1);
Bio::EnsEMBL::Registry->load_all($reg_conf);
my @dbas = @{ Bio::EnsEMBL::Registry->get_all_DBAdaptors() };

for(my$i=0;$i<@dbas;$i++) {
	if ($dbas[$i]->species eq "$master") {
		$master_db = splice(@dbas, $i, 1);
		$i--;
	}
	elsif ($dbas[$i]->species eq "$to_db") {
		$db_to_populate = splice(@dbas, $i, 1);
		$i--;
	}	
	elsif ($dbas[$i]->species eq "$ancestral_seqs") {
		$ancestral_db = splice(@dbas, $i, 1);
		$i--;
	}
	else {	
		$core_db_data{ $dbas[$i]->species }{"dbname"} = $dbas[$i]->dbc->dbname;
		$core_db_data{ $dbas[$i]->species }{"host"} = $dbas[$i]->dbc->host;
		$core_db_data{ $dbas[$i]->species }{"port"} = $dbas[$i]->dbc->port;
		$core_db_data{ $dbas[$i]->species }{"user"} = $dbas[$i]->dbc->username;
		$core_db_data{ $dbas[$i]->species }{"pass"} = $dbas[$i]->dbc->password;
	}
}

my $sql_check_tables="SHOW TABLES";
my %ortheus_dbs;
foreach ($db_to_populate, $ancestral_db) {
	throw("One or both databases missing: $to_db \\ $ancestral_seqs\n") unless $_;
	my $sth = $_->dbc->prepare($sql_check_tables);
	$sth->execute();
	foreach my $table_name( @{ $sth->fetchall_arrayref } ) {
		$ortheus_dbs{ $_->dbc->dbname }{ $table_name->[0] }++;
	}
}

if (-e $species_tree){
	my $species_tree_f = realpath($species_tree);
	open(IN, $species_tree_f) or die "cant open file $species_tree_f";
	while(<IN>) {
		chomp;
		$species_tree = $_, last if $_;
	}
} elsif ($species_tree !~/[\(]+[\d]+[:]+/) {
	die "no/invalid species tree provided\n";
}

my $ancestral_gdb = $master_db->get_adaptor('GenomeDB')->fetch_by_name_assembly("$ancestral_seqs");

my $mlss_a = $master_db->get_adaptor('MethodLinkSpeciesSet');
my $ortheus_mlss = $mlss_a->fetch_by_dbID($ortheus_mlss_id);
throw("No such MethodLinkSpeciesSetID $ortheus_mlss_id in the master db\n") unless $ortheus_mlss;

my $to_db_gdb_a = $db_to_populate->get_adaptor('GenomeDB');
foreach my $genome_db ( @{ $ortheus_mlss->species_set_obj->genome_dbs }, $ancestral_gdb ) {
	my $species_name = $genome_db->name;
	push(@$genome_dbs, $genome_db);	
	my $db_name = $core_db_data{ $species_name }{"dbname"} || $ancestral_db->dbc->dbname;
	my $port = $core_db_data{ $species_name }{"port"} || $ancestral_db->dbc->port;
	my $host = $core_db_data{ $species_name }{"host"} || $ancestral_db->dbc->host;
	my $user = $core_db_data{ $species_name }{"user"} || $ancestral_db->dbc->username;
	my $locator_string;
	if ("$species_name" eq "$ancestral_seqs") {
		$locator_string = "Bio::EnsEMBL::DBSQL::DBAdaptor/pass=" . $ancestral_db->dbc->password . ";host=";
	} else { 
		$locator_string = "Bio::EnsEMBL::DBSQL::DBAdaptor/host=";
	}
	$locator_string .= "$host;port=$port;user=$user;dbname=$db_name;species=$species_name;disconnect_when_inactive=1"; 
	$genome_db->locator($locator_string);
	$to_db_gdb_a->store($genome_db);
}

##copy some tables from the master db
##only want to store the dnafrags from the relevant genome_dbs
my $dnafrag_condition = " genome_db_id in (" . join(",", map { $_->dbID }@$genome_dbs) . ")";
copy_table($master_db, $db_to_populate, "dnafrag", $dnafrag_condition);

my $species_set_condition = " species_set_id = " . $ortheus_mlss->species_set_obj->dbID;
copy_table($master_db, $db_to_populate, "species_set", $species_set_condition);

copy_table($master_db, $db_to_populate, "method_link");

##store the ortheus and enredo mlss(s)
my $to_db_mlss_a = $db_to_populate->get_adaptor('MethodLinkSpeciesSet');
$to_db_mlss_a->store($ortheus_mlss);

my $url = "file://[".hostname."]".realpath($input_file);

my $enredo_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
	-adaptor => $to_db_mlss_a,
      -method => Bio::EnsEMBL::Compara::Method->new( -type => 'ENREDO' ),
	-species_set_obj => Bio::EnsEMBL::Compara::SpeciesSet->new( -genome_dbs => $genome_dbs ),
	-name => "enredo",
	-source => "ensembl",
	-url => "$url",
); 
$enredo_mlss = $to_db_mlss_a->store($enredo_mlss);

parse_and_store_enredo($input_file);

update_schema_tables(\%tables2change);


=head2 update_schema_tables

  Arg[1]  listref of tables to alter. 
  Description: alters the database tables (myisam => innodb and reset autoincrement value to $mlssid * 10000000000 + 1)
  ReturnType: none

=cut

sub update_schema_tables {
	my ($tables) = shift;
	auto_increment_table($ortheus_mlss_id, [ @{ $tables->{AI} }, @{ $tables->{A} } ]) if $tables;
	my $sql_statement = "REPLACE INTO meta (meta_key, meta_value) VALUES (?,?)";
	my $sth = $db_to_populate->dbc->prepare( $sql_statement );
	$sth->execute("name", "ortheus_$ortheus_mlss_id");
	foreach my $table2change (@{ $tables->{I}, $tables->{AI} } ) {
		my $db_to_access;
		if(exists($ortheus_dbs{ $db_to_populate->dbc->dbname }{ $table2change })) { #its a compara-hive table
			$db_to_access = $db_to_populate;
		}
		elsif(exists($ortheus_dbs{ $ancestral_db->dbc->dbname }{ $table2change })) { #its an ancestral-core table
			$db_to_access = $ancestral_db;
		}
		else {
			throw("Table $table2change does not exist in either the compara-hive db or the ancestral-core db\n");
		}
		my $sql_statement = "ALTER TABLE $table2change ENGINE = INNODB";
		my $sth = $db_to_access->dbc->prepare( $sql_statement );
		$sth->execute();
	}
}


=head2 auto_increment_table

  Arg[1]  string $mlssid
  Arg[2]  arrayraef $table_names
  Example auto_increment_table(450, [ "genomic_align", "genomic_align_block" ]);
  Description: set the auto_increment start on the this table to be $mlssid * 10000000000 + 1 
  ReturnType: none

=cut

sub auto_increment_table {
	my($mlssid, $tables) = @_;
	foreach my $table_name(@{ $tables }) {
		my $auto_increment_start = $mlssid * 10000000000 + 1;
		my $sql_statement = "ALTER TABLE $table_name AUTO_INCREMENT = $auto_increment_start";
		my $sth = $db_to_populate->dbc->prepare( $sql_statement );
		$sth->execute();
	}
}


=head2 parse_and_store_enredo

  Arg[1]  string $filename
  Example parse_and_store_enredo($input_file);
  Description:  reads the enredo input file and stores the segments 
		in the dnafrag_region table and also populates the
		synteny_region, analysis, analysis_data and job 
		tables.
  ReturnType: none

=cut

sub parse_and_store_enredo {
	my $enredo_file = shift;
	my %sql_statements = (
	  add_analysis => "REPLACE INTO analysis (created, logic_name, parameters, module) VALUES 
			((SELECT CURRENT_TIMESTAMP FROM DUAL),?,?,?)",
	  get_analysis_id => "SELECT MAX(analysis_id) from analysis", 
	  add_job => "REPLACE INTO job (analysis_id, input_id) values (?,?)",
	  add_analysis_data => "REPLACE INTO analysis_data (data) VALUES (?)",
	  get_analysis_data_id => "SELECT MAX(analysis_data_id) from analysis_data",
	  add_synteny_region => "REPLACE INTO synteny_region (method_link_species_set_id) VALUES (?)",
	  get_synteny_region_id => "SELECT MAX(synteny_region_id) FROM synteny_region",
	  add_dnafrag_region => "REPLACE INTO dnafrag_region 
		(synteny_region_id, dnafrag_id, dnafrag_start, dnafrag_end, dnafrag_strand) VALUES (?,?,?,?,?)",	
	  get_MT_dnafrag_ids => "SELECT dnafrag_id FROM dnafrag WHERE name = \"MT\"", 
	);
	open(FILE, $enredo_file) or return undef;
	my $dnafrag_a = $db_to_populate->get_adaptor('DnaFrag');
	foreach my$sql_statement(keys %sql_statements) {##prepare all the sql statements	
		$sql_statements{$sql_statement} = $db_to_populate->dbc->prepare($sql_statements{$sql_statement});
	}
	$db_to_populate->dbc->do("LOCK TABLE analysis WRITE");
	##Add ortheus to the analysis table
	$sql_statements{'add_analysis'}->execute($logic_name, $parameters, $module);
 	my $analysis_id = $sql_statements{'get_analysis_id'}->execute();
	$db_to_populate->dbc->do("LOCK TABLE analysis_data WRITE");
	##add the species tree to analysis_data table
	$sql_statements{'add_analysis_data'}->execute($species_tree);
	my $tree_id = $sql_statements{'get_analysis_data_id'}->execute();
	$db_to_populate->dbc->do("UNLOCK TABLES");
	my (%dnafrags, %genome_dbs, $z, $dnafrag_regions);
	local $/ = "block";
	while(<FILE>) {
		next if /#/;
		my ($zero_strand, $non_zero_strand);
		$dnafrag_regions = undef;
		$z++;
		foreach my $seg(split("\n", $_)){
			next unless $seg=~/:/;
			my($species,$chromosome,$start,$end,$strand) = 
			$seg=~/^([^\:]+):([^\:]+):(\d+):(\d+) \[(.*)\]/;
			($start,$end) = ($start+1,$end-1); ##assuming anchors have been split and have a one base overlap
			$zero_strand = 1 unless $strand; ##set to true if there is a least one zero strand
			$non_zero_strand = 1 if $strand; ##set to true if there is a least one non-zero strand
			unless(exists($dnafrags{$species}{$chromosome})) {
				unless(exists($genome_dbs{$species})) {
					$genome_dbs{$species} = $to_db_gdb_a->fetch_by_registry_name($species);
				}
				my $dnafrag = $dnafrag_a->fetch_by_GenomeDB_and_name( $genome_dbs{$species}->dbID, $chromosome );
				$dnafrags{$species}{$chromosome}{'dnafrag'} = $dnafrag;
			}
			push(@$dnafrag_regions, [ $dnafrags{$species}{$chromosome}{'dnafrag'}, $start, $end, $strand ]);
		}
		if($zero_strand) {
			##if none of the sequences have a defined strand then set the first sequence strand to 1
			##this will be the target sequence against which to blast the remaining "query" sequences
			$dnafrag_regions->[0]->[3] = 1 unless ($non_zero_strand);
			my $matches = find_strand($dnafrag_regions, $z);
		}
		if(@$dnafrag_regions) {
			_add_synt_dnafrag_regions($dnafrag_regions, \%sql_statements, $tree_id, $analysis_id);
		}
	}
	if($addMT) {
		$dnafrag_regions = undef;
		$sql_statements{'get_MT_dnafrag_ids'}->execute;	
		foreach my $dnafrag_id ( @{ $sql_statements{'get_MT_dnafrag_ids'}->fetchall_arrayref } ) {
			my $dnafrag = $dnafrag_a->fetch_by_dbID( $dnafrag_id->[0] );
			push(@$dnafrag_regions, [ $dnafrag, 1, $dnafrag->length, 1 ]);
		} 
		if(@$dnafrag_regions) {
			_add_synt_dnafrag_regions($dnafrag_regions, \%sql_statements, $tree_id, $analysis_id);
		}	
	}
}


sub _add_synt_dnafrag_regions {
	my ($dnafrag_regions, $sql_statements, $tree_id, $analysis_id) = @_;
	$db_to_populate->dbc->do("LOCK TABLE synteny_region WRITE");
	##set/get synteny_region_id
	$sql_statements->{'add_synteny_region'}->execute($enredo_mlss->dbID);
	$sql_statements->{'get_synteny_region_id'}->execute();
	my $synteny_region_id = $sql_statements->{get_synteny_region_id}->fetchrow_arrayref->[0];
	$db_to_populate->dbc->do("UNLOCK TABLES");
	##set analysis_job for this synteny_region
	my $input_id = "{synteny_region_id=>" . $synteny_region_id . ",method_link_species_set_id=>" . 
	$ortheus_mlss_id . ",tree_analysis_data_id=>" . $tree_id . "}";
	$sql_statements->{'add_job'}->execute($analysis_id, $input_id);
	##insert segments for this synteny_region into dnafrag_region table 
	foreach my $this_dnafrag_region (@$dnafrag_regions) {
		my($dnafrag,$start,$end,$strand) = @$this_dnafrag_region;
		$sql_statements->{'add_dnafrag_region'}->execute($synteny_region_id,$dnafrag->dbID,$start,$end,$strand);
	}
}


=head2 find_strand

  Arg[1]  hashref of segments, where each sequence is a hashref 
	  like this [dnafrag_object, seq_start, seq_end, seq_strand]  
  Example parse_and_store_enredo($input_file);
  Description:  Calculates an average score for each strand of the query.
		The strand with the highest average score is set in the hashref of segments (seq_strand)
		The score is generated by bl2seq 
  ReturnType: none

=cut

sub find_strand {
	my ($dnafrag_regions, $z) = @_;
	my ($query_set, $target_set, $q_files, $t_files, $query_index, $blastResults, $matches);
	for(my$i=0;$i< @$dnafrag_regions;$i++) {
		if( $dnafrag_regions->[$i]->[3] ) {
			push(@$target_set, $dnafrag_regions->[$i]);
		} else {
			push(@$query_set, $dnafrag_regions->[$i]);
			$query_index->{ $dnafrag_regions->[$i]->[0]->slice->sub_Slice(
			$dnafrag_regions->[$i]->[1], $dnafrag_regions->[$i]->[2], 1)->name } = $i;
		}
	}
	##write the query and target files to disc
	($q_files, $t_files) = write_files($query_set, $target_set, $z);
	##blast each query against each target 
	foreach my $query_file (@$q_files) {
		foreach my $target_file (@$t_files) {
			my $command = $bl2seq . " -i $query_file -j $target_file -p blastn";
			my $bl2seq_fh;
			open($bl2seq_fh, "$command |") or throw("Error opening command: $command"); ##run the command
			##parse_bl2seq returns a hashref of the scores and the number of hits to each query strand
			push(@$blastResults, parse_bl2seq($bl2seq_fh));
		}
	}
	foreach my $this_result ( @$blastResults ) {
		foreach my $query_name ( sort keys %$this_result ) {
			foreach my $target_name ( sort keys %{ $this_result->{ $query_name } }) {
				foreach my $strand (sort keys %{ $this_result->{ $query_name }{ $target_name } } ) {
					foreach my $num_of_results (sort keys %{ $this_result->{ $query_name }{ $target_name }{ $strand } } ) {
						## get an average score for each query strand
						$matches->{ $query_name }{ $strand } += 
						$this_result->{ $query_name }{ $target_name }{ $strand }{ $num_of_results } / $num_of_results;
					}
				}
			}
		}
	}
	##set the query strand to -1 or 1 depending on the average score from the blast results
	if( keys %$matches) {
		foreach my $query_name ( sort keys %{ $query_index } ) {
			$dnafrag_regions->[ $query_index->{ $query_name } ]->[3] = 
				$matches->{ $query_name }{ "1" } > $matches->{ $query_name }{ "-1" } ? 1 : -1;
		}
	}
	##remove the target and query files
	foreach my $file (@$q_files, @$t_files) {
		unlink($file) or die "cant remove file: $file\n";
	}
}

=head2 parse_bl2seq

  Arg[1]  file_handle of blast results file
  Example open($bl2seq_fh, "$command |"); parse_bl2seq($bl2seq_fh);
  Description:  parses the query/target blast results file 
  ReturnType: hashref of the scores and the number of hits to each query strand

=cut

sub parse_bl2seq {
	my $file2parse = shift;
	my $hits;
	local $/ = "\n";
	my $blast_io = new Bio::SearchIO(-format => 'blast', -fh => $file2parse);
	my $count;
	while( my $result = $blast_io->next_result ) {
		while( my $hit = $result->next_hit ) {
			while( my $hsp = $hit->next_hsp ) {
				 $hits->{ $result->query_name }{ $hit->name }{ $hsp->strand('hit') }{ ++$count } += $hsp->score;
			}
		}
	}
	return $hits;
}

=head2 write_files

  Arg[1]  array_ref of query_data (those with an unknown strand),
	  each element of which looks like this [dnafrag_object, seq_start, seq_end, seq_strand]
  Arg[2]  array_ref of target_data (those with a known strand). same structure as the query_data
  Example ($q_files, $t_files) = write_files($query_data, $target_data); 
  Description:  calls subroutine print_to_file to write query and target sequences in FASTA format to disc
  ReturnType: 2 array_refs of query and target file names 

=cut

sub write_files {
	my ($queries, $targets, $z) = @_;
	my ($q_fh, $t_fh);
	foreach my $this_query (@$queries) {
		push(@$q_fh, print_to_file($this_query,"Q", $z));
	}
	foreach my $this_target (@$targets) {
		push(@$t_fh, print_to_file($this_target, "T", $z));
	}
	return($q_fh, $t_fh);
}

=head2 print_to_file

  Arg[1]  array_ref like this [dnafrag_object, seq_start, seq_end, seq_strand]
  Arg[2]  string data type (query or target)
  Example $file_name = print_to_file($this_query,"Q")
  Description:  writes query and target sequences in FASTA format to disc
  ReturnType: string (file_name)

=cut

sub print_to_file {
	my($dnafrag_region, $type, $z) = @_;
	my $slice;
	if($type eq "Q") {
		$slice = $dnafrag_region->[0]->slice->sub_Slice(
			$dnafrag_region->[1], $dnafrag_region->[2], 1); ##set the strand to 1 if it's a query
	} else {
		$slice = $dnafrag_region->[0]->slice->sub_Slice(
			$dnafrag_region->[1], $dnafrag_region->[2], $dnafrag_region->[3]); 
	}
	my $file_name = "se$type"  . "_$z" . "_" . $$ . "_" . join("_", $dnafrag_region->[0]->genome_db_id,
		$dnafrag_region->[0]->name, $dnafrag_region->[1], $dnafrag_region->[2]);
	my $seq = $slice->seq;
	$seq =~ s/(.{60})/$1\n/g;
	open(FH, ">>$file_name") or die "cant open $file_name";
	print FH ">" . $slice->name . "\n$seq";
	return $file_name;
}

=head2 copy_table

  Arg[1]  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (database from which to copy table)
  Arg[2]  Bio::EnsEMBL::Compara::DBSQL::DBAdaptor (database to copy table to)
  Arg[3]  string (table name to copy) 
  Arg[4]  string (sql'where' condition - if a restricted data set from the table is required)
  Example copy_table($master_db, $db_to_populate, $table_name, $where_condition) 
  Description:  writes query and target sequences in FASTA format to disc
  ReturnType: none

=cut

sub copy_table {
  my ($from_dba, $to_dba, $table_name, $where) = @_; 
  throw("[$from_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($from_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  throw("[$to_dba] should be a Bio::EnsEMBL::Compara::DBSQL::DBAdaptor")
      unless (UNIVERSAL::isa($to_dba, "Bio::EnsEMBL::Compara::DBSQL::DBAdaptor"));

  my $from_user = $from_dba->dbc->username;
  my $from_host = $from_dba->dbc->host;
  my $from_port = $from_dba->dbc->port;
  my $from_dbname = $from_dba->dbc->dbname;  

  my $to_user = $to_dba->dbc->username;
  my $to_pass = $to_dba->dbc->password;
  my $to_host = $to_dba->dbc->host;
  my $to_port = $to_dba->dbc->port;
  my $to_dbname = $to_dba->dbc->dbname;
  
  my $mysql_pipe;
  if ($where) {
        $mysql_pipe = "mysqldump -uensro -h$from_host -P$from_port -t $from_dbname -w \"$where\" $table_name | ";
  } else {
        $mysql_pipe = "mysqldump -uensro -h$from_host -P$from_port $from_dbname $table_name | ";
  }
  $mysql_pipe .= "mysql -u$to_user -p$to_pass -h$to_host -P$to_port -D$to_dbname";
  system($mysql_pipe);
}

