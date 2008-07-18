#!/usr/local/ensembl/bin/perl -w

use strict;
use Data::Dumper;
use DBI;
use Getopt::Long;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;

Bio::EnsEMBL::Registry->load_all;
Bio::EnsEMBL::Registry->no_version_check(1);

use constant {
	blastz => "BLASTZ_NET",
	min_anchor_size => 50,
	max_anchor_size => 250,
	min_number_of_org_hits_per_base => 2,
	dnafrag_chunk_size => 1000000,
	get_blastz_overlaps => "GetBlastzOverlaps",
	gerp => "Gerp",
	trim_and_store_anchors => "TrimStoreAnchors",
	filter_anchors => "FilterAnchors",
	tree_file_default =>'/lustre/work1/ensembl/sf5/pecan_gerp/9vert.nw'	
};

my $help = sub {
	print  '--config <config_file>',  "\n";
};

my($config_file);

GetOptions(
	"config=s" => \$config_file,
);

unless(defined($config_file)) {
	$help->();
	exit(0);
}

my $self = bless {};
my %sql_statements = (
	select_species_set => "SELECT species_set_id, genome_db_id FROM species_set",
	select_max_species_set_id => "SELECT MAX(species_set_id) FROM species_set",
	select_mlssid => "SELECT method_link_species_set_id, method_link_id, species_set_id FROM method_link_species_set",
	select_method_link => "SELECT method_link_id, type FROM method_link",
	select_max_method_link_id => "SELECT MAX(method_link_id) FROM method_link",
	select_max_method_link_species_set_id => "SELECT MAX(method_link_species_set_id) FROM method_link_species_set",
	select_analysis => "SELECT analysis_id, logic_name FROM analysis",
	select_analysis_data => "SELECT analysis_data_id, data FROM analysis_data",
	select_max_analysis_data_id => "SELECT MAX(analysis_data_id) FROM analysis_data",
	select_ctrl_rule => "SELECT condition_analysis_url, ctrled_analysis_id FROM analysis_ctrl_rule",
	insert_species_set => "INSERT INTO species_set (species_set_id, genome_db_id) VALUES (?,?)",	
	insert_new_analysis => "INSERT INTO analysis (created, logic_name, parameters, module) VALUES (NOW(),?,?,?)",
	insert_method_link => "INSERT INTO method_link (method_link_id, type) VALUES (?,?)",
	insert_mlssid => "INSERT INTO method_link_species_set (method_link_species_set_id, method_link_id, species_set_id, name) VALUES (?,?,?,?)",
	insert_analysis_jobs => "INSERT INTO analysis_job (analysis_id, input_id) VALUES (?,?)",
	insert_analysis_data => "INSERT INTO analysis_data (data) VALUES (?)",
	insert_analysis_ctl_rule => "INSERT INTO analysis_ctrl_rule (condition_analysis_url, ctrled_analysis_id) VALUES (?,?)",
	insert_data_flow_rule => "INSERT INTO dataflow_rule (from_analysis_id, to_analysis_url) VALUES (?,?)", 
	update_analysis_parameters => "UPDATE analysis SET parameters = ? WHERE logic_name = ?",
);

$self->parse_config_file($config_file);

foreach my$sql_statement(keys %sql_statements) {#prepare all the sql statemsnts
        $sql_statements{$sql_statement} = $self->{'anchorDBA'}->dbc->prepare($sql_statements{$sql_statement});
}
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "GenomeDB");
my $dnafrag_adaptor = Bio::EnsEMBL::Registry->get_adaptor("Multi", "compara", "DNAFrag");

$self->insert_analysis_jobs_data;

sub insert_analysis_jobs_data { 
	my $self = shift;
	$sql_statements{select_analysis_data}->execute();
	while(my@row = $sql_statements{select_analysis_data}->fetchrow_array) {
		my $analysis_struct = eval($row[1]);
		if(ref($analysis_struct) eq "HASH" && exists($analysis_struct->{min_anc_size}) && exists($analysis_struct->{max_anc_size})) {
			$self->analysis_data_id($row[0]);
			warn "min_anc_size and max_anc_size already set in analysis_data\n";
		}
	}
	unless($self->analysis_data_id) {
		my($analysis_data_string);
		my($min_anchor_size, $max_anchor_size) = defined($self->analysis_data->{anchor_size_range}) ? 
				(@{$self->analysis_data->{anchor_size_range}}) : (min_anchor_size, max_anchor_size);
		($min_anchor_size, $max_anchor_size) = ($max_anchor_size , $min_anchor_size) unless($min_anchor_size < $max_anchor_size); #check to be sure 
		my($min_number_of_org_hits_per_base) = defined($self->analysis_data->{min_number_of_org_hits_per_base}) ? 
				$self->analysis_data->{min_number_of_org_hits_per_base} : min_number_of_org_hits_per_base;
		unless(defined($self->analysis_data->{tree})) {
			die "no newick tree defined in config file\n$!";
		}
		$analysis_data_string = "{ min_anc_size =>$min_anchor_size, max_anc_size =>$max_anchor_size, min_number_of_org_hits_per_base => $min_number_of_org_hits_per_base, }";
		
		$sql_statements{insert_analysis_data}->execute( $analysis_data_string );
		$sql_statements{select_max_analysis_data_id}->execute();
		$self->analysis_data_id($sql_statements{select_max_analysis_data_id}->fetchrow_array);
		$sql_statements{insert_analysis_data}->execute( $self->analysis_data->{tree} ); #needs to have it's own analysis_data_id for pecan
		$sql_statements{select_max_analysis_data_id}->execute();
		$self->tree_analysis_data_id($sql_statements{select_max_analysis_data_id}->fetchrow_array);
	}
	my($existing_species_set_ids, $species_set_id, @all_genome_db_ids);
	$sql_statements{select_method_link}->execute();
	my $existing_method_link_ids = $sql_statements{select_method_link}->fetchall_hashref("type");
	$sql_statements{select_species_set}->execute();
	while (my $row = $sql_statements{select_species_set}->fetchrow_hashref) {
		$existing_species_set_ids->{$row->{species_set_id}}{$row->{genome_db_id}}++;	
	}
	push(@all_genome_db_ids, $self->reference_genome_db_id, @{$self->non_ref_genome_db_ids});
	foreach my $ssid(sort {$a <=> $b} keys %{$existing_species_set_ids}) {
		$species_set_id = $ssid if
			join("", sort {$a <=> $b} keys %{$existing_species_set_ids->{$ssid}}) eq 
			join("", sort {$a <=> $b} @all_genome_db_ids);
	}
	if ($species_set_id) {
		warn "species_set_id for genome_db_ids \"", join (", ", @all_genome_db_ids), "\" already exists\n";
	}
	else {#if a species_set_id is not already in the db
		$sql_statements{select_max_species_set_id}->execute();
		$species_set_id = ++$sql_statements{select_max_species_set_id}->fetchrow_arrayref->[0];
		foreach my $genome_db_id (@all_genome_db_ids) {	
			$sql_statements{insert_species_set}->execute($species_set_id, $genome_db_id);
		}	
	}
	#the first analysis should be "GetBlastzOverlaps"
	die "the first analysis should be GetBlastzOverlaps" unless $self->analysis->[0]->{"logic_name"} eq "GetBlastzOverlaps"; 	
	my(@new_analysis_ctl_rules);
	foreach my $analysis ( @{$self->analysis} ) {
		my($logic_name, $method_link_id, $parameter_string, $module); 
		$logic_name = $analysis->{logic_name};
		if(exists($existing_method_link_ids->{uc($logic_name)})) {
			$method_link_id = $existing_method_link_ids->{uc($logic_name)}->{method_link_id};
		}
		else {#if a method_link_id is not already in the db
			$sql_statements{select_max_method_link_id}->execute();
			$method_link_id = ++$sql_statements{select_max_method_link_id}->fetchrow_arrayref->[0];
			$sql_statements{insert_method_link}->execute($method_link_id, uc($logic_name));
		}
		$self->previous_mlssid($self->method_link_species_set_id) if ($self->method_link_species_set_id);
		my $existing_mlssids;
		$sql_statements{select_mlssid}->execute();
		while(my @row = $sql_statements{select_mlssid}->fetchrow_array) {
			$existing_mlssids->{$row[1]}{$row[2]} = $row[0];
		}
		if(exists($existing_mlssids->{$method_link_id}{$species_set_id})) {
			$self->method_link_species_set_id($existing_mlssids->{$method_link_id}{$species_set_id});
			warn "mlss_id for method_link_id $method_link_id and species_set_id $species_set_id already exists\n";
		}
		else {#if a method_link_species_set_id is not already in the db
			$sql_statements{select_max_method_link_species_set_id}->execute();
			my $new_mlssid = ++$sql_statements{select_max_method_link_species_set_id}->fetchrow_arrayref->[0];
			$sql_statements{insert_mlssid}->execute( $new_mlssid, $method_link_id,
				$species_set_id, $logic_name );
			$self->method_link_species_set_id($new_mlssid);
			$existing_mlssids->{$method_link_id}{$species_set_id} = $new_mlssid;
		}
		$module = $analysis->{module} if exists $analysis->{module}; 
		$parameter_string = "{ ";
		if (exists $analysis->{parameters}) {
			foreach my $parameter(sort keys %{$analysis->{parameters}}) {
				$parameter_string .= "$parameter=>$analysis->{parameters}->{$parameter}, ";
			}
		}
		eval {
			$sql_statements{insert_new_analysis}->execute(
				$logic_name, undef, $module) or die;
		};
		my($analysis_id);
		$sql_statements{select_analysis}->execute();
		while(my @row = $sql_statements{select_analysis}->fetchrow_array) {
			if($row[1] eq $logic_name) {
				$analysis_id = $row[0];
			}
		}
		unless($analysis_id) {	
			die "could not get analysis_id for $logic_name\n$!";
		}
		push(@new_analysis_ctl_rules, [ $logic_name, $analysis_id ]);
		#add this lot to the parameter string along with what ever was specified in the config file
		if($analysis->{logic_name} eq gerp) {
			my $tree_file = $self->tree_file ? $self->tree_file : tree_file_default;
			$parameter_string .= "window_sizes=>\'[]\', tree_file=>\'" . $tree_file . 
				"\',constrained_element_method_link_type=>'GERP\'"
		}
		else {
			die "undefined value(s): method_link_species_set_id, analysis_id, analysis_data_id, tree_analysis_data_id\n$!" 
			unless ($self->method_link_species_set_id and $analysis_id and $self->analysis_data_id and $self->tree_analysis_data_id);
			$parameter_string .= "method_link_species_set_id=>" . $self->method_link_species_set_id .
				",analysis_id=>$analysis_id,analysis_data_id=>" . $self->analysis_data_id .
				",tree_analysis_data_id=>" . $self->tree_analysis_data_id;
		}
		if($analysis->{logic_name} eq trim_and_store_anchors) {
			die "TrimStoreAnchors analysis should be preceded by another analysis\n$!" unless $self->previous_mlssid;
			$parameter_string .= ",previous_mlssid=>" . $self->previous_mlssid;
			eval {
				$sql_statements{insert_analysis_jobs}->execute($analysis_id,"{}") or die; #dummy analysis to set up jobs for trimming and storing anchors
			};
		}
		$parameter_string .= ", }";
		#update parameter list in analysis table with analysis_data_id & mlss_id & analysis_id
		$sql_statements{update_analysis_parameters}->execute($parameter_string, $analysis->{logic_name});

		if($analysis->{logic_name} eq get_blastz_overlaps) {
			#get all dnafrags for reference
			my $reference_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region(
					$genome_db_adaptor->fetch_by_dbID($self->reference_genome_db_id) );	
			foreach my $reference_dnafrag(@$reference_dnafrags) {
				my (@dnafrag_chunks,$temp_from);
				if($reference_dnafrag->length > dnafrag_chunk_size) { #need to chunk the dnafrag into smaller pieces
					for(my$p=0;$p<(int($reference_dnafrag->length / dnafrag_chunk_size));$p++) {
						$temp_from = $p * dnafrag_chunk_size;		
						push(@dnafrag_chunks, [ $temp_from + 1, $temp_from + dnafrag_chunk_size ]);
					}
					if($reference_dnafrag->length % dnafrag_chunk_size) {
						push(@dnafrag_chunks, [ $temp_from + dnafrag_chunk_size + 1, $reference_dnafrag->length ]);
					}
				}
				else {
					push(@dnafrag_chunks, [ 1, $reference_dnafrag->length ]); #if it's <= dnafrag_chunk_size 
				}
				my $input_id = "{ method_type=>\"" . blastz . "\",genome_db_ids=>[ " . $self->reference_genome_db_id .  ", ";
				foreach my $non_ref_genome_db_id (@{$self->non_ref_genome_db_ids}) {
					$input_id .= $non_ref_genome_db_id . ", ";
				}
				$input_id .= "],ref_dnafrag_id=>" . $reference_dnafrag->dbID;
				foreach my $chunk(@dnafrag_chunks) {
					my $temp_input_id = $input_id;
					$temp_input_id .= ",dnafrag_chunks=>[ " . join(",", @$chunk) . " ], }";
					eval {
						$sql_statements{insert_analysis_jobs}->execute($analysis_id, $temp_input_id) or die;
					};
				}	
			}
		}
	}
	$sql_statements{select_ctrl_rule}->execute() or die;
	my $existing_ctrl_rules = $sql_statements{select_ctrl_rule}->fetchall_hashref("condition_analysis_url") or die;
	for(my$i=0;$i<@new_analysis_ctl_rules-1;$i++) {
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
#			eval {
#				$sql_statements{insert_data_flow_rule}->execute( $new_analysis_ctl_rules[$i]->[1],
#					$new_analysis_ctl_rules[$i+1]->[0] ) or die;
#			};
		}
	}
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

sub analysis_data {
	my $self = shift;
	if(@_) {
		$self->{"analysis_data"} = shift;
	}
	return $self->{"analysis_data"};
}

sub analysis_data_id {
	my $self = shift;
	if(@_) {
		$self->{"analysis_data_id"} = shift;
	}
	return $self->{"analysis_data_id"};
}

sub tree_analysis_data_id {
	my $self = shift;
	if(@_) {
		$self->{"tree_analysis_data_id"} = shift;
	}
	return $self->{"tree_analysis_data_id"};
}

sub method_link_species_set_id {
	my $self = shift;
	if(@_) {
		$self->{"method_link_species_set_id"} = shift;
	}
	return $self->{"method_link_species_set_id"};
}

sub previous_mlssid {
	my $self = shift;
	if(@_) {
		$self->{"previous_mlssid"} = shift;
	}
	return $self->{"previous_mlssid"};
}

sub species_set_id {
	my $self = shift;
	if(@_) {
		$self->{"species_set_id"} = shift;
	}
	return $self->{"species_set_id"};
}

sub tree_file {
	my $self = shift;
	if(@_) {
		$self->{"tree_file"} = shift;
	}
	return $self->{"tree_file"};
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

sub non_ref_genome_db_ids {
	my $self = shift;
	if(@_) {
		$self->{"non_ref_genome_db_ids"} = shift;
	}
	return $self->{"non_ref_genome_db_ids"};
}

sub reference_genome_db_id {
	my $self = shift;
	if(@_) {
		$self->{"reference_genome_db_id"} = shift;
	}
	return $self->{"reference_genome_db_id"};
}

sub analysis {
	my $self = shift;
	if(@_) {
		$self->{"analysis"} = shift;
	}
	return $self->{"analysis"};
}
