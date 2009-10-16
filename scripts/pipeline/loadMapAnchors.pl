#!/usr/local/ensembl/bin/perl -w

use strict;
use Data::Dumper;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

my $post_exonerate_modules = "post_exonerate_modules";
my $cleanup_logic_name = "Clean_up_genomedb_dumps";
my $exonerate_logic_name = "Exonerate_anchors";
my $trim_anchoralign_logic_name = "TrimAnchorAlign";

my %sql_statements = (
	select_anc_seq => "SELECT MIN(anchor_id) min_anchor_id, MAX(anchor_id) max_anchor_id, COUNT(DISTINCT(anchor_id)) anchor_count
				FROM anchor_sequence WHERE method_link_species_set_id = ?",
	select_analysis_id => "SELECT analysis_id FROM analysis WHERE logic_name = ?",
	select_max_species_set_id => "SELECT MAX(species_set_id) FROM species_set",
	select_max_method_link_id => "SELECT MAX(method_link_id) FROM method_link",
	select_max_method_link_species_set_id => "SELECT MAX(method_link_species_set_id) FROM method_link_species_set",
	select_method_link => "SELECT method_link_id, type FROM method_link",
	select_species_set => "SELECT species_set_id, genome_db_id FROM species_set",
	select_mlssid => "SELECT method_link_species_set_id, method_link_id, species_set_id FROM method_link_species_set",
	select_ctrl_rule => "SELECT condition_analysis_url, ctrled_analysis_id FROM analysis_ctrl_rule",
	select_analysis => "SELECT analysis_id, logic_name FROM analysis",
	select_max_analysis_id => "SELECT MAX(analysis_id) FROM analysis",
	select_analysis_data => "SELECT analysis_data_id, data FROM analysis_data",
	select_max_analysis_data_id => "SELECT MAX(analysis_data_id) FROM analysis_data",
	insert_new_analysis => "REPLACE INTO analysis (created, logic_name, program, parameters, module) VALUES (NOW(),?,?,?,?)",
	insert_analysis_jobs => "INSERT INTO analysis_job (analysis_id, input_id) VALUES (?,?)",
	insert_species_set => "INSERT INTO species_set (species_set_id, genome_db_id) VALUES (?,?)",
	insert_method_link => "REPLACE INTO method_link (method_link_id, type) VALUES (?,?)",
	insert_mlssid => "INSERT INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id, name) VALUES (?,?,?,?)",
	insert_analysis_ctl_rule => "INSERT INTO analysis_ctrl_rule (condition_analysis_url, ctrled_analysis_id) VALUES (?,?)",
	insert_analysis_data => "INSERT INTO analysis_data (analysis_data_id, data) VALUES (?,?)",
);

Bio::EnsEMBL::Registry->load_all;
Bio::EnsEMBL::Registry->no_version_check(1);

my($config_file,@anc_seq_id_ranges);

my $help = sub {
	print  '--config <config_file>',  "\n";
};

GetOptions(
	"config=s" => \$config_file,
);

unless(defined($config_file)) {
	$help->();
	exit(0);
}

my $self = bless {};

$self->parse_config_file($config_file);


foreach my$sql_statement(keys %sql_statements) {#prepare all the sql statemsnts
	$sql_statements{$sql_statement} = $self->{'anchorDBA'}->dbc->prepare($sql_statements{$sql_statement});
}

my $gdb_a = Bio::EnsEMBL::Registry->get_adaptor("Anchors", "compara", "GenomeDB");
$sql_statements{select_anc_seq}->execute($self->anchor_sequences_mlssid);
$self->anchor_data($sql_statements{select_anc_seq}->fetchrow_hashref);
fill_seq_id_ranges($self->anchor_data("min_anchor_id")->[0], \@anc_seq_id_ranges);
die "no anchor sequences found. Check the config file\n" unless @anc_seq_id_ranges;
$self->dump_genomes();
$self->insert_analysis_jobs_data(\@anc_seq_id_ranges); #insert into analysis/analysis_job/analysis_ctrl_rule tables
$self->insert_trim_anchor_align; #HACK to add in a new analysis
print "FIN\n";

sub insert_trim_anchor_align {	
	my $self = shift;
	my $method_link_id;
	$sql_statements{select_method_link}->execute();
	my $existing_method_link_ids = $sql_statements{select_method_link}->fetchall_hashref("type");
	if(exists($existing_method_link_ids->{uc($trim_anchoralign_logic_name)})) {
		$method_link_id = $existing_method_link_ids->{uc($trim_anchoralign_logic_name)}->{method_link_id};
	}
	else {
		$sql_statements{select_max_method_link_id}->execute();
		$method_link_id = ++$sql_statements{select_max_method_link_id}->fetchrow_arrayref()->[0];
	}
	$sql_statements{insert_method_link}->execute($method_link_id, uc($trim_anchoralign_logic_name));
	$sql_statements{select_max_method_link_species_set_id}->execute();
	my $method_link_species_set_id = ++$sql_statements{select_max_method_link_species_set_id}->fetchrow_arrayref()->[0];
	$sql_statements{insert_mlssid}->execute($method_link_species_set_id, $method_link_id, 
		$self->species_set_id, $trim_anchoralign_logic_name);

	$sql_statements{select_analysis_id}->execute($trim_anchoralign_logic_name);
	my $analysis_id = $sql_statements{select_analysis_id}->fetchrow_arrayref()->[0];
	my $params = '{"input_method_link_species_set_id" =>' . $self->exonerate_mlssid .
		', "output_method_link_species_set_id" =>' .  $method_link_species_set_id . ' }';
	$sql_statements{insert_new_analysis}->execute($trim_anchoralign_logic_name, undef, "$params", 
		$self->modules->{ $trim_anchoralign_logic_name });	
	
}


sub dump_genomes {
	my $self = shift;
	my %genome_db_ids_mapped_to_paths;
	my $dump_dir = $self->target_genome_info()->{dump_dir};
	my $genome_db_ids = $self->target_genome_info()->{genome_db_ids};
	$sql_statements{select_method_link}->execute();
	my $existing_method_link_ids = $sql_statements{select_method_link}->fetchall_hashref("type");
	$sql_statements{select_species_set}->execute();
	my($existing_species_set_ids, $species_set_id, $method_link_id, $set_ssid_flag, $analysis_data_id);
	while (my $row = $sql_statements{select_species_set}->fetchrow_hashref) {
		$existing_species_set_ids->{$row->{species_set_id}}{$row->{genome_db_id}}++;
	}
	foreach my $ssid(sort {$a <=> $b} keys %{$existing_species_set_ids}) {
		$species_set_id = $ssid if 
			join("", sort {$a <=> $b} keys %{$existing_species_set_ids->{$ssid}}) eq 
			join("", sort {$a <=> $b} @$genome_db_ids);
	}
	unless ($species_set_id) {
		$sql_statements{select_max_species_set_id}->execute();
		$species_set_id = ++$sql_statements{select_max_species_set_id}->fetchrow_arrayref->[0];
		$set_ssid_flag++;#if species_set_id for this set of species is not already in the db
	}
	if(exists($existing_method_link_ids->{uc($exonerate_logic_name)})) {
		$method_link_id = $existing_method_link_ids->{uc($exonerate_logic_name)}->{method_link_id};
	}
	else {#if a method_link_id for exonerate is not already in the db
		$sql_statements{select_max_method_link_id}->execute();
		$method_link_id = ++$sql_statements{select_max_method_link_id}->fetchrow_arrayref->[0];
		$sql_statements{insert_method_link}->execute($method_link_id, uc($exonerate_logic_name));
	}
	$self->species_set_id($species_set_id);
	$self->method_link_id($method_link_id);
	my $analysis_data_str = "{ target_genomes => {";
	print "Dumping genome seq for :\n";
	foreach my $genome_db_id (@{ $genome_db_ids }) {
		my $genome_db = $gdb_a->fetch_by_dbID($genome_db_id);
		$sql_statements{insert_species_set}->execute($species_set_id, $genome_db_id) if $set_ssid_flag;
		my $slice_a = Bio::EnsEMBL::Registry->get_adaptor($genome_db->name, "core", "Slice");
		my ($dir_name) = map { $_=~s/ +/_/g;$_ } ($self->target_genome_info()->{dump_dir} .  "/" . $genome_db->name);
		$genome_db_ids_mapped_to_paths{target_genomes}{ $genome_db_id } = $dir_name . "/genome_seq";
		$analysis_data_str .= " $genome_db_id => \"$genome_db_ids_mapped_to_paths{target_genomes}{ $genome_db_id }\", ";
		eval {
			mkdir($dir_name) or die;
			print $genome_db->name, "\n";
		};
		if($@) {
			if (-d $dir_name) {
				warn "$dir_name already exists\n";
				next;
			}
			else {
				die $@;
			}
		}
		foreach my$slice(@{ $slice_a->fetch_all("toplevel") }) {
			print $slice->name, "\n";
			open(my$fh, ">>$dir_name/genome_seq") or die "Cant create genome sequence file\n", $!;
			print $fh ">", $slice->name, "\n", $slice->seq, "\n";
		}
	}
	$analysis_data_str .= "} }";
	$sql_statements{select_analysis_data}->execute();
	my $existing_analysis_data_ids = $sql_statements{select_analysis_data}->fetchall_hashref("analysis_data_id");
	foreach my $existing_analysis_data_id (sort keys %{$existing_analysis_data_ids}) {
		if("$existing_analysis_data_ids->{$existing_analysis_data_id}->{data}" eq "$analysis_data_str") {
			$analysis_data_id = $existing_analysis_data_id;
		}
	} 
	unless($analysis_data_id) {
		$sql_statements{select_max_analysis_data_id}->execute();
		$analysis_data_id = ++$sql_statements{select_max_analysis_data_id}->fetchrow_arrayref()->[0];
	}
	eval {
		$sql_statements{insert_analysis_data}->execute($analysis_data_id, $analysis_data_str) or die;
	};
	warn $@ if $@;
	$genome_db_ids_mapped_to_paths{analysis_data_id} = $analysis_data_id;
	$self->target_genome_info(\%genome_db_ids_mapped_to_paths);
}

sub insert_analysis_jobs_data {
	my $self = shift;
	my $anchor_groups = shift;
	eval {
		$sql_statements{insert_new_analysis}->execute($exonerate_logic_name, $self->program,
			$self->exonerate_options, $self->modules->{ $exonerate_logic_name }) or die;
	};
	my $existing_mlssids;
	$sql_statements{select_mlssid}->execute();
	while(my @row = $sql_statements{select_mlssid}->fetchrow_array) {
		$existing_mlssids->{$row[1]}{$row[2]} = $row[0];
	}
	if(exists($existing_mlssids->{$self->method_link_id}{$self->species_set_id})) {
		$self->exonerate_mlssid( $existing_mlssids->{$self->method_link_id}{$self->species_set_id} );
	}
	else {
		$sql_statements{select_max_method_link_species_set_id}->execute();
		#set exonerate mlssid if it doesnt already exist 
		$self->exonerate_mlssid( ++$sql_statements{select_max_method_link_species_set_id}->fetchrow_arrayref()->[0] );
		$sql_statements{insert_mlssid}->execute( $self->exonerate_mlssid, $self->method_link_id, 
							$self->species_set_id, $exonerate_logic_name );
	}
	$sql_statements{select_analysis_id}->execute($exonerate_logic_name);
	my $analysis_id = $sql_statements{select_analysis_id}->fetchrow_arrayref()->[0];
	my $genome_seq_paths = $self->target_genome_info()->{target_genomes};
	foreach my$genome_db_id(sort keys %{ $genome_seq_paths }) {
		for(my$i=0;$i<@$anchor_groups-1;$i++) {
			my($anc_from,$anc_to) = @{$anchor_groups}[$i,$i+1];
			$anc_to-- if $i+1 < @$anchor_groups-1; #get anchor ranges correct for analysis_jobs
			my $input_id = "{ancs_from_to=>[" . join(",", $anc_from, $anc_to) . 
					"], target_genome=>$genome_db_id, anchor_sequences_mlssid=>" .
					$self->anchor_sequences_mlssid . ", exonerate_mlssid=>" . $self->exonerate_mlssid . 
					", analysis_data_id =>" . $self->target_genome_info()->{analysis_data_id} . ",}"; 
			eval {
				$sql_statements{insert_analysis_jobs}->execute($analysis_id, $input_id) or die;
			};
			if ($@) {
				last;
			}
		}
	}
	if(exists $self->modules->{$post_exonerate_modules}) {
		my(@new_analysis_ctl_rules, $existing_analysis, $existing_ctrl_rules); 
		push(@new_analysis_ctl_rules, [ $exonerate_logic_name, $analysis_id ]);
		$sql_statements{select_ctrl_rule}->execute() or die;
		$existing_ctrl_rules = $sql_statements{select_ctrl_rule}->fetchall_hashref("condition_analysis_url") or die;
		$sql_statements{select_analysis}->execute() or die;
		$existing_analysis = $sql_statements{select_analysis}->fetchall_hashref("analysis_id") or die;
		foreach my $post_exonerate_module (@{$self->modules->{$post_exonerate_modules}}) {
			my ($logic_name) = keys %{$post_exonerate_module};
			$sql_statements{select_analysis_id}->execute($logic_name);
			my $existing_analysis_id_ref = $sql_statements{select_analysis_id}->fetchrow_arrayref();
			if(defined ($existing_analysis_id_ref->[0])) {
				$analysis_id = $existing_analysis_id_ref->[0];
			}
			else {
				$sql_statements{select_max_analysis_id}->execute;
				$analysis_id = ++$sql_statements{select_max_analysis_id}->fetchrow_arrayref()->[0];
			}
			push(@new_analysis_ctl_rules, [ $logic_name, $analysis_id ]);
			my $module = $post_exonerate_module->{$logic_name};
			my $param_list = my $input_id = "{}"; 
			if($logic_name eq $cleanup_logic_name) {
				$input_id = $self->target_genome_info()->{target_genomes};
			}	
			else {
				$param_list = "{ input_analysis_id=>" . $analysis_id . 
						",input_method_link_species_set_id=>" . $self->exonerate_mlssid . " }";
			}
			if(ref($input_id)){ #its the cleanup module
				foreach my $gdb_id (sort keys %{$input_id}) {
					my $mod_input_id = "{ genome_db_flatfile=>" . $input_id->{$gdb_id} . " }"; 
					eval {
						$sql_statements{insert_analysis_jobs}->execute($analysis_id, $mod_input_id);
					};
				}
			}
			else {
				eval {
					$sql_statements{insert_analysis_jobs}->execute($analysis_id, $input_id) or die;
				};
			}
			eval {
				$sql_statements{insert_new_analysis}->execute($logic_name, undef, $param_list, $module) or die;
				
			};
		}
		for(my$i=0;$i<@new_analysis_ctl_rules-1;$i++) { #set up hive control rules
			if(exists($existing_ctrl_rules->{$new_analysis_ctl_rules[$i]->[0]})) {
				if($existing_ctrl_rules->{$new_analysis_ctl_rules[$i]->[0]}->{ctrled_analysis_id} == $new_analysis_ctl_rules[$i+1]->[1]) {
					warn $@, "analysis control already exists: ", 
						join(":", $new_analysis_ctl_rules[$i]->[0], $new_analysis_ctl_rules[$i+1]->[1]);
				}
				else {
					die $@, "Conflict between your analysis control rules and the rules in the database\n";
				}
			}
			else {
				eval {
					$sql_statements{insert_analysis_ctl_rule}->execute( $new_analysis_ctl_rules[$i]->[0],
								 $new_analysis_ctl_rules[$i+1]->[1] ) or die;
				};
			}
		}
	}
}

sub fill_seq_id_ranges {
	no warnings; #ignore warning about deep recursion, assuming it's not too deep.
	my($cut, $range) = @_; 
	if($self->anchor_data("max_anchor_id")->[0] > $cut) {
		if($cut == $self->anchor_data("min_anchor_id")->[0]) {
			push(@$range, $cut);
		} else {
			 push(@$range, $cut - 1);
		}
		$cut += $self->anchor_batch_size;
		fill_seq_id_ranges->($cut, $range);
	}
	else {
		push(@$range, $self->anchor_data("max_anchor_id")->[0]) if $self->anchor_data("max_anchor_id")->[0];
	}
	return 1;
}

sub parse_config_file {
	my $self = shift;
	my $conf_file = shift;
	my @param_list = @{ do $conf_file };
	die "no parameters in config_file\n" unless(@param_list);
	foreach my $input_hashref (@param_list) {
		my $param = delete($input_hashref->{"TYPE"});
		if($param=~/DBA$/) {
			$self->{$param} =  new Bio::EnsEMBL::Compara::DBSQL::DBAdaptor(%$input_hashref);
		}
		else {
			$self->{$param} = $input_hashref->{$param},
		}
	}
}

sub target_genome_info {
	my $self = shift;
	if(@_) {
		my $tgi = shift;
		if(ref($tgi)) {
			$self->{"target_genome_info"} = $tgi;
		}
		else {
			return $self->{"target_genome_info"}->{$tgi};
		}
	}
	return $self->{"target_genome_info"};
}

sub exonerate_options {
	my $self = shift;
	if(@_) {
		$self->{"exonerate_options"} = shift;
	}
	return $self->{"exonerate_options"};
}

sub program {
	my $self = shift;
	if(@_) {
		$self->{"program"} = shift;
	}
	return $self->{"program"};
}

sub exonerate_mlssid {
	my $self = shift;
	if(@_) {
		$self->{"exonerate_mlssid"} = shift;
	}
	return $self->{"exonerate_mlssid"};
}

sub anchor_sequences_mlssid {
	my $self = shift;
	if(@_) {
		$self->{"anchor_sequences_mlssid"} = shift;
	}
	return $self->{"anchor_sequences_mlssid"};
}

sub species_set_id {
	my $self = shift;
	if(@_) {
		$self->{"species_set_id"} = shift;
	}
	return $self->{"species_set_id"};
}

sub method_link_id {
	my $self = shift;
	if(@_) {
		$self->{"method_link_id"} = shift;
	}
	return $self->{"method_link_id"};
}

sub modules {
	my $self = shift;
	if(@_) {
		$self->{"modules"} = shift;
	}
	return $self->{"modules"};
}

sub anchor_batch_size {
	my $self = shift;
	if(@_) {
		$self->{"anchor_batch_size"} = shift;
	}
	return $self->{"anchor_batch_size"};
}

sub anchor_data {
	my $self = shift;
	if(@_) {
		my @out_put;
		foreach my $input_data(@_) {
			if(ref($input_data)) {
				foreach my $anc_info(sort keys %$input_data) {
					$self->{$anc_info} = $input_data->{$anc_info};
				}
			}
			else {
				push(@out_put, $self->{$input_data});
			}
		}
		return \@out_put if(scalar(@out_put));
	}
}

