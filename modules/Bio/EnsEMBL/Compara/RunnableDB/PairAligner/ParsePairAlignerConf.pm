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


=head1 CONTACT

  Please email comments or questions to the public Ensembl
  developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

  Questions may also be sent to the Ensembl help desk at
  <http://www.ensembl.org/Help/Contact>.

=head1 NAME

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf 

=head1 SYNOPSIS

If master_db defined then use populate_new_database which needs either mlss_id or a list of species provided from the conf_file. Use conf_file when adding multiple pairwise analyses. If have only one pairwise, then define mlss_id in the master.

If master_db is not defined, must populate the compara database from either core databases defined in conf_file or in default_options (core_dbs). Create genome_dbs, the genome_db_id is defined in the conf_file but not in the default_options. Create mlss_ids.

ERROR:
If no master_db, no conf_file and no core_dbs.

=head1 DESCRIPTION

Parse configuration file 

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::ParsePairAlignerConf;

use strict;
use warnings;
use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

use File::Path;

use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;
use Bio::EnsEMBL::Compara::Utils::MasterDatabase;

use Bio::EnsEMBL::Utils::Exception qw(throw verbose);
use Bio::EnsEMBL::Hive::Utils 'stringify';

use Data::Dumper;
$Data::Dumper::Maxdepth = 2;

my $verbose = 0;

#my $suffix_separator = '__cut_here__';

sub fetch_input {
    my ($self) = @_;
    if (!$self->param('master_db') && !$self->param('core_dbs') && !$self->param('conf_file')) {
	throw("No master database is provided so you must set the define the location of core databases using a configuration file ('conf_file') or the 'curr_core_dbs_locs' parameter in the init_pipeline configuration file");
    }

    #Return if no conf file and trying to get the species list or there is no master_db in which case cannot call
    #populate_new_database
    if (!$self->param('conf_file') &&  $self->param('get_species_list') || !$self->param('master_db')) {
	return;
    }
    #
    #Must load the registry first
    #
    
    if ($self->param('reg_conf')) { 	    
    	## die if file cannot be loaded
    	$self->load_registry($self->param('reg_conf'));
    } elsif ($self->param('core_dbs')) {
		#list of individual core databases
		foreach my $core_db (@{$self->param('core_dbs')}) {
		    new Bio::EnsEMBL::DBSQL::DBAdaptor(%$core_db);
		} 
    } elsif ($self->param('registry_dbs')) {
		load_registry_dbs($self->param('registry_dbs'));
    }
}

sub run {
    my ($self) = @_;

    #Return if no conf file and trying to get the species list or there is no master_db in which case cannot call
    #populate_new_database
    if ($self->param('get_species_list') && (!$self->param('conf_file') || !$self->param('master_db'))) {
	return;
    }

    #If no pair_aligner configuration file, use the defaults
    if ($self->param('conf_file')) {
	#parse configuration file
	$self->parse_conf($self->param('conf_file'));
    } else {
	$self->parse_defaults();
    }

}

sub write_output {
    my ($self) = @_;

    #No configuration file or no master_db, so no species list. Flow an empty speciesList
    if ($self->param('get_species_list') && (!$self->param('conf_file') || !$self->param('master_db'))) {
	my $output_id = {'speciesList' => ''};
	$self->dataflow_output_id($output_id,1);
	return;
    }

    #Have configuration file and getting only the speciesList. Dataflow to populate_new_database
    if ($self->param('get_species_list')) {
	my $output_id = {'speciesList' => $self->param('species_list'), 'mlss_id' => ''};
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

    #Create ChunkAndGroupDna analysis jobs
    #Need to get all the pair_aligner dna_collection names
    my $pair_aligner_collection_names;
    foreach my $pair_aligner (@{$self->param('pair_aligners')}) {
        $pair_aligner_collection_names->{$pair_aligner->{'reference_collection_name'}} = 1;
        $pair_aligner_collection_names->{$pair_aligner->{'non_reference_collection_name'}} = 1;
    }

    #Write method_link and method_link_species_set database entries for pair_aligners
    foreach my $pair_aligner (@{$self->param('pair_aligners')}) {
	my ($method_link_id, $method_link_type) = @{$pair_aligner->{'method_link'}};
	my $ref_genome_db = $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'genome_db'};
	my $non_ref_genome_db = $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'genome_db'};
	#If include_non_reference is in auto-detect mode (-1), need to auto-detect!
	#Auto-detect if need to use patches ie only use patches if the non-reference species has a karyotype
	#(because these are the only analyses that we keep up-to-date by running the patch-pipeline)
        #with the exception of self-alignments

	if ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} && 
            $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} == -1) {
		if($non_ref_genome_db->has_karyotype && ($non_ref_genome_db->dbID != $ref_genome_db->dbID)){
		    $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} = 1;
		} else {
		    $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} = 0;
		}
	}
	
        if ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'}) {
            print "include_non_reference " . $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} . "\n" if ($self->debug);
	}

	my $mlss = $self->write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
	$pair_aligner->{'mlss_id'} = $mlss->dbID;

	#Write options and chunks entries to method_link_species_set_tag table
	#Write parameters and dna_collection with raw mlss_id for use in downstream analyses
	$self->write_parameters_to_mlss_tag($mlss, $pair_aligner);
    }

    #Create dataflows for pair_aligner parts of the pipeline
    $self->create_pair_aligner_dataflows();

    #Write dataflow to chunk_and_group_dna (2)
    foreach my $dna_collection (keys %$pair_aligner_collection_names) {
        #print "dna_collection $dna_collection\n";

        #
	#dataflow to chunk_and_group_dna
	#
	my $output_hash = {};
        
        #Set collection_name (hash key of this dna_collection)
	$output_hash->{'collection_name'} = $dna_collection;
	while (my ($key, $value) = each %{$dna_collections->{$dna_collection}}) {
	    if (not ref($value)) {
		if (defined $value) {
		    $output_hash->{$key} = $value;
		}
	    } elsif ($key eq "genome_db") {
		#genome_db_id
		$output_hash->{'genome_db_id'} = $value->dbID;
	    }
	}
	$self->dataflow_output_id($output_hash,2);
        if (defined $dna_collections->{$dna_collection}->{'dump_loc'}) {
            mkpath($dna_collections->{$dna_collection}->{'dump_loc'});
        }
    }

    #Write method_link and method_link_species_set entries for chains and nets
    foreach my $chain_config (@{$self->param('chain_configs')}) {
	my ($method_link_id, $method_link_type) = @{$chain_config->{'output_method_link'}};
	my $ref_genome_db = $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'};
	my $non_ref_genome_db = $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'};
	my $mlss = $self->write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
	$chain_config->{'mlss_id'} = $mlss->dbID;
    }

    foreach my $net_config (@{$self->param('net_configs')}) {
	my ($method_link_id, $method_link_type) = @{$net_config->{'output_method_link'}};
	my $ref_genome_db = $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'};
	my $non_ref_genome_db = $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'};
	
	my $mlss = $self->write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
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
    my $pair_aligners = [];
    my $chain_configs= [];
    my $net_configs = [];

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
	my @spp_names;
	if ($self->param('master_db')) {
	    $self->get_species($speciesList, 'in_master_db');
	    foreach my $species (@{$speciesList}) {
		push @spp_names, $species->{genome_db}->name,
	    }
	}

	my $species_list = join ",", @spp_names;
	$self->param('species_list', $species_list);
	return;
    }

    #No master, so copy dnafrags from core_db
    unless ($self->param('master_db')) {
	foreach my $species (@{$speciesList}) {
	    #populate_database if necessary
	    #Need to load from core database
	    $self->populate_database_from_core_db($species);
	}
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
    my ($self, $speciesList, $in_master_db) = @_;

    print "SPECIES\n" if ($self->debug);
    my $gdb_adaptor;
    if ($in_master_db) {
	my $compara_dba = $self->get_cached_compara_dba('master_db');
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
	    unless(defined $species->{species}) {
		die ("Need a name to fetch genome_db");
	    }
	    $genome_db = $gdb_adaptor->fetch_by_name_assembly($species->{species});
	}
	$species->{'genome_db'} = $genome_db;

	if ($species->{host}) {
	    #already have core db location defined
	    my $port = $species->{port} || 3306;
	    my $core_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(
							     -host => $species->{host},
							     -user => $species->{user},
							     -port => $port,
							     -species => $species->{species},
							     -dbname => $species->{dbname});
	    $genome_db->locator($core_dba->locator);
	    next;
	}

      $genome_db->locator($genome_db->db_adaptor->locator);
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
	    #print "genome_db_id " . $dna_collection->{'genome_db'}->toString . "\n";
	} elsif (defined ($dna_collection->{'genome_name_assembly'})) {
	    my ($genome_name, $assembly) = split ":", $dna_collection->{'genome_name_assembly'};
	    $dna_collection->{'genome_db'} = $gdb_adaptor->fetch_by_name_assembly($genome_name, $assembly);
	    #print "genome_name_assembly " . $dna_collection->{'genome_db'}->toString . "\n";
	} else {
	    #Check if first field of collection name is valid genome name
	    my @fields = split " ", $name;
	    foreach my $species (@$speciesList) {
		if (_name_matches($species->{'genome_db'}, $fields[0])) {
		    $dna_collection->{'genome_db'} = $species->{'genome_db'};
		    #print "collection_name " . $dna_collection->{'genome_db'}->toString . "\n";
		}
	    }
	}
	#print "gdb " . $dna_collection->{'genome_db'}->toString . "\n";
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

        #Set default dna_collection chunking values
        $self->get_chunking($ref_dna_collection, $self->param('default_chunks')->{'reference'});
        $self->get_chunking($non_ref_dna_collection, $self->param('default_chunks')->{'non_reference'});

        #Set default pair_aligner values
        unless (defined $pair_aligner->{'method_link'}) {
            $pair_aligner->{'method_link'} = $self->param('default_pair_aligner');
        }

	$self->set_pair_aligner_options( $pair_aligner, $ref_dna_collection->{'genome_db'}, $non_ref_dna_collection->{'genome_db'} );
	print_conf($pair_aligner);
	print "\n" if ($self->debug);
    }
    $self->param('pair_aligners', $pair_aligners);
}

#
# given a datastructure like {'ss1' => 'settings1', 'ss2' => 'settings2', 'default' => 'def_settings'}
# set the correct pair aligner parameters. 'settings2', for example, will be used when both ref and non-ref
# genome_db_ids are part of the species_set named 'ss2'. 'default' will be used if the species do not appear
# together in any of the given collections
#

sub set_pair_aligner_options {
	my ($self, $pair_aligner, $ref_genome_db, $non_ref_genome_db) = @_;

	# legacy code - not willing to touch #
	if ( defined $pair_aligner->{'analysis_template'} ) {
		my $params = eval($pair_aligner->{'analysis_template'}{'-parameters'});
		print "options " . $params->{'options'} . "\n" if ($self->debug && $params->{'options'});
		if ($params->{'options'}) {
		   $pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $params->{'options'};
		   return;
	    } 
	}
    #####################################

    # check master for species sets - only pairwise LASTZ species set is copied locally
	my $compara_dba = $self->get_cached_compara_dba('master_db');
	my $gdb_adaptor = $compara_dba->get_GenomeDBAdaptor;

	# check if static or dynamic params are being used
	# static = string input; dynamic = hash ref input
	my $default_parameters = $self->param('default_parameters');
	unless ( ref($default_parameters) ) { # input is not a ref - assume string and set params
		$pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $default_parameters;
		return;
	}

	# read in per-species_set settings
	my %taxon_settings = %{ $self->param('default_parameters') };

	my $default_settings = $taxon_settings{'default'};
	delete $taxon_settings{'default'};

	# keep track of the size of the clade - in cases where multiple
	# clades apply to a single pair, the smallest clade 'wins'
	my $this_clade_size = 1000; 
	my $these_settings;
	foreach my $tax_id ( keys %taxon_settings ) {
		my @clade_gdbs = @{$gdb_adaptor->fetch_all_by_ancestral_taxon_id($tax_id)};

		 # ensure that the smallest taxonomic group settings are applied
		 # when dealing with nested sets
		next if ( defined $these_settings && scalar(@clade_gdbs) >= $this_clade_size );
		$this_clade_size = scalar @clade_gdbs;

		# if both ref and non-ref are present, use these settings
		my $found_ref     = grep { $_->dbID == $ref_genome_db->dbID } @clade_gdbs;
		my $found_non_ref = grep { $_->dbID == $non_ref_genome_db->dbID } @clade_gdbs;
		
		$these_settings = $taxon_settings{$tax_id} if ( $found_ref && $found_non_ref );
	}

	$these_settings = $default_settings unless ( defined $these_settings );
	my ($ref_name, $non_ref_name) = ( $ref_genome_db->name, $non_ref_genome_db->name );
	print "!!! $ref_name - $non_ref_name PAIR_ALIGNER SETTINGS: $these_settings\n";
	$pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $these_settings;
}

#
#Fill in missing information in the conf file from the default_chunk 
#
sub get_chunking {
   my ($self, $dna_collection, $default_chunk) = @_;

   # need to check if human-specific chunking params exist
   # incoming structure would be a hash if so
   $self->get_chunking($dna_collection, $default_chunk->{$dna_collection->{'genome_db'}->name} || $default_chunk->{default}) if exists $default_chunk->{default};

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
   
   #include_non_reference (haplotypes)
   unless (defined $dna_collection->{'include_non_reference'}) {
       $dna_collection->{'include_non_reference'} = $default_chunk->{'include_non_reference'};
   }

   #set masking_option if neither masking_option_file or masking_options has been set
   unless (defined $dna_collection->{'masking_options'} || defined $dna_collection->{'masking_options_file'}) {
       $dna_collection->{'masking_options'} = $default_chunk->{'masking_options'};
   }
   
   #Check that only masking_options OR masking_options_file have been defined
   if (defined $dna_collection->{'masking_options'} && defined $dna_collection->{'masking_options_file'}) {
       throw("Both masking_options and masking_options_file have been defined. Please only define EITHER masking_options OR masking_options_file");
   }

   unless (defined $dna_collection->{'dump_loc'}) {
       $dna_collection->{'dump_loc'} = $default_chunk->{'dump_loc'};
   }
   #foreach my $key (keys %{$dna_collection}) {
   #    print "$key " . $dna_collection->{$key} . "\n";
   #}

}

sub get_default_chunking {
    my ($dna_collection, $default_chunk, $dump_dir_species) = @_;

   # need to check if human-specific chunking params exist
   # incoming structure would be a hash if so
   get_default_chunking($dna_collection, $default_chunk->{$dna_collection->{'genome_db'}->name} || $default_chunk->{default}) if exists $default_chunk->{default};


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

    #region
    unless (defined $dna_collection->{'region'}) {
	$dna_collection->{'region'} = $default_chunk->{'region'};
    }
 
    #include_non_reference (haplotypes) and masking_options
    unless (defined $dna_collection->{'include_non_reference'}) {
	$dna_collection->{'include_non_reference'} = $default_chunk->{'include_non_reference'};
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
	    $dna_collection->{'dump_loc'} = $default_chunk->{'dump_dir'} . "/" . $dump_dir_species . "/" . $dna_collection->{'genome_db'}->dbID . "_" . $dna_collection->{'genome_db'}->_get_unique_name;
	}
    }
    
    #foreach my $key (keys %{$dna_collection}) {
	#print "    $key " . $dna_collection->{$key} . "\n";
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

    #parse only the SPECIES fields to get a species_list only

    my $genome_dbs;
    my $mlss;

    #No master, so copy dnafrags from core_db
    unless ($self->param('master_db')) {
	if ($self->param('core_dbs')) {
	    foreach my $core_db (@{$self->param('core_dbs')}) {
		push @$genome_dbs, ($self->populate_database_from_core_db($core_db));
	    }
	} else {
	    die "Must define location of core dbs to load dnafrags";
	}
    }
    #Should be able to provide a list of mlss_ids
    if ($self->param('mlss_id')) {
	my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	$mlss = $mlss_adaptor->fetch_by_dbID($self->param('mlss_id'));
	$genome_dbs = $mlss->species_set->genome_dbs;
    } 
    #load genome_dbs from a collection
    if ($self->param('collection')) {
        my $collection = $self->param('collection');
        my $ss_adaptor = $self->compara_dba->get_SpeciesSetAdaptor();
        my $ss = $ss_adaptor->fetch_collection_by_name($collection);
        $genome_dbs = $ss->genome_dbs;
    }

    #Create a collection of pairs from the list of genome_dbs
    my $collection;
    if (@$genome_dbs > 2) {

        if ($self->param('ref_species')) {
            #ref vs all

            my ($ref_genome_db, @non_ref_gdbs) = $self->find_reference_species($genome_dbs);
            die "Cannot find reference species " . $self->param('ref_species') . " in collection " . $self->param('collection') unless ($ref_genome_db);
            foreach my $genome_db (@non_ref_gdbs) {
                my $pair = { 'ref_genome_db' => $ref_genome_db, 'non_ref_genome_db' => $genome_db };
                push @$collection, $pair;
            }
        } else {
            #all vs all

            #Check that default_chunks->reference is the same as default_chunks->non_reference otherwise there will be
            #unpredictable consequences ie a dna_collection is not specific to whether the species is ref or non-ref.

            my @chunk_keys_checks = ( "masking_options_file", "masking_options" );
            foreach my $key (@chunk_keys_checks) {
                if ($self->param('default_chunks')->{'reference'}{$key} ne $self->param('default_chunks')->{'non_reference'}{$key}) {
                    throw "The default_chunks parameters MUST be the same for reference and non_reference. Please edit your init_pipeline config file. $key: ref=" . $self->param('default_chunks')->{'reference'}{$key} . " non_ref=" . $self->param('default_chunks')->{'non_reference'}{$key} . "\n";
                }
            }

            #Have a collection. Make triangular matrix, ordered by genome_db_id?
            
            #Check the dna_collection is the same for reference and non-reference
            my @ordered_genome_dbs = sort {$b->dbID <=> $a->dbID} @$genome_dbs;
            while (@ordered_genome_dbs) {
                my $ref_genome_db = shift @ordered_genome_dbs;
                foreach my $genome_db (@ordered_genome_dbs) {
                    my $pair;
                    %$pair = ('ref_genome_db'     => $ref_genome_db,
                              'non_ref_genome_db' => $genome_db);
                    push @$collection, $pair;
                }
            }
        }
    } elsif (@$genome_dbs == 2) {
        my ($ref_genome_db, @non_ref_gdbs) = $self->find_reference_species($genome_dbs);
	#Normal case of a pair of species
        my $pair = { 'ref_genome_db' => $ref_genome_db, 'non_ref_genome_db' => $non_ref_gdbs[0] };
	unless ($ref_genome_db) {
	    if ($mlss) {
		throw ("Unable to find " . $self->param('ref_species') . " in this mlss " . $mlss->name . " (" . $mlss->dbID . ")") 
	    } else {
		throw ("Unable to find " . $self->param('ref_species') . " in these genome_dbs (" . join ",", @$genome_dbs . ")")
	    }
	}
	push @$collection, $pair;
    } else {
        # Self-alignment
        my %pair = (
            'ref_genome_db'     => $genome_dbs->[0],
            'non_ref_genome_db' => $genome_dbs->[0],
        );
	push @$collection, \%pair;
    }

    foreach my $pair (@$collection) {
	#print $pair->{ref_genome_db}->dbID . " vs " . $pair->{non_ref_genome_db}->dbID . "\n";
	
	my $pair_aligner = {};
	$pair_aligner->{'method_link'} = $self->param('default_pair_aligner');
	$self->set_pair_aligner_options( $pair_aligner, $pair->{'ref_genome_db'}, $pair->{'non_ref_genome_db'} );
	# $pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $self->param('default_parameters');
    
	my $chain_config = {};
	%$chain_config = ('input_method_link' => $self->param('default_chain_input'),
			  'output_method_link' => $self->param('default_chain_output'));
	
	my $net_config = {};
	%$net_config = ('input_method_link' => $self->param('default_net_input'),
			'output_method_link' => $self->param('default_net_output'));

	#If used input mlss, check if the method_link_type is the same as the value defined in the conf file used in init_pipeline
	if ($mlss && ($self->param('default_net_output')->[1] ne $mlss->method->type)) {
	    warn("The default net_output_method_link " . $self->param('default_net_output')->[1] . " is not the same as the type " . $mlss->method->type . " of the mlss_id (" . $mlss->dbID .") used. Using " . $self->param('default_net_output')->[1] .".\n");
	}
	
	my @genome_db_ids;
	#create dna_collections
	#foreach my $genome_db (@$genome_dbs) {
	foreach my $genome_db ($pair->{ref_genome_db}, $pair->{non_ref_genome_db}) {
	    #get and store locator
          $genome_db->locator($genome_db->db_adaptor->locator);
	    $self->compara_dba->get_GenomeDBAdaptor->store($genome_db);
	    
	    push @genome_db_ids, $genome_db->dbID;
	    
	}
	
	#create pair_aligners
	$pair_aligner->{'reference_collection_name'} = $pair->{ref_genome_db}->dbID . " raw";
	$chain_config->{'reference_collection_name'} = $pair->{ref_genome_db}->dbID . " for chain";
	#$net_config->{'reference_collection_name'} = $pair->{ref_genome_db}->dbID . " for chain";

        #What to do about all vs all which will not have a net_ref_species
        #Check net_ref_species is a member of the pair
        if ((!$self->param('net_ref_species')) || _name_matches($pair->{ref_genome_db}, $self->param('net_ref_species'))) {
            $net_config->{'reference_collection_name'} = $pair->{ref_genome_db}->dbID . " for chain";
            $net_config->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->dbID . " for chain";
        } elsif (_name_matches($pair->{non_ref_genome_db}, $self->param('net_ref_species'))) {
            $net_config->{'reference_collection_name'} = $pair->{non_ref_genome_db}->dbID . " for chain";
            $net_config->{'non_reference_collection_name'} = $pair->{ref_genome_db}->dbID . " for chain";
        } else {
            throw (sprintf('Net reference species must be either %s (%s) or %s ($s). Currently %s', $pair->{ref_genome_db}->_get_unique_name, $pair->{ref_genome_db}->dbID, $pair->{non_ref_genome_db}->_get_unique_name, $pair->{non_ref_genome_db}->dbID, $self->param('net_ref_species') ));
        }

	my $dna_dump_loc = $self->param('dump_dir') . "/dna/";
	my $dump_loc = $self->param('dump_dir') . "/" . $pair->{ref_genome_db}->dbID . "_nib_for_chain";
	
	%{$dna_collections->{$pair_aligner->{'reference_collection_name'}}} = ('genome_db' => $pair->{ref_genome_db}, 'dump_loc' => $dna_dump_loc);
	%{$dna_collections->{$chain_config->{'reference_collection_name'}}} = ('genome_db' => $pair->{ref_genome_db},
									      'dump_loc' => $dump_loc);

	$pair_aligner->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->dbID . " raw";;
	$chain_config->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->dbID . " for chain";
	#$net_config->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->dbID . " for chain";

        # self-alignments would have the same names for "reference" and
        # "non-reference" collections otherwise
        if ($pair->{ref_genome_db}->dbID eq $pair->{non_ref_genome_db}->dbID) {
            $net_config->{'non_reference_collection_name'} .= ' again';
            $pair_aligner->{'non_reference_collection_name'} .= ' again';
            $chain_config->{'non_reference_collection_name'} .= ' again';
        }
	    
	$dump_loc = $self->param('dump_dir') . "/" . $pair->{non_ref_genome_db}->dbID . "_nib_for_chain";
	
	%{$dna_collections->{$pair_aligner->{'non_reference_collection_name'}}} = ('genome_db' => $pair->{non_ref_genome_db}, 'dump_loc' => $dna_dump_loc);
	%{$dna_collections->{$chain_config->{'non_reference_collection_name'}}} = ('genome_db' => $pair->{non_ref_genome_db},
										   'dump_loc' => $dump_loc);

	#create unique subdirectory to dump dna using genome_db_ids
	my $dump_dir_species = join "_", @genome_db_ids;
	
	#Set default dna_collection chunking values if required
	get_default_chunking($dna_collections->{$pair_aligner->{'reference_collection_name'}}, $self->param('default_chunks')->{'reference'}, $dump_dir_species);	
	get_default_chunking($dna_collections->{$pair_aligner->{'non_reference_collection_name'}}, $self->param('default_chunks')->{'non_reference'}, $dump_dir_species);
    
	#Store region, if defined, in the chain_config for use in no_chunk_and_group_dna
	if ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'region'}) {
	    $dna_collections->{$chain_config->{'reference_collection_name'}}->{'region'} = 
	      $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'region'};
	}
	if ($dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'region'}) {
	    $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'region'} = 
	      $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'region'};
	}
	#Store include_non_reference, if defined, in the chain_config for use in no_chunk_and_group_dna
#	if ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'}) {
#	    $dna_collections->{$chain_config->{'reference_collection_name'}}->{'include_non_reference'} = 
#	      $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'};
#	}
#	if ($dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'include_non_reference'}) {
#	    $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'include_non_reference'} = 
#	      $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'include_non_reference'};
#	}
	
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

sub find_reference_species {
    my ($self, $genome_dbs) = @_;

    my $ref_species = $self->param('ref_species');
    my $ref_genome_db;
    my @non_ref_gdbs;

    foreach my $genome_db (@$genome_dbs) {
        if (_name_matches($genome_db, $ref_species)) {
            $ref_genome_db = $genome_db;
        } else {
            push @non_ref_gdbs, $genome_db;
        }
    }

    return ($ref_genome_db, @non_ref_gdbs);
}

sub _name_matches {
    my ($genome_db, $name) = @_;
    return 0 unless $name;
    return (($name eq $genome_db->dbID) or ($name eq $genome_db->_get_unique_name));
}

#
#Write new method_link and method_link_species_set entries in database
#
sub write_mlss_entry {
    my ($self, $compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db) = @_;

    my $ref_name;
    my $name;

    foreach my $species_name ($ref_genome_db->name, $non_ref_genome_db->name) {
        $species_name =~ s/\b(\w)/\U$1/g;
        $species_name =~ s/(\S)\S+\_/$1\./;
        $species_name = substr($species_name, 0, 5);
        $ref_name = $species_name unless ($ref_name);
        $name .= $species_name."-";
    }
    $name =~ s/\-$//;
    my $type = lc($method_link_type);
    $type =~ s/_/\-/g;
    $name .= " $type (on $ref_name)";
    my $source = "ensembl";

    my $genome_dbs = ($ref_genome_db->dbID == $non_ref_genome_db->dbID) ? [$ref_genome_db] : [$ref_genome_db,$non_ref_genome_db];

    if ($compara_dba->get_MethodAdaptor->fetch_by_type($method_link_type)) {
        my $existing_mlss = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_method_link_type_GenomeDBs($method_link_type, $genome_dbs);
        return $existing_mlss if $existing_mlss;
        #die "The MLSS entry for ${method_link_type}x(".join("+", map {$_->name} @$genome_dbs).") does not exist in the master databse." if $self->param('master_db');
    }

    my $method = Bio::EnsEMBL::Compara::Method->new(
        -type               => $method_link_type,
        -dbID               => $method_link_id,
	-class              => "GenomicAlignBlock.pairwise_alignment",
    );

    my $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -genome_dbs         => $genome_dbs,
    );

    my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method             => $method,
        -species_set    => $species_set,
        -name               => $name,
        -source             => $source,
    );

    $compara_dba->get_MethodLinkSpeciesSetAdaptor->store($mlss);

    return $mlss;
}

#
#Write options and chunk parameters to method_link_species_set_tag table
#
#sub write_parameters_to_meta {
sub write_parameters_to_mlss_tag {
    my ($self, $mlss, $pair_aligner) = @_;

    my $dna_collections = $self->param('dna_collections');
    #Write pair aligner options to mlss_tag table for use with PairAligner jobs (eg lastz)
    my $this_param = $mlss->get_value_for_tag("param");

    my $ensembl_cvs_root_dir = $ENV{'ENSEMBL_CVS_ROOT_DIR'};

    if ($this_param) {
        my $analysis_params = $pair_aligner->{'analysis_template'}->{'parameters'}{'options'};
        #Need to convert "Q=" if present
        if ($ensembl_cvs_root_dir && $pair_aligner->{'analysis_template'}->{'parameters'}{'options'} =~ /(.*Q=)$ensembl_cvs_root_dir(.*)/) {
            $analysis_params = $1.'$ENSEMBL_CVS_ROOT_DIR'.$2;
        } 

        if ($this_param ne $analysis_params) {
            throw "Trying to store a different set of options (" . $pair_aligner->{'analysis_template'}->{'parameters'}{'options'} . ") for the same method_link_species_set ($this_param). This is currently not supported";
        }
    } else {
        #Convert expanded $ensembl_cvs_root_dir to the string '$ENSEMBL_CVS_ROOT_DIR' if it is present, else store the param as it is
        if ($ensembl_cvs_root_dir && $pair_aligner->{'analysis_template'}->{'parameters'}{'options'} =~ /(.*Q=)$ensembl_cvs_root_dir(.*)/) {
            $mlss->store_tag("param",  $1.'$ENSEMBL_CVS_ROOT_DIR'.$2);
        } else {
            $mlss->store_tag("param", $pair_aligner->{'analysis_template'}->{'parameters'}{'options'});
        }
    }

    #Write chunk options to mlss_tag table for use with FilterDuplicates
    my $ref_dna_collection = $dna_collections->{$pair_aligner->{'reference_collection_name'}};
    my $non_ref_dna_collection = $dna_collections->{$pair_aligner->{'non_reference_collection_name'}};
    
    #Write dna_collection hash
    my $ref_collection;
    foreach my $key (keys %$ref_dna_collection) {
        if (defined $ref_dna_collection->{$key} && $key ne "genome_db") {
            #skip dump_loc
            next if (defined $ref_dna_collection->{$key} && $key eq "dump_loc");
            
            #Convert masking_options_file to $ENSEMBL_CVS_ROOT_DIR if defined
            if ($key eq "masking_options_file") {
                my $ensembl_cvs_root_dir = $ENV{'ENSEMBL_CVS_ROOT_DIR'};
                if ($ENV{'ENSEMBL_CVS_ROOT_DIR'} && $ref_dna_collection->{$key} =~ /^$ensembl_cvs_root_dir(.*)/) {
                    $ref_collection->{$key} = '$ENSEMBL_CVS_ROOT_DIR'.$1;
                }
            } else {
                $ref_collection->{$key} =  $ref_dna_collection->{$key};
            }
        }
    }
    my $non_ref_collection;
    
    foreach my $key (keys %$non_ref_dna_collection) {
        if (defined $non_ref_dna_collection->{$key} && $key ne "genome_db") {
            #Convert masking_options_file to $ENSEMBL_CVS_ROOT_DIR if defined
            #skip dump_loc
            next if (defined $non_ref_dna_collection->{$key} && $key eq "dump_loc");
            
            if ($key eq "masking_options_file") {
                my $ensembl_cvs_root_dir = $ENV{'ENSEMBL_CVS_ROOT_DIR'};
                if ($ENV{'ENSEMBL_CVS_ROOT_DIR'} && $non_ref_dna_collection->{$key} =~ /^$ensembl_cvs_root_dir(.*)/) {
                    $non_ref_collection->{$key} = '$ENSEMBL_CVS_ROOT_DIR'.$1;
                }
            } else {
                $non_ref_collection->{$key} =  $non_ref_dna_collection->{$key};
            }
        }
    }
    #print "mlss_id " . $mlss->dbID . "\n";
    #print "Store tag ref " . stringify($ref_collection) . "\n";
    #print "Store tag non_ref " . stringify($non_ref_collection) . "\n";

    $mlss->store_tag("ref_dna_collection", stringify($ref_collection));
    $mlss->store_tag("non_ref_dna_collection", stringify($non_ref_collection));

}

#
#Write masking options to method_link_species_set_tag table
#
sub write_masking_options {
    my ($self, $dna_collection, $mlss, $tag) = @_;

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
    $mlss->store_tag($tag, $options_string);

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
	#my $output_id = "{'method_link_species_set_id'=>'$mlss_id','query_collection_name'=>'" . $pair_aligner->{'non_reference_collection_name'} . "','target_collection_name'=>'" . $pair_aligner->{'reference_collection_name'} . "'}";
        my $output_hash = {};
        %$output_hash = ('method_link_species_set_id'=>$mlss_id,
                         'query_collection_name'     => $pair_aligner->{'non_reference_collection_name'},
                         'target_collection_name'    => $pair_aligner->{'reference_collection_name'});

#Necessary if I want to flow this to the pairaligner jobs
#                         'options'                   => $pair_aligner->{'analysis_template'}->{'parameters'}{'options'});

	$self->dataflow_output_id($output_hash,1);

	#
	#dataflow to create_filter_duplicates_jobs
	#
	my $ref_output_hash = {};
	%$ref_output_hash = ('method_link_species_set_id'=>$mlss_id,
			     'is_reference' => 1,
			     'collection_name'=> $pair_aligner->{'reference_collection_name'},
			     'chunk_size' => $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'chunk_size'},
			     'overlap' => $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'overlap'});

	my $non_ref_output_hash = {};
	%$non_ref_output_hash = ('method_link_species_set_id'=>$mlss_id,
				 'is_reference' => 0,
				 'collection_name'=>$pair_aligner->{'non_reference_collection_name'},
				 'chunk_size' => $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'chunk_size'},
				 'overlap' => $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'overlap'});

	$self->dataflow_output_id($ref_output_hash,3);
	$self->dataflow_output_id($non_ref_output_hash,3);
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

	my ($input_method_link_id, $input_method_link_type) = @{$chain_config->{'input_method_link'}};

	my $pair_aligner = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'}->dbID, $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'}->dbID);
	throw("Unable to find the corresponding pair_aligner for the chain_config") unless (defined $pair_aligner);

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
        #Set include_non_reference from the corresponding pair_aligner config
        if (defined $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{include_non_reference}) {
            $output_hash->{'include_non_reference'} = $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{include_non_reference};
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
        #Set include_non_reference from the corresponding pair_aligner config
        if (defined $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{include_non_reference}) {
            $output_hash->{'include_non_reference'} = $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{include_non_reference};
        }
	$self->dataflow_output_id($output_hash,4);
	
#	my ($input_method_link_id, $input_method_link_type) = @{$chain_config->{'input_method_link'}};

#	my $pair_aligner = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'}->dbID, $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'}->dbID);
#	throw("Unable to find the corresponding pair_aligner for the chain_config") unless (defined $pair_aligner);

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
    my $bidirectional = $self->param('bidirectional');

    foreach my $net_config (@$net_configs) {

	my $ref_species_name = $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name;
	my $non_ref_species_name = $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name;

	#
	#Write ref_species_name and non_ref_species_name to method_link_species_set_tag table
	#
	my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlss_adaptor->fetch_by_dbID($net_config->{'mlss_id'});

	$mlss->store_tag("reference_species", $ref_species_name);
	$mlss->store_tag("non_reference_species", $non_ref_species_name);

        if ($dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->genome_component) {
            $mlss->store_tag('reference_component', $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->genome_component);
        }
        if ($dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->genome_component) {
            $mlss->store_tag('non_reference_component', $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->genome_component);
        }

	my $ref_species = $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->dbID;
	my $non_ref_species = $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->dbID;

	my ($input_method_link_id, $input_method_link_type) = @{$net_config->{'input_method_link'}};
	my $chain_config = find_config($all_configs, $dna_collections, $input_method_link_type, $ref_species, $non_ref_species);
        #If chain_config not found, try swapping reference_collection_name and non_reference_collection_name (which may be different for the net than the chain)
        unless ($chain_config) {
            $chain_config = find_config($all_configs, $dna_collections, $input_method_link_type, $non_ref_species, $ref_species);
        }

	my ($chain_input_method_link_id, $chain_input_method_link_type) = @{$chain_config->{'input_method_link'}};
	my $pairaligner_config = find_config($all_configs, $dna_collections, $chain_input_method_link_type, $ref_species, $non_ref_species);
        
        $self->write_parameters_to_mlss_tag($mlss, $pairaligner_config);

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

	if ($bidirectional) {

           # Let's do it bidirectional by swapping the reference and non-reference species
          
           $output_hash = {};
           %$output_hash = ('query_collection_name' => $net_config->{'non_reference_collection_name'},
                            'target_collection_name' => $net_config->{'reference_collection_name'},
                            'input_mlss_id' => $chain_config->{'mlss_id'},
                            'output_mlss_id' => $net_config->{'mlss_id'},
               );
           $self->dataflow_output_id($output_hash,6);

           #
           #dataflow to create_filter_duplicates_net_jobs
           #
           my $ref_output_hash = {};
           %$ref_output_hash = ('method_link_species_set_id'=>$net_config->{'mlss_id'},
                                'is_reference' => 1,
                                'collection_name'=> $net_config->{'reference_collection_name'},
                                'chunk_size' => $dna_collections->{$net_config->{'reference_collection_name'}}->{'chunk_size'},
                                'overlap' => $dna_collections->{$net_config->{'reference_collection_name'}}->{'overlap'});

           my $non_ref_output_hash = {};
           %$non_ref_output_hash = ('method_link_species_set_id'=>$net_config->{'mlss_id'},
                                    'is_reference' => 0,
                                    'collection_name'=>$net_config->{'non_reference_collection_name'},
                                    'chunk_size' => $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'chunk_size'},
                                    'overlap' => $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'overlap'});

           $self->dataflow_output_id($ref_output_hash,10);
           $self->dataflow_output_id($non_ref_output_hash,10);
       }

	#Dataflow to healthcheck

	if ($self->param('do_pairwise_gabs')) {
	    my $healthcheck_hash = {};
	    %$healthcheck_hash = ('test' => 'pairwise_gabs',
				  'mlss_id' => $net_config->{'mlss_id'});
	    $self->dataflow_output_id($healthcheck_hash, 8);
	}

	if ($self->param('do_compare_to_previous_db')) {
	    my $healthcheck_hash = {};
	    %$healthcheck_hash = ('test' => 'compare_to_previous_db',
				  'mlss_id' => $net_config->{'mlss_id'});
	    $self->dataflow_output_id($healthcheck_hash, 8);
	}

	#Dataflow to pairaligner_stats
	my $pairaligner_hash = {};
	%$pairaligner_hash = ('mlss_id' => $net_config->{'mlss_id'},
			      'raw_mlss_id' => $pairaligner_config->{'mlss_id'});

	$self->dataflow_output_id($pairaligner_hash,7);
    }
}

#
#Find pair_aligner with same reference and non-reference collection names as the chain_config. Return undef if not found
#
sub find_config {
    my ($all_configs, $dna_collections, $method_link_type, $ref_genome_db_id, $non_ref_genome_db_id) = @_;

    foreach my $config (@$all_configs) {
	my ($output_method_link_id,$output_method_link_type);
	if (defined $config->{'method_link'}) {
	    ($output_method_link_id,$output_method_link_type) = @{$config->{'method_link'}};
	} elsif (defined $config->{'output_method_link'}) {
	    ($output_method_link_id,$output_method_link_type) = @{$config->{'output_method_link'}};
	}
	if ($output_method_link_type eq $method_link_type &&
            ($dna_collections->{$config->{'reference_collection_name'}}->{'genome_db'}->dbID == $ref_genome_db_id) &&
            ($dna_collections->{$config->{'non_reference_collection_name'}}->{'genome_db'}->dbID == $non_ref_genome_db_id)) {
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
#Taken from LoadOneGenomeDB
#


sub load_registry_dbs {
    my ($registry_dbs) = @_;
    
    #my $registry_dbs = $these_registry_dbs->[0];

    #my $species_name = $self->param('species_name');
    for(my $r_ind=0; $r_ind<scalar(@$registry_dbs); $r_ind++) {
	
	#Bio::EnsEMBL::Registry->load_registry_from_db( %{ $registry_dbs->[$r_ind] }, -species_suffix => $suffix_separator.$r_ind );
	Bio::EnsEMBL::Registry->load_registry_from_db( %{ $registry_dbs->[$r_ind] }, -verbose=>1);

    } # try next registry server

}

#
#If no master is present, populate the compara database from the core databases. 
#Assign genome_db from SPECIES config if one is given
#
sub populate_database_from_core_db {
    my ($self, $species) = @_;

    my $genome_db;
    my $species_dba;
    #Load from SPECIES tag in conf_file
    if ($species->{dbname}) {
	my $port = $species->{port} || 3306;
	$species_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(
							     -host => $species->{host},
							     -user => $species->{user},
							     -port => $port,
							     -species => $species->{species},
							     -dbname => $species->{dbname});
	$genome_db = update_genome_db($species_dba, $self->compara_dba, $species->{genome_db_id});

    } elsif ($species->{-dbname}) {
	#Load form curr_core_dbs_locs in default_options file
	$species_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(%$species);
	$genome_db = update_genome_db($species_dba, $self->compara_dba);
    }

    Bio::EnsEMBL::Compara::Utils::MasterDatabase::update_dnafrags($self->compara_dba, $genome_db, $species_dba);

    return ($genome_db);
}

#Taken from update_genome.pl
sub update_genome_db {
    my ($species_dba, $compara_dba, $genome_db_id) = @_;

    my $compara = $compara_dba->dbc->dbname;
    my $genome_db_adaptor = $compara_dba->get_GenomeDBAdaptor();
    
    my $genome_db = eval {$genome_db_adaptor->fetch_by_core_DBAdaptor($species_dba)};

    if ($genome_db) {
      my $species_production_name = $genome_db->name;
      my $this_assembly = $genome_db->assembly;
	throw "GenomeDB with this name [$species_production_name] and assembly".
	  " [$this_assembly] is already in the compara DB [$compara]\n";
    }

	#Need to remove FOREIGN KEY to ncbi_taxa_node which is not necessary for pairwise alignments
	#Check if foreign key exists
	my $sql = "SHOW CREATE TABLE genome_db";

	my $sth = $compara_dba->dbc()->prepare($sql);
	$sth->execute();

	my $foreign_key = 0;
	while (my $row = $sth->fetchrow_array) {
	    if ($row =~ /FOREIGN KEY/) {
		$foreign_key = 1;
	    }
	}
	$sth->finish();

	if ($foreign_key) {
	    $compara_dba->dbc()->do('ALTER TABLE genome_db DROP FOREIGN KEY genome_db_ibfk_1');
	}

      $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new_from_DBAdaptor( $species_dba );

      if (not defined $genome_db->name) {
	    throw "Cannot get the species name from the database ".$species_dba->dbname;
      } elsif (not defined $genome_db->taxon_id) {
          my $species_name = $genome_db->name;
          throw "Cannot find species.taxonomy_id in meta table for $species_name.\n";
      }
      print "New GenomeDB for Compara: ", $genome_db->toString, "\n";

	if (defined $genome_db_id) {
          $genome_db->dbID($genome_db_id);
	}

      $genome_db_adaptor->store($genome_db);

    return $genome_db;
}


1;
