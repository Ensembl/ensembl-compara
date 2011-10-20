=head1 LICENSE

  Copyright (c) 1999-2011 The European Bioinformatics Institute and
  Genome Research Limited.  All rights reserved.

  This software is distributed under a modified Apache license.
  For license details, please see

    http://www.ensembl.org/info/about/code_licence.html

=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <dev@ensembl.org>.

  Questions may also be sent to the Ensembl help desk at
  <helpdesk@ensembl.org>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf 

=head1 SYNOPSIS


=head1 DESCRIPTION

Parse configuration file 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

my $verbose = 0;

my $suffix_separator = '__cut_here__';

sub fetch_input {
    my ($self) = @_;

    #must be better way of doing this
    #Return if no conf file and trying to get the species list
    if ($self->param('conf_file') eq "" &&  $self->param('get_species_list')) {
	return;
    }

    #
    #Must load the registry first
    #
    if ($self->param('reg_conf') ne "") {
	Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'));
    } elsif (defined $self->param('registry_dbs')) {

	load_registry_dbs($self->param('registry_dbs'));
    }

    #Set default reference speices. Should be set by init_pipeline module
    unless (defined $self->param('ref_species')) {
	$self->param('ref_species', 'homo_sapiens');
    }
}

sub run {
    my ($self) = @_;

    #must be better way to doing this
    if ($self->param('conf_file') eq "" &&  $self->param('get_species_list')) {
	return;
    }

    #If no pair_aligner configuration file, use the defaults
    if ($self->param('conf_file') eq "") {
	$self->parse_defaults();
    } else {
	#parse configuration file
	$self->parse_conf($self->param('conf_file'));
    }
}

sub write_output {
    my ($self) = @_;

    #No configuration file, so no species list. Flow an empty speciesList
    if ($self->param('conf_file') eq "" &&  $self->param('get_species_list')) {
	my $output_id = "{'speciesList'=>'\"\"'}";
	$self->dataflow_output_id($output_id,1);
	return;
    }

    #Have configuration file and getting only the speciesList. Dataflow to populate_new_database
    if ($self->param('get_species_list')) {
	my $output_id = "{'speciesList'=>'" . join (",", $self->param('species_list')) . "', 'mlss_id'=>'\"\"'}";
	$self->dataflow_output_id($output_id,1);
	return;
    }

    print "WRITE OUTPUT\n" if ($self->debug);

    #Store locator for genome_db
    my $speciesList = $self->param('species');
    foreach my $species (@{$speciesList}) {
	my $genome_db = $species->{genome_db};
	$self->compara_dba->get_GenomeDBAdaptor->store($genome_db);
    }

    my $dna_collections = $self->param('dna_collections');

    #Write method_link and method_link_species_set database entries for pair_aligners
    foreach my $pair_aligner (@{$self->param('pair_aligners')}) {
	my ($method_link_id, $method_link_type) = @{$pair_aligner->{'method_link'}};
	my $ref_genome_db = $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'genome_db'};
	my $non_ref_genome_db = $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'genome_db'};
	
	my $mlss = write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
	$pair_aligner->{'mlss_id'} = $mlss->dbID;
    }

    #Write options and chunks entries to meta table
    $self->write_parameters_to_meta();

    #Write masking options
    foreach my $dna_collection (values %$dna_collections) {
	$self->write_masking_options($dna_collection);
    }

    #Create dataflows for pair_aligner parts of the pipeline
    $self->create_pair_aligner_dataflows();

    #Write method_link and method_link_species_set entries for chains and nets
    foreach my $chain_config (@{$self->param('chain_configs')}) {
	my ($method_link_id, $method_link_type) = @{$chain_config->{'output_method_link'}};
	my $ref_genome_db = $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'};
	my $non_ref_genome_db = $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'};
	
	my $mlss = write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
	$chain_config->{'mlss_id'} = $mlss->dbID;
    }

    foreach my $net_config (@{$self->param('net_configs')}) {
	my ($method_link_id, $method_link_type) = @{$net_config->{'output_method_link'}};
	my $ref_genome_db = $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'};
	my $non_ref_genome_db = $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'};
	
	my $mlss = write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
	$net_config->{'mlss_id'} = $mlss->dbID;
    }

    #Write dataflows for chaining and netting parts of the pipeline
    $self->create_chain_dataflows();
    $self->create_net_dataflows();

}

#
#Parse the configuration file
#
sub parse_conf {
    my ($self, $conf_file) = @_;
    
    unless ($conf_file and (-e $conf_file)) {
	die("No configuration file given");
    }

    #read configuration file from disk
    my @conf_list = @{do $conf_file};
    
    my $speciesList;
    my $dna_collections;
    my $pair_aligners;
    my $chain_configs;
    my $net_configs;

    foreach my $confPtr (@conf_list) {
	my $type = $confPtr->{TYPE};
	delete $confPtr->{TYPE};
	if($type eq 'SPECIES') {
	    push @{$speciesList} , $confPtr;
	} elsif ($type eq 'DNA_COLLECTION') {
	    my $name = $confPtr->{collection_name};
	    $dna_collections->{$name} = $confPtr;
	} elsif ($type eq 'PAIR_ALIGNER') {
	    push @{$pair_aligners} , $confPtr;
	} elsif ($type eq 'CHAIN_CONFIG') {
	    push @{$chain_configs} , $confPtr;
	} elsif ($type eq 'NET_CONFIG') {
	    push @{$net_configs} , $confPtr;
	}
    }

    #parse only the SPECIES fields to get a species_list only
    if ($self->param('get_species_list')) {
	$self->get_species($speciesList, $self->param('compara_url'));

	my @spp_names;
	foreach my $species (@{$speciesList}) {
	    push @spp_names, $species->{genome_db}->name,
	}
	my $species_list = join ",", @spp_names;
	$self->param('species_list', $species_list);
	return;
    }

    #Adding missing information in hash lists with default values
    $self->get_species($speciesList);
    $self->get_dna_collection($dna_collections, $speciesList);
    $self->get_pair_aligner($pair_aligners, $dna_collections);
    $self->get_chain_configs($chain_configs);
    $self->get_net_configs($net_configs);

    $self->param('species', $speciesList);
    $self->param('chain_configs', $chain_configs);
    $self->param('net_configs', $net_configs);
    $self->param('dna_collections', $dna_collections);

    #Make a collection of pair_aligners, chain_configs and net_configs
    my $all_configs;
    push @$all_configs, @$pair_aligners, @$chain_configs, @$net_configs;
    $self->param('all_configs', $all_configs);

}

#
#Get species fields
#
sub get_species {
    my ($self, $speciesList, $compara_url) = @_;

    print "SPECIES\n" if ($self->debug);
    my $gdb_adaptor;
    if (defined $compara_url) {
	my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara_url);
	$gdb_adaptor = $compara_dba->get_GenomeDBAdaptor;
    } else {
	$gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    }

    my $genome_dbs;
    foreach my $species (@{$speciesList}) {
	#get genome_db
	my $genome_db;
	if (defined $species->{genome_db_id}) {
	    $genome_db = $gdb_adaptor->fetch_by_dbID($species->{genome_db_id});
	} else {
	    unless(defined $species->{name}) {
		die ("Need a name to fetch genome_db");
	    }
	    $genome_db = $gdb_adaptor->fetch_by_name_assembly($species->{name});
	}
	$species->{'genome_db'} = $genome_db;
	$self->get_locator($genome_db);
    }
}

#
#Use heuristics to fill in missing information in DNA_COLLECTION
#
sub get_dna_collection {
    my ($self, $dna_collections, $speciesList) = @_;

    print "DNA_COLLECTION\n" if ($self->debug);
    my $gdb_adaptor = $self->compara_dba->get_GenomeDBAdaptor;
    foreach my $name (keys %{$dna_collections}) {
	my $dna_collection = $dna_collections->{$name};

	#Fill in genome_db
	if (defined $dna_collection->{'genome_db_id'}) {
	    $dna_collection->{'genome_db'} = $gdb_adaptor->fetch_by_dbID($dna_collection->{'genome_db_id'});
	    #print "genome_db_id " . $dna_collection->{'genome_db'}->name . "\n";
	} elsif (defined ($dna_collection->{'genome_name_assembly'})) {
	    my ($genome_name, $assembly) = split ":", $dna_collection->{'genome_name_assembly'};
	    $dna_collection->{'genome_db'} = $gdb_adaptor->fetch_by_name_assembly($genome_name, $assembly);
	    #print "genome_name_assembly " . $dna_collection->{'genome_db'}->name . "\n";
	} else {
	    #Check if first field of collection name is valid genome name
	    my @fields = split " ", $name;
	    foreach my $species (@$speciesList) {
		if ($species->{'genome_db'}->name eq $fields[0]) {
		    $dna_collection->{'genome_db'} = $species->{'genome_db'};
		    #print "collection_name " . $dna_collection->{'genome_db'}->name . "\n";
		}
	    }
	}
	#print "gdb " . $dna_collection->{'genome_db'}->name . "\n";
	#print_conf($dna_collection);
	#print "\n";
    }
}

#
#Use defaults to fill in missing information in PAIR_ALIGNER
#
sub get_pair_aligner {
    my ($self, $pair_aligners, $dna_collections) = @_;

    print "PAIR_ALIGNER\n" if ($self->debug);
    foreach my $pair_aligner (@{$pair_aligners}) {
	my $ref_collection_name = $pair_aligner->{'reference_collection_name'};
	my $non_ref_collection_name = $pair_aligner->{'non_reference_collection_name'};
	my $ref_dna_collection = $dna_collections->{$ref_collection_name};
	my $non_ref_dna_collection = $dna_collections->{$non_ref_collection_name};

	#Set default dna_collection chunking values if required
	$self->get_chunking($ref_dna_collection, $self->param('default_chunks')->{'reference'});
	$self->get_chunking($non_ref_dna_collection, $self->param('default_chunks')->{'non_reference'});

	#Set default pair_aligner values
	unless (defined $pair_aligner->{'method_link'}) {
	    $pair_aligner->{'method_link'} = $self->param('default_pair_aligner');
	}
	unless (defined $pair_aligner->{'analysis_template'}{'-parameters'}{'options'}) {
	    $pair_aligner->{'analysis_template'}{'-parameters'}{'options'} = $self->param('default_parameters');
	}
	#print_conf($pair_aligner);
	#print "\n";
    }
    $self->param('pair_aligners', $pair_aligners);
}

sub get_chunking {
   my ($self, $dna_collection, $default_chunk) = @_;

   #chunk_size
   unless (defined $dna_collection->{'chunk_size'}) {
       $dna_collection->{'chunk_size'} = $default_chunk->{'chunk_size'};
   }
   
   #overlap
   unless (defined $dna_collection->{'overlap'}) {
       $dna_collection->{'overlap'} = $default_chunk->{'overlap'};
   }
   
   #include_non_reference (haplotypes) and masking_options
   unless (defined $dna_collection->{'include_non_reference'}) {
       $dna_collection->{'include_non_reference'} = $default_chunk->{'include_non_reference'};
   }
   unless (defined $dna_collection->{'masking_options_file'}) {
       $dna_collection->{'masking_options_file'} = $default_chunk->{'masking_options_file'};
   }
   unless (defined $dna_collection->{'masking_options'}) {
       $dna_collection->{'masking_options'} = $default_chunk->{'masking_options'};
   }
   
   unless (defined $dna_collection->{'dump_loc'}) {
       $dna_collection->{'dump_loc'} = $default_chunk->{'dump_loc'};
   }
   #foreach my $key (keys %{$ref_dna_collection}) {
   #print "$key " . $ref_dna_collection->{$key} . "\n";
   #}

}

sub get_default_chunking {
    my ($dna_collection, $default_chunk) = @_;

    #chunk_size
    unless (defined $dna_collection->{'chunk_size'}) {
	$dna_collection->{'chunk_size'} = $default_chunk->{'chunk_size'};
    }

    #group_set_size
    unless (defined $dna_collection->{'group_set_size'}) {
	$dna_collection->{'group_set_size'} = $default_chunk->{'group_set_size'};
    }

    #overlap
    unless (defined $dna_collection->{'overlap'}) {
	$dna_collection->{'overlap'} = $default_chunk->{'overlap'};
    }

    #masking option file (currently only set for human which is always reference)
    unless (defined $dna_collection->{'masking_options_file'}) {
	$dna_collection->{'masking_options_file'} = $default_chunk->{'masking_options_file'};
    }

    #masking_option
    unless (defined $dna_collection->{'masking_options'}) {
	$dna_collection->{'masking_options'} = $default_chunk->{'masking_options'};
    }
    
    #dump location (currently never set for non-reference chunking)
    unless (defined $dna_collection->{'dump_loc'}) {
	$dna_collection->{'dump_loc'} = $default_chunk->{'dump_loc'};
    }

    unless (defined $dna_collection->{'dump_loc'}) {
	if (defined $default_chunk->{'dump_dir'}) {
	    $dna_collection->{'dump_loc'} = $default_chunk->{'dump_dir'} . "/" . $dna_collection->{'genome_db'}->name;
	}
    }
    
    foreach my $key (keys %{$dna_collection}) {
	print "    $key " . $dna_collection->{$key} . "\n";
    }
}

#
#Get chunking info for reference species. Use defaults to fill in missing information
#
sub get_reference_chunking {
    my ($self, $pair_aligner, $dna_collections) = @_;

    my $ref_collection_name = $pair_aligner->{'reference_collection_name'};
    my $ref_dna_collection = $dna_collections->{$ref_collection_name};

    my $default_chunks = $self->param('default_chunks');

    #chunk_size
    unless (defined $ref_dna_collection->{'chunk_size'}) {
	$ref_dna_collection->{'chunk_size'} = $default_chunks->{'reference'}{'chunk_size'};
    }
    
    #overlap
    unless (defined $ref_dna_collection->{'overlap'}) {
	$ref_dna_collection->{'overlap'} = $default_chunks->{'reference'}{'overlap'};
    }
    
    #include_non_reference (haplotypes) and masking_options
    unless (defined $ref_dna_collection->{'include_non_reference'}) {
	$ref_dna_collection->{'include_non_reference'} = $default_chunks->{'reference'}{'include_non_reference'};
    }
    unless (defined $ref_dna_collection->{'masking_options_file'}) {
	$ref_dna_collection->{'masking_options_file'} = $default_chunks->{'reference'}{'masking_options_file'};
    }
    unless (defined $ref_dna_collection->{'masking_options'}) {
	$ref_dna_collection->{'masking_options'} = $default_chunks->{'reference'}{'masking_options'};
    }

    #Find location to dump dna for tblat analyses. Can either be specific dump_loc or a dump_dir
    unless (defined $ref_dna_collection->{'dump_loc'}) {
	$ref_dna_collection->{'dump_loc'} = $default_chunks->{'reference'}{'dump_loc'};
    }
    unless (defined $ref_dna_collection->{'dump_loc'}) {
	if (defined $default_chunks->{'reference'}{'dump_dir'}) {
	    $ref_dna_collection->{'dump_loc'} = $default_chunks->{'reference'}{'dump_dir'} . "/" . $ref_dna_collection->{'genome_db'}->name;
	}
    }

    #foreach my $key (keys %{$ref_dna_collection}) {
	#print "$key " . $ref_dna_collection->{$key} . "\n";
    #}
}

#
#Get chunking info for non-reference species. Use defaults to fill in missing information
#
sub get_non_reference_chunking {
    my ($self, $pair_aligner, $dna_collections) = @_;

    my $default_chunks = $self->param('default_chunks');

    my $non_ref_collection_name = $pair_aligner->{'non_reference_collection_name'};
    my $non_ref_dna_collection = $dna_collections->{$non_ref_collection_name};

    #chunk_size
    unless (defined $non_ref_dna_collection->{'chunk_size'}) {
	$non_ref_dna_collection->{'chunk_size'} = $default_chunks->{'non_reference'}{'chunk_size'};
    }

    #group_set_size
    unless (defined $non_ref_dna_collection->{'group_set_size'}) {
	$non_ref_dna_collection->{'group_set_size'} = $default_chunks->{'non_reference'}{'group_set_size'};
    }

    #overlap
    unless (defined $non_ref_dna_collection->{'overlap'}) {
	$non_ref_dna_collection->{'overlap'} = $default_chunks->{'non_reference'}{'overlap'};
    }

    #masking option file (currently only set for human which is always reference)
    unless (defined $non_ref_dna_collection->{'masking_options_file'}) {
	$non_ref_dna_collection->{'masking_options_file'} = $default_chunks->{'non_reference'}{'masking_options_file'};
    }

    #masking_option
    unless (defined $non_ref_dna_collection->{'masking_options'}) {
	$non_ref_dna_collection->{'masking_options'} = $default_chunks->{'non_reference'}{'masking_options'};
    }
    
    #dump location (currently never set for non-reference chunking)
    unless (defined $non_ref_dna_collection->{'dump_loc'}) {
	$non_ref_dna_collection->{'dump_loc'} = $default_chunks->{'non_reference'}{'dump_loc'};
    }

    unless (defined $non_ref_dna_collection->{'dump_loc'}) {
	if (defined $default_chunks->{'non_reference'}{'dump_dir'}) {
	    $non_ref_dna_collection->{'dump_loc'} = $default_chunks->{'non_reference'}{'dump_dir'} . "/" . $non_ref_dna_collection->{'genome_db'}->name;
	}
    }

    #foreach my $key (keys %{$non_ref_dna_collection}) {
	#print "    $key " . $non_ref_dna_collection->{$key} . "\n";
    #}
}

sub get_chain_configs {
    my ($self, $chain_configs) = @_;

    foreach my $chain_config (@$chain_configs) {
	$chain_config->{'input_method_link'} = $self->param('default_chain_input') unless (defined $chain_config->{'input_method_link'});
	$chain_config->{'output_method_link'} = $self->param('default_chain_output') unless (defined $chain_config->{'output_method_link'});
    }
}

sub get_net_configs {
    my ($self, $net_configs) = @_;

    foreach my $net_config (@$net_configs) {
	$net_config->{'input_method_link'} = $self->param('default_net_input') unless (defined $net_config->{'input_method_link'});
	$net_config->{'output_method_link'} = $self->param('default_net_output') unless (defined $net_config->{'output_method_link'});
    }
}

#
#No pair_aligner configuration file provided. Use defaults
#
sub parse_defaults {
    my ($self) = @_;

    my $dna_collections;
    my $pair_aligners;
    my $chain_configs;
    my $net_configs;

    #Should be able to provide a list of mlss_ids
    if ($self->param('mlss_id')) {
	my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
	my $genome_dbs = $mlss->species_set;
	my $pair_aligner = {};
	$pair_aligner->{'method_link'} = $self->param('default_pair_aligner');
	$pair_aligner->{'analysis_template'}{'-parameters'}{'options'} = $self->param('default_parameters');

	my $chain_config = {};
	%$chain_config = ('input_method_link' => $self->param('default_chain_input'),
			  'output_method_link' => $self->param('default_chain_output'));

	my $net_config = {};
	%$net_config = ('input_method_link' => $self->param('default_net_input'),
			'output_method_link' => $self->param('default_net_output'));

	#create dna_collections
	foreach my $genome_db (@$genome_dbs) {

	    #get and store locator
	    $self->get_locator($genome_db);
	    $self->compara_dba->get_GenomeDBAdaptor->store($genome_db);

	    my $raw_name = $genome_db->name . " raw";
	    my $chain_name = $genome_db->name . " for chain";
	    my $dump_loc = $self->param('dump_dir') . "/" . $genome_db->name . "_nib_for_chain";

	    %{$dna_collections->{$raw_name}} = ('genome_db' => $genome_db);
	    %{$dna_collections->{$chain_name}} = ('genome_db' => $genome_db,
						  'dump_loc' => $dump_loc);

	    #create pair_aligners
	    if ($genome_db->name eq $self->param('ref_species')) {
		$pair_aligner->{'reference_collection_name'} = $raw_name;
		$chain_config->{'reference_collection_name'} = $chain_name;
		$net_config->{'reference_collection_name'} = $chain_name;
	    } else {
		$pair_aligner->{'non_reference_collection_name'} = $raw_name;
		$chain_config->{'non_reference_collection_name'} = $chain_name;
		$net_config->{'non_reference_collection_name'} = $chain_name;
	    }
	}
	throw ("Unable to find " . $self->param('ref_species') . " in this mlss " . $mlss->name . " (" . $mlss->dbID . ")") unless (defined $pair_aligner->{'reference_collection_name'});

	#Set default dna_collection chunking values if required
	get_default_chunking($dna_collections->{$pair_aligner->{'reference_collection_name'}}, $self->param('default_chunks')->{'reference'});	
	get_default_chunking($dna_collections->{$pair_aligner->{'non_reference_collection_name'}}, $self->param('default_chunks')->{'non_reference'});
	

	push @$pair_aligners, $pair_aligner;
	push @$chain_configs, $chain_config;
	push @$net_configs, $net_config;
    }
    $self->param('dna_collections', $dna_collections);
    $self->param('pair_aligners', $pair_aligners);
    $self->param('chain_configs', $chain_configs);
    $self->param('net_configs', $net_configs);

    #Make a collection of pair_aligners, chain_configs and net_configs
    my $all_configs;
    push @$all_configs, @$pair_aligners, @$chain_configs, @$net_configs;
    $self->param('all_configs', $all_configs);
}

#
#Write new method_link and method_link_species_set entries in database
#
sub write_mlss_entry {
    my ($compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db) = @_;

    #create method_link
    my $sql = "INSERT ignore into method_link SET method_link_id=$method_link_id, type='$method_link_type'";
    $compara_dba->dbc->do($sql);

    # create method_link_species_set
    my $mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
    $mlss->method_link_type($method_link_type);
    
    if ($ref_genome_db->dbID == $non_ref_genome_db->dbID) {
	$mlss->species_set([$ref_genome_db]);
    } else {
	$mlss->species_set([$ref_genome_db,$non_ref_genome_db]);
    } 
    $compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);
    return $mlss;
}

#
#Write options and chunk parameters to meta table
#
sub write_parameters_to_meta {
    my ($self) = @_;

    my $pair_aligners = $self->param('pair_aligners');
    my $dna_collections = $self->param('dna_collections');

    foreach my $pair_aligner (@$pair_aligners) {
	
	#Write pair aligner options to meta table for use with PairAligner jobs (eg lastz)
	my $key = "options_" . $pair_aligner->{'mlss_id'};
	my $meta_container = $self->compara_dba->get_MetaContainer;
	$meta_container->store_key_value($key, $pair_aligner->{'analysis_template'}->{'-parameters'}{'options'});
	
	#Write chunk options to meta table for use with FilterDuplicates
	my $ref_dna_collection = $dna_collections->{$pair_aligner->{'reference_collection_name'}};
	my $non_ref_dna_collection = $dna_collections->{$pair_aligner->{'non_reference_collection_name'}};

	my $chunk_data = "{'ref'=>{'chunk_size'=>'" . $ref_dna_collection->{'chunk_size'} . "','overlap'=>'". $ref_dna_collection->{'overlap'} . "'},'non_ref'=>{'chunk_size'=>'" . $non_ref_dna_collection->{'chunk_size'} . "', 'overlap'=>'". $non_ref_dna_collection->{'overlap'} . "'}}";

	$key = "chunk_" . $pair_aligner->{'mlss_id'};
	$meta_container->store_key_value($key, $chunk_data);
    }
}

#
#Write masking options to analysis_data table for now
#
sub write_masking_options {
    my ($self, $dna_collection) = @_;

    my $masking_options_file = $dna_collection->{'masking_options_file'};
    if (defined $masking_options_file && ! -e $masking_options_file) {
	throw("ERROR: masking_options_file $masking_options_file does not exist\n");
    }

    my $masking_options = $dna_collection->{'masking_options'};

    my $options_string = "";
    if (defined $masking_options_file) {
	my $options_hash_ref = do($masking_options_file);

	return unless($options_hash_ref);

	$options_string = "{\n";
	foreach my $key (keys %{$options_hash_ref}) {
	    $options_string .= "'$key'=>'" . $options_hash_ref->{$key} . "',\n";
	}
	$options_string .= "}";
    } elsif (defined $masking_options) {
	$options_string = $masking_options;
    } else {
	#No masking options defined
	return;
    }

    $dna_collection->{'masking_analysis_data_id'} =
      $self->compara_dba->get_AnalysisDataAdaptor->store_if_needed($options_string);

    #$dna_collection->{'masking_options'} = undef;
    #$dna_collection->{'masking_options_file'} = undef;
}


#
#Add dataflows for pair aligner part of pipeline
#
sub create_pair_aligner_dataflows {
    my ($self) = @_;

    my $speciesList = $self->param('species');
    my $dna_collections = $self->param('dna_collections');
    my $pair_aligners = $self->param('pair_aligners');

    foreach my $pair_aligner (@$pair_aligners) {

	my $mlss_id = $pair_aligner->{'mlss_id'};
	
	#
	#dataflow to create_pair_aligner_jobs
	#
	#'query_collection_name' => 'non_reference_collection_name'
	#'target_collection_name' => 'reference_collection_name'
	#
	my $output_id = "{'method_link_species_set_id'=>'$mlss_id','query_collection_name'=>'" . $pair_aligner->{'non_reference_collection_name'} . "','target_collection_name'=>'" . $pair_aligner->{'reference_collection_name'} . "'}";
	$self->dataflow_output_id($output_id,1);

	#
	#dataflow to create_filter_duplicates_jobs
	#
	#my $ref_output_id = "{'method_link_species_set_id'=>'$mlss_id','collection_name'=>'" . $pair_aligner->{'reference_collection_name'} . "'}";
	my $ref_output_hash = {};
	%$ref_output_hash = ('method_link_species_set_id'=>$mlss_id,
			     'collection_name'=> $pair_aligner->{'reference_collection_name'});

	#my $non_ref_output_id = "{'method_link_species_set_id'=>'$mlss_id','collection_name'=>'" . $pair_aligner->{'non_reference_collection_name'} . "'}";
	my $non_ref_output_hash = {};
	%$non_ref_output_hash = ('method_link_species_set_id'=>$mlss_id,
				 'collection_name'=>$pair_aligner->{'non_reference_collection_name'});

	$self->dataflow_output_id($ref_output_hash,3);
	$self->dataflow_output_id($non_ref_output_hash,3);

	#
	#dataflow to chunk_and_group_dna
	#
	my $output_hash = {};
	$output_hash->{'collection_name'} = $pair_aligner->{'reference_collection_name'};
	while (my ($key, $value) = each %{$dna_collections->{$pair_aligner->{'reference_collection_name'}}}) {
	    if (not ref($value)) {
		if (defined $value) {
		    $output_hash->{$key} = $value;
		}
	    } else {
		#genome_db_id
		$output_hash->{'genome_db_id'} = $value->dbID;
	    }
	}
	$self->dataflow_output_id($output_hash,2);

	$output_hash = {};
	$output_hash->{'collection_name'} = $pair_aligner->{'non_reference_collection_name'};
	while (my ($key, $value) = each %{$dna_collections->{$pair_aligner->{'non_reference_collection_name'}}}) {
	    if (not ref($value)) {
		if (defined $value) {
		    $output_hash->{$key} = $value;
		}
	    } else {
		#genome_db_id
		$output_hash->{'genome_db_id'} = $value->dbID;
	    }
	}
	$self->dataflow_output_id($output_hash,2);
	
	#
	#dataflow to dump_dna.
	#
	if (defined ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'dump_loc'})) {
	    my $dump_dna_hash;
	    $dump_dna_hash->{"collection_name"} = $pair_aligner->{'reference_collection_name'};
	    $self->dataflow_output_id($dump_dna_hash, 9);
	}
	if (defined ($dna_collections->{$pair_aligner->{'target_collection_name'}}->{'dump_loc'})) {
	    my $dump_dna_hash;
	    $dump_dna_hash->{"collection_name"} = $pair_aligner->{'target_collection_name'};
	    $self->dataflow_output_id($dump_dna_hash, 9);
	}
    }
}


#
#Add dataflows for chaining part of pipeline
#
sub create_chain_dataflows {
    my ($self) = @_;

    my $dna_collections = $self->param('dna_collections');
    my $pair_aligners = $self->param('pair_aligners');
    my $chain_configs = $self->param('chain_configs');
    my $net_configs = $self->param('net_configs');
    my $all_configs = $self->param('all_configs');

    foreach my $chain_config (@$chain_configs) {
	#
	#dataflow to no_chunk_and_group_dna
	#
	my $output_hash = {};
	$output_hash->{'collection_name'} = $chain_config->{'reference_collection_name'};
	while (my ($key, $value) = each %{$dna_collections->{$chain_config->{'reference_collection_name'}}}) {
	    if (not ref($value)) {
		$output_hash->{$key} = $value;
	    } else {
		#genome_db_id
		$output_hash->{'genome_db_id'} = $value->dbID;
	    }
	}
	$self->dataflow_output_id($output_hash,4);

	$output_hash = {};
	$output_hash->{'collection_name'} = $chain_config->{'non_reference_collection_name'};
	while (my ($key, $value) = each %{$dna_collections->{$chain_config->{'non_reference_collection_name'}}}) {
	    if (not ref($value)) {
		$output_hash->{$key} = $value;
	    } else {
		#genome_db_id
		$output_hash->{'genome_db_id'} = $value->dbID;
	    }
	}
	$self->dataflow_output_id($output_hash,4);
	
	my ($input_method_link_id, $input_method_link_type) = @{$chain_config->{'input_method_link'}};

	my $pair_aligner = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'}->name);
	throw("Unable to find the corresponding pair_aligner for the chain_config") unless (defined $pair_aligner);

	#my ($input_method_link_id, $input_method_link_type) = @{$pair_aligner->{'method_link'}};
	#my ($output_method_link_id, $output_method_link_type) = @{$chain_config->{'method_link'}};

	#
	#dataflow to create_alignment_chains_jobs
	#
	my $chain_output_hash = {};
	%$chain_output_hash = ('query_collection_name' => $chain_config->{'reference_collection_name'},
			       'target_collection_name' => $chain_config->{'non_reference_collection_name'},
			       'input_mlss_id' => $pair_aligner->{'mlss_id'},
			       'output_mlss_id' => $chain_config->{'mlss_id'},
			      );
	
	$self->dataflow_output_id($chain_output_hash,5);
    }
}

sub create_net_dataflows {
    my ($self) = @_;

    my $dna_collections = $self->param('dna_collections');
    my $pair_aligners = $self->param('pair_aligners');
    my $chain_configs = $self->param('chain_configs');
    my $net_configs = $self->param('net_configs');
    my $all_configs = $self->param('all_configs');

    foreach my $net_config (@$net_configs) {

	my $ref_species = $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name;
	my ($input_method_link_id, $input_method_link_type) = @{$net_config->{'input_method_link'}};
	my $chain_config = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name);


	my ($chain_input_method_link_id, $chain_input_method_link_type) = @{$chain_config->{'input_method_link'}};
	my $pairaligner_config = find_config($all_configs, $dna_collections, $chain_input_method_link_type, $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name);

	#
	#dataflow to create_alignment_nets_jobs
	#
	my $output_hash = {};
	%$output_hash = ('query_collection_name' => $net_config->{'reference_collection_name'},
			 'target_collection_name' => $net_config->{'non_reference_collection_name'},
			 'input_mlss_id' => $chain_config->{'mlss_id'},
			 'output_mlss_id' => $net_config->{'mlss_id'},
			);
	$self->dataflow_output_id($output_hash,6);

	#Dataflow to healthcheck
	my $healthcheck_hash = {};
	%$healthcheck_hash = ('test' => 'pairwise_gabs',
			      'mlss_id' => $net_config->{'mlss_id'});
	$self->dataflow_output_id($healthcheck_hash, 8);

	$healthcheck_hash = {};
	%$healthcheck_hash = ('test' => 'compare_to_previous_db',
			      'mlss_id' => $net_config->{'mlss_id'});
	$self->dataflow_output_id($healthcheck_hash, 8);
	

	#Dataflow to pairaligner_config
	my $pairaligner_hash = {};
	my $ref_dna_collection;
	my $non_ref_dna_collection;
	while (my ($key, $value) = each %{$dna_collections->{$pairaligner_config->{'reference_collection_name'}}}) {
	    if (defined $value && (not ref($value))) {
		$ref_dna_collection->{$key} = $value;
	    }
	}
	while (my ($key, $value) = each %{$dna_collections->{$pairaligner_config->{'non_reference_collection_name'}}}) {
	    if (defined $value && (not ref($value))) {
		$non_ref_dna_collection->{$key} = $value;
	    }
	}
	%$pairaligner_hash = ('ref_species' => $ref_species,
			       'mlss_id' => $net_config->{'mlss_id'},
			       'ref_dna_collection' => $ref_dna_collection,
			       'non_ref_dna_collection' => $non_ref_dna_collection,
			       'pair_aligner_options' => $pairaligner_config->{'analysis_template'}{'-parameters'}{'options'});
	$self->dataflow_output_id($pairaligner_hash,7);
    }
}

#
#Find pair_aligner with same reference and non-reference collection names as the chain_config. Return undef if not found
#
sub find_config {
    my ($all_configs, $dna_collections, $method_link_type, $ref_name, $non_ref_name) = @_;

    foreach my $config (@$all_configs) {
	my ($output_method_link_id,$output_method_link_type);
	if (defined $config->{'method_link'}) {
	    ($output_method_link_id,$output_method_link_type) = @{$config->{'method_link'}};
	} elsif (defined $config->{'output_method_link'}) {
	    ($output_method_link_id,$output_method_link_type) = @{$config->{'output_method_link'}};
	}
	if ($output_method_link_type eq $method_link_type && 
	    $dna_collections->{$config->{'reference_collection_name'}}->{'genome_db'}->name eq $ref_name &&
	    $dna_collections->{$config->{'non_reference_collection_name'}}->{'genome_db'}->name eq $non_ref_name) {
	    return $config;
	}
    }
    return undef;
}

sub print_conf {
    my ($conf) = @_;

    foreach my $key (keys %{$conf}) {
	if (ref($conf->{$key}) eq "ARRAY") {
	    foreach my $ele (@{$conf->{$key}}) {
		print "       $ele\n";
	    }
	} elsif (ref($conf->{$key}) eq "HASH") {
	    foreach my $k (keys %{$conf->{$key}}) {
		print "       $k => " . $conf->{$key}{$k} . "\n";
	    }
	} else {
	    print "    $key => " . $conf->{$key} . "\n";
	}
    }
}

sub print_pair_aligner {
    my ($pair_aligner) = @_;

    foreach my $key (keys %{$pair_aligner}) {
	if (ref($pair_aligner->{$key}) eq "ARRAY") {
	    foreach my $ele (@{$pair_aligner->{$key}}) {
		print "       $ele\n";
	    }
	} elsif (ref($pair_aligner->{$key}) eq "HASH") {
	    foreach my $k (keys %{$pair_aligner->{$key}}) {
		print "       $k => " . $pair_aligner->{$key}{$k} . "\n";
	    }
	} else {
	    print "    $key => " . $pair_aligner->{$key} . "\n";
	}
    }
}

#
#This should probably go elsewhere eventually
#
sub get_locator {
    my ($self, $genome_db) = @_;
    my $no_alias_check = 1;
    my $this_core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($genome_db->name, 'core', $no_alias_check);
    if (!defined $this_core_dba) {
	die("Unable to find a suitable core database from the registry\n");
    }
    my $this_assembly = $this_core_dba->extract_assembly_name();
    my $this_start_date = $this_core_dba->get_MetaContainer->get_genebuild();
    
    my $genebuild = $genome_db->genebuild;
    my $assembly_name = $genome_db->assembly;
    
    $genebuild ||= $this_start_date;
    $assembly_name ||= $this_assembly;
    
    my $core_dba;
    if($this_assembly eq $assembly_name && $this_start_date eq $genebuild) {
	$core_dba = $this_core_dba;
    } else {
	#The assembly.default and coord_system.version names should be the same
	throw "Found assembly '$this_assembly' when looking for '$assembly_name' or '$this_start_date' when looking for '$genebuild'";
    }
    
    if (defined $core_dba) {
	#print "locator " . $core_dba->locator . "\n";
	$genome_db->locator($core_dba->locator);
    }

}

#
#Taken from LoadOneGenomeDB
#
sub Bio::EnsEMBL::DBSQL::DBAdaptor::extract_assembly_name {  # with much regret I have to introduce the highly demanded method this way
    my $self = shift @_;

    my ($cs) = @{$self->get_CoordSystemAdaptor->fetch_all()};
    my $assembly_name = $cs->version;

    return $assembly_name;
}

sub Bio::EnsEMBL::DBSQL::DBAdaptor::locator {  # this is another similar hack (to be included or at least offered for inclusion into Core codebase)
    my $self         = shift @_;

    my $dbc = $self->dbc();

    return sprintf(
          "%s/host=%s;port=%s;user=%s;pass=%s;dbname=%s;species=%s;species_id=%s;disconnect_when_inactive=%d",
          ref($self), $dbc->host(), $dbc->port(), $dbc->username(), $dbc->password(), $dbc->dbname(), $self->species, $self->species_id, 1,
    );
}


sub load_registry_dbs {
    my ($registry_dbs) = @_;
    
    #my $registry_dbs = $these_registry_dbs->[0];


    #my $species_name = $self->param('species_name');
    for(my $r_ind=0; $r_ind<scalar(@$registry_dbs); $r_ind++) {
	
	#Bio::EnsEMBL::Registry->load_registry_from_db( %{ $registry_dbs->[$r_ind] }, -species_suffix => $suffix_separator.$r_ind );
	Bio::EnsEMBL::Registry->load_registry_from_db( %{ $registry_dbs->[$r_ind] }, -verbose=>1);

=remove	
	my $no_alias_check = 1;
	my $this_core_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($species_name.$suffix_separator.$r_ind, 'core', $no_alias_check) || next;
	my $this_assembly = $this_core_dba->extract_assembly_name();
	my $this_start_date = $this_core_dba->get_MetaContainer->get_genebuild();
    
	$genebuild ||= $this_start_date;
	$assembly_name ||= $this_assembly;
	
	if($this_assembly eq $assembly_name && $this_start_date eq $genebuild) {
	    $core_dba = $this_core_dba;
	    
	    if($self->param('first_found')) {
		last;
	    }
	} else {
	    warn "Found assembly '$this_assembly' when looking for '$assembly_name' or '$this_start_date' when looking for '$genebuild'";
	}

=cut

    } # try next registry server

}


1;
