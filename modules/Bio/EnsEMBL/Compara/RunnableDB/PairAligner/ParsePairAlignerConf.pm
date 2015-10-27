=head1 LICENSE

Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute

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
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Compara::Utils::CoreDBAdaptor;

use Bio::EnsEMBL::Utils::Exception qw(throw verbose);
use Bio::EnsEMBL::Hive::Utils 'stringify';

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
    if ($self->param('core_dbs')) {
	#list of individual core databases
	foreach my $core_db (@{$self->param('core_dbs')}) {
	    new Bio::EnsEMBL::DBSQL::DBAdaptor(%$core_db);
	} 
    }
    if ($self->param('registry_dbs')) {
	load_registry_dbs($self->param('registry_dbs'));
    } elsif ($self->param('reg_conf')) { 	    
      Bio::EnsEMBL::Registry->load_all($self->param('reg_conf'));
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
	#Auto-detect if need to use patches ie only use patches if the non-reference species has chromosomes
	#(because these are the only analyses that we keep up-to-date by running the patch-pipeline)

	if ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} && 
            $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} == -1) {
	    if (defined $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'region'}) {
		my ($coord_system_name, $name) = split ":", $dna_collections->{$pair_aligner->{'non_reference_collection_name'}}->{'region'};
		if ($coord_system_name eq 'chromosome') {
		    $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} = 1;
		} else {
		    $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} = 0;
		}

	    } else {
		if($non_ref_genome_db->has_karyotype){
		    $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} = 1;
		} else {
		    $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} = 0;
		}
	    }
	}
	
        if ($dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'}) {
            print "include_non_reference " . $dna_collections->{$pair_aligner->{'reference_collection_name'}}->{'include_non_reference'} . "\n" if ($self->debug);
	}

	my $mlss = write_mlss_entry($self->compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db);
	$pair_aligner->{'mlss_id'} = $mlss->dbID;

	#Write options and chunks entries to method_link_species_set_tag table
	#Write parameters and dna_collection with raw mlss_id for use in downstream analyses
	$self->write_parameters_to_mlss_tag($mlss, $pair_aligner);
    }

    #Create dataflows for pair_aligner parts of the pipeline
    $self->create_pair_aligner_dataflows();

    #Write dataflow to chunk_and_group_dna (2) and dump_dna_factory(9)
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
	    $self->dataflow_output_id($output_hash, 9);
        }
    }

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
	    $self->get_species($speciesList, $self->param('master_db'));
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
    my ($self, $speciesList, $master_db) = @_;

    print "SPECIES\n" if ($self->debug);
    my $gdb_adaptor;
    if ($master_db) {
	my $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->go_figure_compara_dba( $master_db );
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

        #Set default dna_collection chunking values
        $self->get_chunking($ref_dna_collection, $self->param('default_chunks')->{'reference'});
        $self->get_chunking($non_ref_dna_collection, $self->param('default_chunks')->{'non_reference'});

        #Set default pair_aligner values
        unless (defined $pair_aligner->{'method_link'}) {
            $pair_aligner->{'method_link'} = $self->param('default_pair_aligner');
        }

	my $params = eval($pair_aligner->{'analysis_template'}{'-parameters'});
	print "options " . $params->{'options'} . "\n" if ($self->debug);
	if ($params->{'options'}) {
	    $pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $params->{'options'};
        } else {
	    $pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $self->param('default_parameters');
        }
	print_conf($pair_aligner);
	print "\n" if ($self->debug);
    }
    $self->param('pair_aligners', $pair_aligners);
}

#
#Fill in missing information in the conf file from the default_chunk 
#
sub get_chunking {
   my ($self, $dna_collection, $default_chunk) = @_;

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
	    $dna_collection->{'dump_loc'} = $default_chunk->{'dump_dir'} . "/" . $dump_dir_species . "/" . $dna_collection->{'genome_db'}->name;
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
	$genome_dbs = $mlss->species_set_obj->genome_dbs;
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
        my %pair = (
            'ref_genome_db'     => $genome_dbs->[0],
            'non_ref_genome_db' => $genome_dbs->[0],
        );
	push @$collection, \%pair;
    }

    foreach my $pair (@$collection) {
	#print $pair->{ref_genome_db}->name . " " . $pair->{non_ref_genome_db}->name . "\n";
	
	my $pair_aligner = {};
	$pair_aligner->{'method_link'} = $self->param('default_pair_aligner');
	$pair_aligner->{'analysis_template'}{'parameters'}{'options'} = $self->param('default_parameters');
    
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
	$pair_aligner->{'reference_collection_name'} = $pair->{ref_genome_db}->name . " raw";
	$chain_config->{'reference_collection_name'} = $pair->{ref_genome_db}->name . " for chain";
	#$net_config->{'reference_collection_name'} = $pair->{ref_genome_db}->name . " for chain";

        #What to do about all vs all which will not have a net_ref_species
        #Check net_ref_species is a member of the pair
        if ((!$self->param('net_ref_species')) || ($self->param('net_ref_species') eq $pair->{ref_genome_db}->name)) {
            $net_config->{'reference_collection_name'} = $pair->{ref_genome_db}->name . " for chain";
            $net_config->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->name . " for chain";
        } elsif ($self->param('net_ref_species') eq $pair->{non_ref_genome_db}->name) {
            $net_config->{'reference_collection_name'} = $pair->{non_ref_genome_db}->name . " for chain";
            $net_config->{'non_reference_collection_name'} = $pair->{ref_genome_db}->name . " for chain";
        } else {
            throw ("Net reference species " . $self->param('net_ref_species') . " must be either " . $pair->{ref_genome_db}->name . " or " . $pair->{non_ref_genome_db}->name );
        }

	my $dump_loc = $self->param('dump_dir') . "/" . $pair->{ref_genome_db}->name . "_nib_for_chain";
	
	%{$dna_collections->{$pair_aligner->{'reference_collection_name'}}} = ('genome_db' => $pair->{ref_genome_db});
	%{$dna_collections->{$chain_config->{'reference_collection_name'}}} = ('genome_db' => $pair->{ref_genome_db},
									      'dump_loc' => $dump_loc);

	$pair_aligner->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->name . " raw";;
	$chain_config->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->name . " for chain";
	#$net_config->{'non_reference_collection_name'} = $pair->{non_ref_genome_db}->name . " for chain";

        # self-alignments would have the same names for "reference" and
        # "non-reference" collections otherwise
        if ($pair->{ref_genome_db}->name eq $pair->{non_ref_genome_db}->name) {
            $net_config->{'non_reference_collection_name'} .= ' again';
            $pair_aligner->{'non_reference_collection_name'} .= ' again';
            $chain_config->{'non_reference_collection_name'} .= ' again';
        }
	    
	$dump_loc = $self->param('dump_dir') . "/" . $pair->{non_ref_genome_db}->name . "_nib_for_chain";
	
	%{$dna_collections->{$pair_aligner->{'non_reference_collection_name'}}} = ('genome_db' => $pair->{non_ref_genome_db});
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
        if (($ref_species eq $genome_db->dbID) or ($ref_species eq $genome_db->name)) {
            $ref_genome_db = $genome_db;
        } else {
            push @non_ref_gdbs, $genome_db;
        }
    }

    return ($ref_genome_db, @non_ref_gdbs);
}


#
#Write new method_link and method_link_species_set entries in database
#
sub write_mlss_entry {
    my ($compara_dba, $method_link_id, $method_link_type, $ref_genome_db, $non_ref_genome_db) = @_;

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

    my $method = Bio::EnsEMBL::Compara::Method->new(
        -type               => $method_link_type,
        -dbID               => $method_link_id,
	-class              => "GenomicAlignBlock.pairwise_alignment",
    );

    my $species_set_obj = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -genome_dbs         => ($ref_genome_db->dbID == $non_ref_genome_db->dbID)
                                        ? [$ref_genome_db]
                                        : [$ref_genome_db,$non_ref_genome_db]
    );

    my $mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
        -method             => $method,
        -species_set_obj    => $species_set_obj,
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

	my $pair_aligner = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'}->name);
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

#	my $pair_aligner = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$chain_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$chain_config->{'non_reference_collection_name'}}->{'genome_db'}->name);
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

	my $ref_species = $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name;
	my $non_ref_species = $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name;

	#
	#Write ref_species and non_ref_species to method_link_species_set_tag table
	#
	my $mlss_adaptor = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor;
	my $mlss = $mlss_adaptor->fetch_by_dbID($net_config->{'mlss_id'});

	$mlss->store_tag("reference_species", $ref_species);
	$mlss->store_tag("non_reference_species", $non_ref_species);


	my ($input_method_link_id, $input_method_link_type) = @{$net_config->{'input_method_link'}};
	my $chain_config = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name);
        #If chain_config not found, try swapping reference_collection_name and non_reference_collection_name (which may be different for the net than the chain)
        unless ($chain_config) {
            $chain_config = find_config($all_configs, $dna_collections, $input_method_link_type, $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name);
        }

	my ($chain_input_method_link_id, $chain_input_method_link_type) = @{$chain_config->{'input_method_link'}};
	my $pairaligner_config = find_config($all_configs, $dna_collections, $chain_input_method_link_type, $dna_collections->{$net_config->{'reference_collection_name'}}->{'genome_db'}->name, $dna_collections->{$net_config->{'non_reference_collection_name'}}->{'genome_db'}->name);
        
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
    #Load from SPECIES tag in conf_file
    if ($species->{dbname}) {
	my $port = $species->{port} || 3306;
	my $species_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(
							     -host => $species->{host},
							     -user => $species->{user},
							     -port => $port,
							     -species => $species->{species},
							     -dbname => $species->{dbname});
	$genome_db = update_genome_db($species_dba, $self->compara_dba, $species->{genome_db_id});
	update_dnafrags($self->compara_dba, $genome_db, $species_dba);

    } elsif ($species->{-dbname}) {
	#Load form curr_core_dbs_locs in default_options file
	my $species_dba = new Bio::EnsEMBL::DBSQL::DBAdaptor(%$species);
	$genome_db = update_genome_db($species_dba, $self->compara_dba);
	update_dnafrags($self->compara_dba, $genome_db, $species_dba);	
    }

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

      $genome_db = Bio::EnsEMBL::Compara::GenomeDB->new(
          -DB_ADAPTOR => $species_dba,
      );

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

=head2 update_dnafrags

  Arg[1]      : Bio::EnsEMBL::Compara::DBSQL::DBAdaptor $compara_dba
  Arg[2]      : Bio::EnsEMBL::Compara::GenomeDB $genome_db
  Arg[3]      : Bio::EnsEMBL::DBSQL::DBAdaptor $species_dba
  Description : This method fetches all the dnafrag in the compara DB
                corresponding to the $genome_db. It also gets the list
                of top_level seq_regions from the species core DB and
                updates the list of dnafrags in the compara DB.
  Returns     : -none-
  Exceptions  :

=cut

sub update_dnafrags {
  my ($compara_dba, $genome_db, $species_dba) = @_;

  my $dnafrag_adaptor = $compara_dba->get_adaptor("DnaFrag");
  my $old_dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db);
  my $old_dnafrags_by_id;
  foreach my $old_dnafrag (@$old_dnafrags) {
    $old_dnafrags_by_id->{$old_dnafrag->dbID} = $old_dnafrag;
  }

  my $sql1 = qq{
      SELECT
        cs.name,
        sr.name,
        sr.length
      FROM
        coord_system cs,
        seq_region sr,
        seq_region_attrib sra,
        attrib_type at
      WHERE
        sra.attrib_type_id = at.attrib_type_id
        AND at.code = 'toplevel'
        AND sr.seq_region_id = sra.seq_region_id
        AND sr.coord_system_id = cs.coord_system_id
        AND cs.species_id =?
    };
  my $sth1 = $species_dba->dbc->prepare($sql1);
  $sth1->execute($species_dba->species_id());
  my $current_verbose = verbose();
  verbose('EXCEPTION');
  while (my ($coordinate_system_name, $name, $length) = $sth1->fetchrow_array) {

    #Find out if region is_reference or not
    my $slice = $species_dba->get_SliceAdaptor->fetch_by_region($coordinate_system_name,$name);
    my $is_reference = $slice->is_reference;

    my $new_dnafrag = new Bio::EnsEMBL::Compara::DnaFrag(
            -genome_db => $genome_db,
            -coord_system_name => $coordinate_system_name,
            -name => $name,
            -length => $length,
            -is_reference => $is_reference
        );
    my $dnafrag_id = $dnafrag_adaptor->update($new_dnafrag);
    delete($old_dnafrags_by_id->{$dnafrag_id});
    throw() if ($old_dnafrags_by_id->{$dnafrag_id});
  }
  verbose($current_verbose);
  print "Deleting ", scalar(keys %$old_dnafrags_by_id), " former DnaFrags...";
  foreach my $deprecated_dnafrag_id (keys %$old_dnafrags_by_id) {
    $compara_dba->dbc->do("DELETE FROM dnafrag WHERE dnafrag_id = ".$deprecated_dnafrag_id) ;
  }
  print "  ok!\n\n";
}

1;
