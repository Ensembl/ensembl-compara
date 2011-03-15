#!/software/bin/perl -w

=head1 NAME

update_config_database.pl

head1 AUTHORS

Kathryn Beal (kbeal@ebi.ac.uk)

=head1 COPYRIGHT

This modules is part of the Ensembl project http://www.ensembl.org

=head1 DESCRIPTION

This script parses pairwise alignment configuration files, writes the details into a config database and calculates various
statistics on the final alignment, such as coverage.

=head1 SYNOPSIS

perl update_config_database.pl --conf_file ~/work/compara_releases/release_60/kb3_hsap_amel_lastz_60/lastz.conf --config_url mysql://user:pass@host:port/kb3_pair_aligner_config_test --ref_url mysql://user\@host/version --non_ref_url  mysql://user@host/version --compara_url mysql://user@host:port/kb3_hsap_amel_lastz_60 --ref_species homo_sapiens --mlss_id 483

perl update_config_database.pl
   [--reg_conf registry configuration file]
   [--conf_file pair aligner configuration file]
   [--config_url pair aligner configuration database]
   --ref_species reference species
   --ref_url core database for reference species
   [--non_ref_url core database for non-reference species]
   --compara_url compara database
   --mlss_id method_link_species_set_id
   [--ensembl_release ensembl schema version]
   
=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--config_url mysql://user[:passwd]@host[:port]/dbname]>
Location of the configuration database

=item B<[--conf_file filename]>
Path to the pair aligner configuaration file

=item B<[--compara_url mysql://user[:passwd]@host[:port]/dbname]>
Location of the compara database containing the pairwise alignment

=item B<--ref_species species>

Species to be used as the reference

=item B<--ref_url mysql://user[:passwd]@host[:port]/version>

Core database containing the species defined in ref_species

=item B<[--non_ref_url mysql://user[:passwd]@host[:port]/version]>

Core database containing the other species in the pairwise alignment. This need not be defined 
if both species are in the same core database

=item B<--mlss_id method_link_species_set_id>

Method link species set id of the pairwise alignment

=item B<--ensembl_release ensembl schema version>

If this is not defined, the schema version is taken from the meta container. For retrospective additions, this may not be correct and hence the need to define it here

=item  B<[--ref_genome_bed filename]>

Location of the genome bed file for the reference species. Default location defined in $bed_file_location variable

=item  B<[--ref_coding_exons_bed filename]>

Location of the coding exons bed file for the reference species. Default location defined in $bed_file_location variable

=item  B<[--non_ref_genome_bed filename]>

Location of the genome bed file for the non-reference species. Default location defined in $bed_file_location variable

=item  B<[--non_ref_coding_exons_bed filename]>

Location of the coding exons bed file for the non-reference species. Default location defined in $bed_file_location variable

=item  B<[--ref_alignment_bed filename]>

Location of the alignment bed file for the reference species. Default is to create this file automatically in the current directory

=item  B<[--non_ref_alignment_bed filename]>

Location of the alignment bed file for the non-reference species. Default is to create this file automatically in the current directory

=cut

use warnings;
use strict;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Utils::Exception qw(throw);
use Getopt::Long;
use DBI;

my $usage = qq{
perl update_config_database.pl
  Getting help:
    [--help]

  Options:
   [--config_url mysql://user[:passwd]\@host[:port]/dbname]
      Location of the configuration database

   [--conf_file filename]
      Path to the pair aligner configuaration file

   [--compara_url mysql://user[:passwd]\@host[:port]/dbname]
      Location of the compara database containing the pairwise alignment

    --ref_species species
       Species to be used as the reference

    --ref_url mysql://user[:passwd]\@host[:port]/version
       Core database containing the species defined in ref_species

    --non_ref_url mysql://user[:passwd]\@host[:port]/version]
       Core database containing the other species in the pairwise alignment. This need not be defined 
       if both species are in the same core database

    --mlss_id method_link_species_set_id
       Method link species set id of the pairwise alignment

    [--ref_genome_bed filename]
       Location of the genome bed file for the reference species. Default location defined in bed_file_location variable

    [--ref_coding_exons_bed filename]
       Location of the coding exons bed file for the reference species. Default location defined in bed_file_location variable

    [--non_ref_genome_bed filename]
       Location of the genome bed file for the non-reference species. Default location defined in bed_file_location variable

    [--non_ref_coding_exons_bed filename]
       Location of the coding exons bed file for the non-reference species. Default location defined in bed_file_location variable

    [--ref_alignment_bed filename]
       Location of the alignment bed file for the reference species. Default is to create this file automatically in the current directory

    [--non_ref_alignment_bed filename]
       Location of the alignment bed file for the non-reference species. Default is to create this file automatically in the current directory

};

my $help;
my $reg_conf;
my $config_file;
my $config_url;
my $mlss_id;
my $ref_url;
my $non_ref_url;
my $compara_url;
my $compara_dba;
my $species;
my $ref_genome_bed;
my $ref_coding_exons_bed;
my $non_ref_genome_bed;
my $non_ref_coding_exons_bed;
my $ref_alignment_bed;
my $non_ref_alignment_bed;
my $non_ref_species;
my $ensembl_release;
my $download_url;

#blastz parameters corresponding to the blastz_parameters table.  
my $possible_blastz_params = {T => 1,
			      L => 1,
			      H => 1,
			      K => 1,
			      O => 1,
			      E => 1,
			      M => 1,
			      Q => 1};

#tblat parameters corresponding to the tblat_parameters table. 
my $possible_tblat_params ={minScore => 1,
			    t        => 1,
			    q        => 1,
			    mask     => 1,
			    qMask    => 1};

my $dump_features = "/nfs/users/nfs_k/kb3/src/ensembl_main/ensembl-compara/scripts/dumps/dump_features.pl";
my $bed_file_location = "/nfs/ensembl/compara/dumps/bed/";

# ok this is a hack, but I'm going to pretend I've got an object here
# by creating a blessed hash ref and passing it around like an object
# this is to avoid using global variables in functions, and to consolidate
# the globals into a nice '$self' package
my $self = bless {};

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "config_file=s" => \$config_file,
    "config_url=s" => \$config_url,
    "mlss_id=i" => \$mlss_id,
    "ref_url=s" => \$ref_url,
    "non_ref_url=s" => \$non_ref_url,
    "compara_url=s" => \$compara_url,
    "ref_species=s" => \$species,
    "ensembl_release=i" => \$ensembl_release,
    "download_url=s" => \$download_url,
    "bed_file_location=s" => \$bed_file_location,
    "ref_genome_bed=s" => \$ref_genome_bed,
    "ref_coding_exons_bed=s" => \$ref_coding_exons_bed,
    "non_ref_genome_bed=s" => \$non_ref_genome_bed,
    "non_ref_coding_exons_bed=s" => \$non_ref_coding_exons_bed,
    "ref_alignment_bed=s" => \$ref_alignment_bed,
    "non_ref_alignment_bed=s" => \$non_ref_alignment_bed,
  );

# Print Help and exit
if ($help) {
  print $usage;
  exit(0);
}

my %hive_params;
my %engine_params;
my %compara_conf;
$compara_conf{'-port'} = 3306;

#print_memory("Start");

#
#Create compara database adaptor
#
if ($compara_url =~ /^mysql/) {
    $self->compara_dba(Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url => $compara_url));
} else {
    throw "Must define compara_db or compara_url\n"
}

if (defined $mlss_id) {
    $self->mlss_id($mlss_id);
} else {
    throw "Must define method_link_species_set_id";
} 

#Find ensembl release version from compara meta container if not defined
if (defined $ensembl_release) {
    $self->ensembl_release($ensembl_release);
} else {
    my $meta_container = $self->compara_dba->get_MetaContainer;
    $self->ensembl_release($meta_container->list_value_by_key('schema_version')->[0]);
}

#Store download_url if defined
if (defined $download_url) {
    $self->download_url($download_url);
} else {
    $self->download_url("");
}

#Open connection to config database
if (defined $config_url) {
    $self->open_db_connection($config_url);
}

#Convert name from alias to production_name 
my $reg = "Bio::EnsEMBL::Registry";

if ($reg_conf) {
    $reg->load_all($reg_conf);
} else {
    $reg->load_registry_from_url($ref_url);
    if (defined $non_ref_url && ($non_ref_url ne $ref_url)) {
	$reg->load_registry_from_url($non_ref_url);
    }
}

$species = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_registry_name($species)->name;

#
#Write config parameters to config database if defined
#
my $pair_aligner_id;
if (defined $config_file) {
    $self->parse_conf($config_file);
    $pair_aligner_id = $self->write_config_params($config_url);
} else {
    #If no config file available, then fill in as much as possible
    $pair_aligner_id = $self->write_default_config_params($species);
}

#
#Calculate and store statistics
#
$self->write_pairaligner_statistics($ref_url, $non_ref_url, $compara_url, $config_url, $pair_aligner_id);

if (defined $config_url) {
    $self->close_db_connection();
}

#print_memory("End");


#
#Store configuration parameters
#
sub write_config_params {
    my ($self, $config_url) = @_;
    my $pair_aligner_id;

    #Find method_link_type
    my $method_link_species_set = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->mlss_id);
    my $method_link_type = $method_link_species_set->method_link_type;

    #Find asssembly
    #my $genome_db = $self->compara_dba->get_GenomeDBAdaptor->fetch_by_registry_name($self->species);

    my $reference_dna_collection;
    my $non_reference_dna_collection;
    #Assume only have single set of configuration parameters
    foreach my $pairAlignerConf (@{$self->{'pair_aligner_conf_list'}}) {
	my $parameters= eval($pairAlignerConf->{analysis_template}->{-parameters})->{options};

	#Deal with cases of very old configuration files where we have query_collection_name and target_collection_name
	if (!defined $pairAlignerConf->{reference_collection_name} && defined $pairAlignerConf->{target_collection_name}) {
	    $pairAlignerConf->{reference_collection_name} = $pairAlignerConf->{target_collection_name};
	}
	if (!defined $pairAlignerConf->{non_reference_collection_name} && defined $pairAlignerConf->{query_collection_name}) {
	    $pairAlignerConf->{non_reference_collection_name} = $pairAlignerConf->{query_collection_name};
	}

	#Write dna_collection
	$self->{reference_dna_collection} = $self->write_dna_collection($pairAlignerConf->{reference_collection_name});
	$self->{non_reference_dna_collection} = $self->write_dna_collection($pairAlignerConf->{non_reference_collection_name});
	
	#Add pair_aligner_config
	$pair_aligner_id = $self->write_pair_aligner_config($method_link_type, $self->{reference_dna_collection}->{dna_collection_id}, $self->{non_reference_dna_collection}->{dna_collection_id});

	#Add specific parameters
	if ($method_link_type eq "BLASTZ_NET" ||
	    $method_link_type eq "LASTZ_NET") {
	    $self->write_blastz_params($parameters, $pair_aligner_id);
	} elsif($method_link_type eq "TRANSLATED_BLAT_NET") {
	    $self->write_tblat_params($parameters, $pair_aligner_id);
	}
    }
    return($pair_aligner_id);
}

#
#Parse the configuration file (taken from loadPairAligner)
#
sub parse_conf {
    my $self = shift;
    my $conf_file = shift;
  
    if($conf_file) {
	if (-e $conf_file) {
	    #read configuration file from disk
	    my @conf_list = @{do $conf_file};
	    
	    foreach my $confPtr (@conf_list) {
		my $type = $confPtr->{TYPE};
		delete $confPtr->{TYPE};
		if($type eq 'COMPARA') {
		    %compara_conf = %{$confPtr};
		} elsif($type eq 'HIVE') {
		    %hive_params = %{$confPtr};
		} elsif($type eq 'PAIR_ALIGNER') {
		    push @{$self->{'pair_aligner_conf_list'}} , $confPtr;
		} elsif($type eq 'DNA_COLLECTION') {
		    push @{$self->{'dna_collection_conf_list'}} , $confPtr;
		} elsif($type eq 'ENGINE') {
		    %engine_params = %{$confPtr};
		}
	    }
	} else {
	    throw("$conf_file does not exist");
	}
    }
}

#
#Parse specific options
#
sub parse_params {
    my ($params) = @_;

    my $parsed_params;
    my (@results) = split " ", $params;
    
    foreach my $r (@results) {
	my ($option, $value) = split "=", $r;
	$parsed_params->{$option} = $value;
    }
    return $parsed_params;
}

#
#Store the dna_collection data in the configuration database
#
sub write_dna_collection {
    my ($self, $collection_name) = @_;

    #Don't try to store anything in the database
    return if (!defined $self->config_dbh);

    my $id;
    my $dna_collection_conf;

    my $method_link_species_set = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->mlss_id);
    my $species_set = $method_link_species_set->species_set;

    foreach my $dnaCollectionConf (@{$self->{'dna_collection_conf_list'}}) {
	next if ($dnaCollectionConf->{collection_name} ne $collection_name);

	#my ($name, $assembly) = split ":",  $dnaCollectionConf->{genome_name_assembly};
	#change name if necessary
	#if ($name =~ /\w* \w*/) {
	 #   $name = lcfirst($name);
	  #  $name =~ s/ /_/;
	#}
	my $genome_db_id = $dnaCollectionConf->{genome_db_id};

	#Check that the name exists in the species_set of the mlss
	my $found = 0;
	my $name;
	foreach my $genome_db (@$species_set) {
	    if ($genome_db->dbID == $genome_db_id) {
		$name = $genome_db->name;
		$found = 1;
	    }
	}
	if (!$found) {
	    throw("$genome_db_id is not part of method link specices set $mlss_id");
	}

	#Find common name
	my $common_name = $reg->get_adaptor($name, "core", "MetaContainer")->list_value_by_key('species.ensembl_alias_name')->[0];

	my $masking_options;
	if (defined $dnaCollectionConf->{masking_options_file}) {
	    $masking_options = $dnaCollectionConf->{masking_options_file};
	} elsif (defined $dnaCollectionConf->{masking_options}) {
	    $masking_options = $dnaCollectionConf->{masking_options};
	    if ($masking_options eq "{default_soft_masking => 1}") {
		$masking_options = "default_soft_masking";
	    }
	}
	
	#Check if already exists in database
	my $check_sql = "SELECT dna_collection_id FROM dna_collection WHERE name = ? AND chunk_size = ? AND group_set_size = ? AND overlap = ? AND masking_options = ?";
	my $check_sth = $self->config_dbh->prepare($check_sql);

	#The reference species does not have a group_set_size
	if (!defined $dnaCollectionConf->{group_set_size}) {
	    $dnaCollectionConf->{group_set_size} = 0;
	}

	$check_sth->execute($name, 
			    $dnaCollectionConf->{chunk_size},
			    $dnaCollectionConf->{group_set_size},
			    $dnaCollectionConf->{overlap},
			    $masking_options);
	$id = $check_sth->fetchrow_array();

	#If doesn't exist, then add it
	if (!defined $id) {
#	    my $sql = "INSERT IGNORE dna_collection (name, common_name, chunk_size, overlap, group_set_size, masking_options) VALUES (\"$name\", " . $dnaCollectionConf->{chunk_size} . "," . $dnaCollectionConf->{overlap} . "," . $dnaCollectionConf->{group_set_size} . ",\"" . $masking_options . "\")";
	    my $sql = "INSERT IGNORE dna_collection (name, common_name, chunk_size, overlap, group_set_size, masking_options) VALUES (?,?,?,?,?,?)";
	    #print "$sql\n";
	    my $sth = $self->config_dbh->prepare($sql);
	    $sth->execute($name, $common_name, $dnaCollectionConf->{chunk_size}, $dnaCollectionConf->{overlap}, $dnaCollectionConf->{group_set_size}, $masking_options);
	    $id = $sth->{'mysql_insertid'};
	    $sth->finish();
	}

	#Make object
	%$dna_collection_conf = (
				dna_collection_id => $id,
				name => $name,
				common_name => $common_name,
				chunk_size => $dnaCollectionConf->{chunk_size},
				group_set_size => $dnaCollectionConf->{group_set_size},
				overlap => $dnaCollectionConf->{overlap},
				masking_options => $masking_options);	
    }
    return ($dna_collection_conf);
}

#
#Write default configuaration parameters if the config parameter file is not available but still wish to add final
#statistics to the database. 
#
sub write_default_config_params {
    my ($self, $species) = @_;

    my $method_link_species_set = $self->compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->mlss_id);
    
    if (!$method_link_species_set) {
	print " ** ERROR **  Cannot find any MethodLinkSpeciesSet with this ID (" . $self->mlss_id . ")\n";
	exit(1);
    }
    my $species_set = $method_link_species_set->species_set;
    my $ref_species;
    my $non_ref_species;
    
    foreach my $genome_db (@$species_set) {
	if ($genome_db->name eq $species) {
	    $ref_species = $genome_db->name;
	} else {
	    $non_ref_species = $genome_db->name;
	}
    }
    if (!defined $species) {
	throw("Unable to find species $species in method_link_species_set_id " . $self->mlss_id);
    }
    #print "REF $ref_species $non_ref_species\n";
    #Find common name

    my $ref_common_name = $reg->get_adaptor($ref_species, "core", "MetaContainer")->list_value_by_key('species.ensembl_alias_name')->[0];
    my $non_ref_common_name = $reg->get_adaptor($non_ref_species, "core", "MetaContainer")->list_value_by_key('species.ensembl_alias_name')->[0];

    #Check if reference already present
    my $check_sql = "SELECT dna_collection_id FROM dna_collection WHERE name = ? AND chunk_size = 0 AND group_set_size = 0 AND overlap = 0";
    my $check_sth = $self->config_dbh->prepare($check_sql);
    $check_sth->execute($ref_species);
    my $reference_id = $check_sth->fetchrow_array();
    
    #Insert reference if not present
    my $sql = "INSERT IGNORE INTO dna_collection (name, common_name) VALUES (?,?)";
    my $sth = $self->config_dbh->prepare($sql);
    if (!defined $reference_id) {
	$sth->execute($ref_species, $ref_common_name);
	$reference_id = $sth->{'mysql_insertid'};
    }

    #Check if non-reference already present
    $check_sth->execute($non_ref_species);
    my $non_reference_id = $check_sth->fetchrow_array();

    #Insert non-reference if not present
    if (!defined $non_reference_id) {
	$sth->execute($non_ref_species, $non_ref_common_name);
	$non_reference_id = $sth->{'mysql_insertid'};
    }

    #Add pair-aligner values
    $sql = "INSERT INTO pair_aligner_config (method_link_species_set_id, method_link_type, ensembl_release, reference_id, non_reference_id, download_url) VALUES(?,?,?,?,?,?)";
    $sth = $self->config_dbh->prepare($sql);
    $sth->execute($self->mlss_id, 
		  $method_link_species_set->method_link_type,
		  $self->ensembl_release,
		  $reference_id,
		 $non_reference_id,
		 $self->download_url);
    $pair_aligner_id = $sth->{'mysql_insertid'};

    return ($pair_aligner_id);
}

#
#Store pair_aligner_config parameters
#
sub write_pair_aligner_config {
    my ($self, $method_link_type, $reference_id, $non_reference_id) = @_;

    #Don't try to store anything in the database
    return if (!defined $self->config_dbh);

    my $sql = "INSERT INTO pair_aligner_config (method_link_species_set_id, method_link_type, ensembl_release, reference_id, non_reference_id, download_url) VALUES (?,?,?,?,?,?)";

    my $sth = $self->config_dbh->prepare($sql);
    $sth->execute($self->mlss_id, $method_link_type, $self->ensembl_release, $reference_id, $non_reference_id, $self->download_url);
    $pair_aligner_id = $sth->{'mysql_insertid'};
    $sth->finish;
    return $pair_aligner_id;
}

#
#Store blastz specific parameters in blastz_params
#
sub write_blastz_params {
    my ($self, $parameters, $pair_aligner_id) = @_;
    my $blastz_params = parse_params($parameters);

    #Don't try to store anything in the database
    return if (!defined $self->config_dbh);

    my @key_array;
    my @value_array;
    
    my $sql = "INSERT INTO blastz_parameter (";
    push @key_array, "pair_aligner_id";
    push @value_array, $pair_aligner_id;


    foreach my $key (keys %$blastz_params) {
	if ($possible_blastz_params->{$key}) {
	    push @key_array, $key;
	    push @value_array, "\"" . $blastz_params->{$key} . "\"";
	} else {
	    push @key_array, "other";
	    push @value_array, "\"" .  $key . " " . $blastz_params->{$key} . "\"";
	}
    }
    $sql .= join ",", @key_array;
    $sql .= ") VALUES (";
    $sql .= join ",", @value_array;
    $sql .= ")";
    #print "sql $sql\n";
    my $sth = $self->config_dbh->prepare($sql);
    $sth->execute();
    my $blastz_parameter_id = $sth->{'mysql_insertid'};
    $sth->finish;

}

#
#Store tblat specific parameters in tblat_params
#
sub write_tblat_params {
    my ($self, $parameters, $pair_aligner_id) = @_;
    my $tblat_params = parse_params($parameters);

    #Don't try to store anything in the database
    return if (!defined $self->config_dbh);

    my @key_array;
    my @value_array;
    
    my $sql = "INSERT INTO tblat_parameter (";
    push @key_array, "pair_aligner_id";
    push @value_array, $pair_aligner_id;


    foreach my $key (keys %$tblat_params) {
	my $param_key = $key;
	$param_key =~ s/-//g;
	if ($possible_tblat_params->{$param_key}) {
	    push @key_array, $param_key;
	    push @value_array, "\"" .  $tblat_params->{$key} . "\"";
	} else {
	    push @key_array, "other";
	    push @value_array, "\"" .  $key . " " . $tblat_params->{$key} . "\"";
	}
    }
    $sql .= join ",", @key_array;
    $sql .= ") VALUES (";
    $sql .= join ",", @value_array;
    $sql .= ")";

    #print "sql $sql\n";
    my $sth = $self->config_dbh->prepare($sql);
    $sth->execute();
    my $tblat_parameter_id = $sth->{'mysql_insertid'};
    $sth->finish;

}

#
#Store pair-aligner statistics in pair_aligner_statistics table
#
sub write_pairaligner_statistics {
    my ($self, $url1, $url2, $compara_url, $config_url, $pair_aligner_id) = @_;
    my $verbose = 0;

    if ($compara_url =~ /^mysql/) {
	$compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url => $compara_url);
    } else {
	throw "Must define compara_db or compara_url\n"
    }

    my $method_link_species_set = $compara_dba->get_MethodLinkSpeciesSetAdaptor->fetch_by_dbID($self->mlss_id);
    
    if (!$method_link_species_set) {
	print " ** ERROR **  Cannot find any MethodLinkSpeciesSet with this ID (" . $self->mlss_id . ")\n";
	exit(1);
    }
    
    #Fetch the number of genomic_align_blocks
    my $gab_adaptor = $compara_dba->get_GenomicAlignBlockAdaptor;
    my $gabs = $gab_adaptor->fetch_all_by_MethodLinkSpeciesSet($method_link_species_set);
    my $num_blocks = @$gabs;

    print "num gabs " . @$gabs . "\n";
    
    #Find the reference and non-reference genome_db
    my $species_set = $method_link_species_set->species_set;
    my $ref_genome_db;
    my $non_ref_genome_db;
    my ($ref_url, $non_ref_url);

    #Need to find "real" reference species as defined by the configuration file, not from the command line which is there to
    #assign species to url
    foreach my $genome_db (@$species_set) {

	if (defined  $self->{reference_dna_collection}->{name} && 
	    $genome_db->name eq $self->{reference_dna_collection}->{name}) {
	    $ref_genome_db = $genome_db;
	    if ($url1 && $url2) {
		if ($genome_db->name eq $species) {
		    $ref_url = $url1;
		} else {
		    $ref_url = $url2;
		}
	    }
	} elsif (defined $self->{non_reference_dna_collection}->{name} && 
		 $genome_db->name eq $self->{non_reference_dna_collection}->{name}) {
	    $non_ref_genome_db = $genome_db;
	    if ($url1 && $url2) {
		if ($genome_db->name eq $species) {
		    $non_ref_url = $url1;
		} else {
		    $non_ref_url = $url2;
		}
	    }
	} else {
	    #If no configuration file given, use ref_species as reference
	    if ($genome_db->name eq $species) {
		$ref_genome_db = $genome_db;
		$ref_url = $url1 if ($url1);
	    } else {
		$non_ref_genome_db = $genome_db;
		$non_ref_url = $url2 if ($url2);
	    }
	}
    }

    #Calculate the statistics
    my ($ref_coverage, $ref_coding_coverage, $ref_alignment_coding) = calc_stats($reg_conf, $ref_url, $ref_genome_db, $ref_genome_bed, $ref_coding_exons_bed, $ref_alignment_bed);
    my ($non_ref_coverage, $non_ref_coding_coverage, $non_ref_alignment_coding) = calc_stats($reg_conf, $non_ref_url, $non_ref_genome_db, $non_ref_genome_bed, $non_ref_coding_exons_bed, $non_ref_alignment_bed);
    
    #Store the results in the configuration database
    if (defined $config_url) {
	write_compare_bed_output($config_url, $pair_aligner_id, $num_blocks, $ref_genome_db, $ref_coverage, $ref_coding_coverage, $ref_alignment_coding, $non_ref_genome_db, $non_ref_coverage, $non_ref_coding_coverage, $non_ref_alignment_coding);
    }
}

#
#Calculate the statistics.
#The genome_bed file if not defined, is located in the directory given by bed_file_location 
#The alignment_bed file if not defined, is automatically created in the current directory
#compare_beds.pl $genome_bed $alignment_bed --stats
#compare_beds.pl $genome_bed $coding_exons_bed --stats
#compare_beds.pl $coding_exons_bed $alignment_bed --stats
#
sub calc_stats {
    my ($reg_conf, $url, $genome_db, $genome_bed, $coding_exons_bed, $alignment_bed) = @_;
    my $species = $genome_db->name;
    my $assembly_name = $genome_db->assembly;

    #Use default location and name. The files should be named species_name.assembly.bed but species_name.bed is supported
    if (!defined $genome_bed) {

	#try with assembly first 
	$genome_bed = "$bed_file_location" . $species . "." . $assembly_name . ".genome.bed";
	#try without assembly
	unless (-e $genome_bed) {
	    $genome_bed = "$bed_file_location" . $species . ".genome.bed";
	    unless (-e $genome_bed) {
		throw("$genome_bed does not exist\n");
	    }
	}
    }

    if (!defined $coding_exons_bed) {
	#try with assembly first
	$coding_exons_bed = "$bed_file_location" . $species . "." . $assembly_name . ".coding_exons.bed";
	#try without assembly 
	unless (-e $coding_exons_bed) {
	    $coding_exons_bed = "$bed_file_location" . $species . ".coding_exons.bed";
	    unless (-e $genome_bed) {
		throw("$coding_exons_bed does not exist\n");
	    }
	}
    }

    #dump alignment_bed if not defined
    if (!defined $alignment_bed) {
	my $feature = "mlss_" . $self->mlss_id;
	$alignment_bed = $feature . "." . $species . ".bed";
	if ($reg_conf) {
	    unless (system("$dump_features --reg_conf $reg_conf --compara_url $compara_url --species $species --feature $feature > $alignment_bed") == 0) {
		throw("$dump_features --reg_conf $reg_conf --compara_url $compara_url --species $species --feature $feature execution failed\n");
	    }
	} else {
	    unless (system("$dump_features --url $url --compara_url $compara_url --species $species --feature $feature > $alignment_bed") == 0) {
		throw("$dump_features --url $url --compara_url $compara_url --species $species --feature $feature execution failed\n");
	    }
	}
    }
    my $coverage_data = `/software/ensembl/compara/bin/compare_beds.pl $genome_bed $alignment_bed --stats`;
    
    my $coding_coverage_data = `/software/ensembl/compara/bin/compare_beds.pl $genome_bed $coding_exons_bed --stats`;
    
    my $alignment_coding_data = `/software/ensembl/compara/bin/compare_beds.pl $coding_exons_bed $alignment_bed --stats`;

    print "*** $species ***\n";
    #print "coverage\n$coverage_data\n";
    #print "coding_coverage\n$coding_coverage_data\n";
    #print "alignment_coverage\n$alignment_coding_data\n";
    
    my $coverage = parse_compare_bed_output($coverage_data);
    my $coding_coverage = parse_compare_bed_output($coding_coverage_data);
    my $alignment_coding = parse_compare_bed_output($alignment_coding_data);
    
    printf "Align Coverage: %.2f%% (%d bp out of %d)\n", ($coverage->{both} / $coverage->{total} * 100), $coverage->{both}, $coverage->{total};
    
    printf "CodExon Coverage: %.2f%% (%d bp out of %d)\n", ($coding_coverage->{both} / $coverage->{total}* 100), $coding_coverage->{both}, $coverage->{total};
    
    printf "Align Overlap: %.2f%% of aligned bp correspond to coding exons (%d bp out of %d)\n", ($alignment_coding->{both} / $coverage->{both} * 100), $alignment_coding->{both}, $coverage->{both};
    
    printf "CodExon Overlap: %.2f%% of coding bp are covered by alignments (%d bp out of %d)\n", ($alignment_coding->{both} / $coding_coverage->{both} * 100), $alignment_coding->{both}, $coding_coverage->{both};
    print "\n";

    return ($coverage, $coding_coverage, $alignment_coding);
}

#
#Parse output of compare_beds
#
sub parse_compare_bed_output {
    my ($output) = @_;
    
    my ($first_bp, $both_bp, $second_bp) = $output =~ /# FIRST: (\d*.) ; BOTH: (\d*.) ; SECOND: (\d*.)/;
    my ($first_perc, $both_perc, $second_perc) = $output =~ /# FIRST: (\d*.\d*)%; BOTH: (\d*.\d*)%; SECOND: (\d*.\d*)%/;
    my ($first_overlap, $second_overlap) = $output =~ /# FIRST OVERLAP: (\d*.\d*)%; SECOND OVERLAP: (\d*.\d*)%/;
    my $ref_total_bp = ($first_bp + $both_bp);

    my $results;
    $results->{first} = $first_bp;
    $results->{both} = $both_bp;
    $results->{second} = $second_bp;
    $results->{total} = ($first_bp+$both_bp);

    return $results;
}

#
#Store compare_bed output in configuration database
#
sub write_compare_bed_output {
    my ($config_url, $pair_aligner_id, $num_blocks, $ref_genome_db, $ref_coverage, $ref_coding_coverage, $ref_alignment_coding, $non_ref_genome_db, $non_ref_coverage, $non_ref_coding_coverage, $non_ref_alignment_coding) = @_;
    unless (defined $pair_aligner_id) {
	throw("Unable to add statistics to database without corresponding pair_aligner_id\n");
    }

    my $sql_genome = "INSERT IGNORE INTO genome_statistics (genome_db_id, name, assembly, length, coding_exon_length) VALUES (?,?,?,?,?)";
    my $sth = $self->config_dbh->prepare($sql_genome);
    $sth->execute($ref_genome_db->dbID, $ref_genome_db->name, $ref_genome_db->assembly, $ref_coverage->{total}, $ref_coding_coverage->{both});
    $sth->execute($non_ref_genome_db->dbID, $non_ref_genome_db->name, $non_ref_genome_db->assembly, $non_ref_coverage->{total}, $non_ref_coding_coverage->{both});
    
    my $sql = "INSERT IGNORE INTO pair_aligner_statistics (pair_aligner_id, method_link_species_set_id, num_blocks, ref_genome_db_id, non_ref_genome_db_id, ref_alignment_coverage, ref_alignment_exon_coverage, non_ref_alignment_coverage, non_ref_alignment_exon_coverage) VALUES (?,?,?,?,?,?,?,?,?)";
    $sth = $self->config_dbh->prepare($sql);
    $sth->execute($pair_aligner_id, 
		  $self->mlss_id, 
		  $num_blocks, 
		  $ref_genome_db->dbID, 
		  $non_ref_genome_db->dbID, 
		  $ref_coverage->{both},
		  $ref_alignment_coding->{both},
		  $non_ref_coverage->{both},
		  $non_ref_alignment_coding->{both});
    $sth->finish;
}

#
#Create database handle from a valid url
#
sub open_db_connection {
    my ($self, $url) = @_;

    my $dbh;
    if ($url =~ /mysql\:\/\/([^\@]+\@)?([^\:\/]+)(\:\d+)?(\/.+)?/ ) {
	my $user_pass = $1;
	my $host      = $2;
	my $port      = $3;
	my $dbname    = $4;
	
	$user_pass =~ s/\@$//;
	my ( $user, $pass ) = $user_pass =~ m/([^\:]+)(\:.+)?/;
	    $pass    =~ s/^\:// if ($pass);
	$port    =~ s/^\:// if ($port);
	$dbname  =~ s/^\/// if ($dbname);
	
	$dbh = DBI->connect("DBI:mysql:$dbname;host=$host;port=$port", $user, $pass, { RaiseError => 1 });
    } else {
	throw("Invalid url $url\n");
    }
    $self->config_dbh($dbh);
}

#
#Close database connection
#
sub close_db_connection {
    my ($self) = @_;

    $self->config_dbh->disconnect;
}
   
##########################################
#
# getter/setter methods
# 
##########################################

sub compara_dba {
  my $self = shift;
  $self->{'_compara_dba'} = shift if(@_);
  return $self->{'_compara_dba'};
}

sub mlss_id {
  my $self = shift;
  $self->{'_mlss_id'} = shift if(@_);
  return $self->{'_mlss_id'};
}

sub ensembl_release {
  my $self = shift;
  $self->{'_ensembl_release'} = shift if(@_);
  return $self->{'_ensembl_release'};
}

sub download_url {
  my $self = shift;
  $self->{'_download_url'} = shift if(@_);
  return $self->{'_download_url'};
}

sub method_link_type {
  my $self = shift;
  $self->{'_method_link_type'} = shift if(@_);
  return $self->{'_method_link_type'};
}
sub config_dbh {
  my $self = shift;
  $self->{'_config_dbh'} = shift if(@_);
  return $self->{'_config_dbh'};
}

sub print_memory {
    my ($text) = @_;

    print "$text\t";

    my @lines = split("\n", qx"ps -efl | grep update_config_database");
    #print join("\n", grep {/perl/} @lines), "\n";
    my $line = join("\n", grep {/perl/} @lines);
    my @fields = split ' ', $line;

    print "SZ $fields[9] \n";
}

