#!/usr/bin/env perl
# Copyright [1999-2016] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
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


use warnings;
use strict;

=head1 NAME

create_mlss.pl

=head1 AUTHORS

 Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script creates a new MethodLinkSpeciesSet based on the
information provided through the command line and tries to store
it in the database 

=head1 SYNOPSIS

perl create_mlss.pl --help

perl create_mlss.pl
    [--method_link_type method_link_type]
    [--genome_db_id genome_db_id_1,genome_db_id_2... [--genome_db_id genome_db_id_X]]
    [--name name]
    [--source source]
    [--url url]
    [--compara name]
    [--reg_conf file]
    [--f] force
    [--pw] pairwise
    [--sg] singleton
    [--use_genomedb_ids] use GenomeDB IDs in MLSS name than truncated GenomeDB names
    [--species_set_name species_set_name] 

=head1 OPTIONS

=head2 GETTING HELP

=over

=item B<[--help]>

  Prints help message and exits.

=back

=head2 GENERAL CONFIGURATION

=over

=item B<[--reg_conf registry_configuration_file]>

The Bio::EnsEMBL::Registry configuration file. If none given,
the one set in ENSEMBL_REGISTRY will be used if defined, if not
~/.ensembl_init will be used.

=item B<--compara compara_db_name_or_alias>

The compara database to update. You can use either the original name or any of the
aliases given in the registry_configuration_file. DEFAULT VALUE: compara_master

=item B<--method_link_type method_link_type>

It should be an existing method_link_type. E.g. TRANSLATED_BLAT, BLASTZ_NET, MLAGAN...

=item B<--genome_db_id>

This should be a list of genome_db_ids. You can separate them by commas or specify them in
as many --genome_db_id options as you want

=item B<--name>

The name for this MethodLinkSpeciesSet

=item B<--source>

The source for this MethodLinkSpeciesSet

=item B<--url>

The url for this MethodLinkSpeciesSet

=item B<--pw>

From a list of genome_db_id 1,2,3,4, it will create all possible pairwise combinaison 
i.e. [1,2] [1,3] [1,4] [2,3] [2,4] [3,4] for a given  method link.

=item B<--sg>

From a list of genome_db_id 1,2,3,4, it will create a mlss for each single genome_db_id 
in the list i.e. [1] [2] [3] [4] for a given  method link.

=item B<--use_genomedb_ids>

Force the names of the create MLSS to use the Genome DB ID rather than the truncated form
of its name (which is normally of the form H.sap).

=item B<--species_set_name>

Set the name for this species_set.

=item B<--collection>

Use all the species in that collection (more practical than giving a long list of genome_db_ids

=item B<Examples>

perl create_mlss.pl

perl create_mlss.pl --method_link_type BLASTZ_NET --genome_db_id 1,2

perl create_mlss.pl --method_link_type PECAN --genome_db_id 1,2,3,4 --name "4 species PECAN" --source "ensembl" --url "" --species_set_name "mammals"

=item B<[--release]>

Mark all the objects that are created / used (GenomeDB, SpeciesSet, MethodLinkSpeciesSet)
as "current", i.e. with a first_release and an undefined last_release

=back

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Compara::DBSQL::DBAdaptor;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::SqlHelper;
use Getopt::Long;

my $help;

my $reg_conf;
my $compara = "compara_master";
my $yes = 0;
my $method_link_type;
my @input_genome_db_ids;
my @genome_db_ids;
my $name;
my $source;
my $url;
my $force = 0;
my $pairwise = 0;
my $singleton = 0;
my $use_genomedb_ids = 0;
my $species_set_name;
my $collection;
my $method_link_class;
my $release;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "method_link_type=s" => \$method_link_type,
    "method_link_class=s" => \$method_link_class,
    "genome_db_id=s@" => \@input_genome_db_ids,
    "name=s" => \$name,
    "source=s" => \$source,
    "url=s" => \$url,
    "force|f" => \$force,
    "pw" => \$pairwise,
    "sg" => \$singleton,
    "use_genomedb_ids" => \$use_genomedb_ids,
    "species_set_name|species_set_tag=s" => \$species_set_name,
    "collection=s" => \$collection,
    'release' => \$release,
  );

if ($pairwise && $singleton) {
  warn("You cannot store pairwise way and singleton way at the same time. Please choose one.\n");
  exit 1;
}

if (scalar(@input_genome_db_ids) && $collection) {
  warn("You cannot define the species set with both genome_db_id collection. Please choose one.\n");
  exit 1;
}

@input_genome_db_ids = split(/,/,join(',',@input_genome_db_ids));

# Print Help and exit if help is requested
if ($help) {
    use Pod::Usage;
    pod2usage({-exitvalue => 0, -verbose => 2});
}

#################################################
## Get the adaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf, 0, 0, 0, "throw_if_missing");

my $compara_dba;
if ($compara =~ /mysql:\/\//) {
    $compara_dba = Bio::EnsEMBL::Compara::DBSQL::DBAdaptor->new(-url=>$compara);
} else {
    $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
}

if (!$compara_dba) {
  die "Cannot connect to compara database <$compara>.";
}
my $helper = Bio::EnsEMBL::Utils::SqlHelper->new(-DB_CONNECTION => $compara_dba->dbc);
my $gdba = $compara_dba->get_GenomeDBAdaptor();
my $ma = $compara_dba->get_MethodAdaptor();
my $ssa = $compara_dba->get_SpeciesSetAdaptor();
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
##
#################################################

#################################################
## Set values interactively if needed
if (!$method_link_type) {
  $method_link_type = ask_for_method_link_type($compara_dba);
  print "METHOD_LINK_TYPE = $method_link_type\n";
}
my $method = $ma->fetch_by_type($method_link_type);
if (not $method) {
    if (not $method_link_class) {
        die "The method '$method_link_type' could not be found in the database, and --class was ommitted. I don't know how to create the new method !\n";
    }
    $method = Bio::EnsEMBL::Compara::Method->new( -TYPE => $method_link_type, -CLASS => $method_link_class );
}
my $ml_type = lc($method_link_type);
$ml_type =~ s/ensembl_//;
$ml_type =~ s/_/\-/g;
$ml_type = 'families' if $ml_type eq 'family';

if ($collection) {
  my $ss = $ssa->fetch_collection_by_name($collection);
  if (not $ss) {
      die "The collection '$collection' could not be found in the database.\n";
  }
  # For ENSEMBL_ORTHOLOGUES or ENSEMBL_PARALOGUES we need to exclude the
  # component genome_dbs because they are only temporary for production
  my $gdbs = ($pairwise or $singleton) ? [grep {not $_->genome_component}  @{$ss->genome_dbs}] : $ss->genome_dbs;
  @input_genome_db_ids = map {$_->dbID} @$gdbs;
}

# All the pairwise / singleton will share the same URL. Set it once here
if (!defined $url) {
  if ($force) {
    $url = "";
  } else {
    $url = prompt("Set the url for this MethodLinkSpeciesSet", "");
  }
}

# All the pairwise / singleton will share the same source. Set it once here
if (!$source) {
  if ($force) {
    $source = "ensembl";
  } else {
    $source = prompt("Set the source for this MethodLinkSpeciesSet", "ensembl");
  }
}

if ($pairwise) {

  # Only makes sense for GenomicAlignBlock.pairwise_alignment,
  # SyntenyRegion.synteny and Homology.homology
  my $this_class = $method->class;
  my %valid_classes = map {$_ => 1} qw(GenomicAlignBlock.pairwise_alignment SyntenyRegion.synteny Homology.homology);
  die "The --pw option only makes sense for these method_link_classes, not for $this_class.\n" unless $valid_classes{$this_class};

  while (my $gdb_id1 = shift @input_genome_db_ids) {
    foreach my $gdb_id2 (@input_genome_db_ids) {
      create_mlss( [$gdb_id1, $gdb_id2] );
    }
  }

} elsif ($singleton) {

  # Only makes sense for GenomicAlignBlock.pairwise_alignment,
  # SyntenyRegion.synteny and Homology.homology
  my $this_class = $method->class;
  my %valid_classes = map {$_ => 1} qw(GenomicAlignBlock.pairwise_alignment SyntenyRegion.synteny Homology.homology);
  die "The --sg option only makes sense for these method_link_classes, not for $this_class.\n" unless $valid_classes{$this_class};

  foreach my $gdb_id (@input_genome_db_ids) {
    create_mlss( [$gdb_id] );
  }

} else {

  if (!@input_genome_db_ids) {
    my @genome_dbs = ask_for_genome_dbs($compara_dba);
    @input_genome_db_ids = map {$_->dbID} @genome_dbs;
  }

  create_mlss( \@input_genome_db_ids, $name, $species_set_name || $collection );
}


sub create_mlss {
  my ($genome_db_ids, $desired_mlss_name, $desired_ss_name) = @_;

  ## Get the Bio::EnsEMBL::Compara::GenomeDB
  my $all_genome_dbs;
  foreach my $this_genome_db_id (@{$genome_db_ids}) {
    my $this_genome_db = $gdba->fetch_by_dbID($this_genome_db_id);
    if (!UNIVERSAL::isa($this_genome_db, "Bio::EnsEMBL::Compara::GenomeDB")) {
      throw("Cannot get any Bio::EnsEMBL::Compara::GenomeDB using dbID #$this_genome_db_id");
    }
    push(@$all_genome_dbs, $this_genome_db);
  }

  # Simple check to allow running create_mlss for homoeologues on the whole
  # collection
  if (($method_link_type eq 'ENSEMBL_HOMOEOLOGUES') and (grep {not $_->is_polyploid} @$all_genome_dbs)) {
    print "Skipping this MLSS because ENSEMBL_HOMOEOLOGUES only applies to polyploid species\n";
    return;
  }

  ## Check if the MethodLinkSpeciesSet already exists
  my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($method_link_type, $genome_db_ids, 1);
  if ($mlss) {
    print "This MethodLinkSpeciesSet already exists in the database!\n  $method_link_type: ",
        join(" - ", map {$_->name."(".$_->assembly.")"} @{$mlss->species_set_obj->genome_dbs}), "\n";
    print "  Name: ", $mlss->name, "\n";
    print "  Source: ", $mlss->source, "\n";
    print "  URL: ", $mlss->url, "\n";
    print "  SpeciesSet name: ".($mlss->species_set_obj->name)."\n";
    print "  MethodLinkSpeciesSet has dbID: ", $mlss->dbID, "\n";
    if ($release and !$mlss->is_current) {
      $helper->transaction( -CALLBACK => sub { $mlssa->make_object_current($mlss) } );
    }
    return;
  }

  ## Check if the SpeciesSet already exists
  my $species_set = $ssa->fetch_by_GenomeDBs($all_genome_dbs);
  if (!$species_set) {
    my $ss_name = $desired_ss_name;
    if (!$ss_name) {
      my @individual_names;
      if ($use_genomedb_ids) {
        @individual_names = @{$genome_db_ids};
      } else {
        foreach my $this_genome_db_id (@{$genome_db_ids}) {
          my $gdb = $gdba->fetch_by_dbID($this_genome_db_id) || die( "Cannot fetch_by_dbID genome_db $this_genome_db_id" );
          my $species_name = $gdb->name;
          $species_name =~ s/\b(\w)/\U$1/g;
          $species_name =~ s/(\S)\S+\_/$1\./;
          $species_name = substr($species_name, 0, 5);
          push @individual_names, $species_name;
        }
      }
      $ss_name = join('-', @individual_names);
    }
    unless ($force) {
      $ss_name = prompt("Set the value for this species_set name []", $ss_name);
      die "Species-sets must have a name.\n" unless $ss_name;
    }
    $species_set = Bio::EnsEMBL::Compara::SpeciesSet->new(
        -GENOME_DBS => $all_genome_dbs,
        -NAME => $ss_name,
    );
  }

  ## Name the new MLSS
  my $mlss_name = $desired_mlss_name;
  if (!$mlss_name) {
      $mlss_name = $species_set->name." $ml_type";
      if ($method_link_type eq "BLASTZ_NET" || $method_link_type eq "LASTZ_NET") {
        if ($mlss_name =~ /H\.sap/) {
          $mlss_name .= " (on H.sap)";
        } elsif ($mlss_name =~ /M\.mus/) {
          $mlss_name .= " (on M.mus)";
        } elsif ($mlss_name =~ /G\.gal/) {
          $mlss_name .= " (on G.gal)";
        } elsif ($mlss_name =~ /D\.rer/) {
          $mlss_name .= " (on D.rer)";
        }
      }
      unless ($force) {
        $mlss_name = prompt("Set the name for this MethodLinkSpeciesSet", $mlss_name);
      }
  }

  print "You are about to store the following MethodLinkSpeciesSet\n  $method_link_type: ",
    join(" - ", map {$_->name."(".$_->assembly.")"} @$all_genome_dbs), "\n";
  print "  Name: $mlss_name\n";
  print "  Source: $source\n";
  print "  URL: $url\n";
  print "  SpeciesSet name: ".($species_set->name)."\n";
  unless ($force) {
    print "\nDo you want to continue? [y/N]? ";
    
    my $resp = <STDIN>;
    if ($resp !~ /^y$/i and $resp !~ /^yes$/i) {
      print "Cancelled.\n";
      next;
    }
  }
  
  my $new_mlss = Bio::EnsEMBL::Compara::MethodLinkSpeciesSet->new(
                                                                 -method => $method,
                                                                 -species_set_obj => $species_set,
                                                                 -name => $mlss_name,
                                                                 -source => $source,
                                                                 -url => $url);

  $helper->transaction( -CALLBACK => sub {
    $mlssa->store($new_mlss);
    $mlssa->make_object_current($new_mlss) if $release;
  } );

  print "  MethodLinkSpeciesSet has dbID: ", $new_mlss->dbID, "\n";
}



exit(0);
  

###############################################################################
## SUBROUTINES
###############################################################################

sub prompt {
    my $message = shift;
    my $default = shift;
    my $answer;

    print $message;
    print ' (default is ', $default, ')' if $default;
    print '   ';
    chomp ($answer = <>);
    return $answer if $answer;
    return $default;
}

sub ask_for_method_link_type {
  my ($compara_dba) = @_;
  my $method_link_type = undef;

  return undef if (!$compara_dba);

  my $method_link_types = { map { ($_->dbID => $_->type) } @{$compara_dba->get_MethodAdaptor()->fetch_all()} };
  my $answer;

  do {
    print "\n";
    foreach my $this_method_link_id (sort {$a <=> $b} keys %$method_link_types) {
      my $type = $method_link_types->{$this_method_link_id};
      printf " %3d. $type\n", $this_method_link_id;
    }
    $answer = prompt("Select the method link type");
    if ($answer =~ /^\d+$/ and defined($method_link_types->{$answer})) {
      $method_link_type = $method_link_types->{$answer};
      return $method_link_type;
    } else {
      print "\nERROR selecting method_link type, try again\n";
    }
  } while (1);
}

sub ask_for_genome_dbs {
  my ($compara_dba) = @_;
  my @genome_dbs = ();

  return undef if (!$compara_dba);

  my $all_genome_dbs = $compara_dba->get_GenomeDBAdaptor->fetch_all();
  my $answer;
  my $genome_dbs_in = {};
  my $genome_dbs_out = {map {$_->dbID, $_} @{$all_genome_dbs}};
  do {
    print "\n";
    foreach my $this_genome_db (sort {
        ($a->is_current <=> $b->is_current)
          or
        ($a->name cmp $b->name)} values %$genome_dbs_out) {
      my $dbID = $this_genome_db->dbID;
      my $name = $this_genome_db->name;
      my $assembly = $this_genome_db->assembly;
      if ($this_genome_db->is_current) {
        printf " %3d. $name $assembly\n", $dbID;
      } else {
        printf " %3d. ($name $assembly)\n", $dbID;
      }
    }
    print "Current species = ",
        join(" - ", map {$_->dbID.". ".$_->name." (".$_->assembly.")"} values %$genome_dbs_in),
        "\n";
    $answer = prompt("Add/Remove a GenomeDB", "Press enter to finish");
    if ($answer =~ /^\d+$/ and defined($genome_dbs_in->{$answer})) {
      delete($genome_dbs_in->{$answer});
    } elsif ($answer =~ /^\d+$/ and defined($genome_dbs_out->{$answer})) {
      $genome_dbs_in->{$answer} = $genome_dbs_out->{$answer};
    } elsif ($answer eq "Press enter to finish" and keys %$genome_dbs_in) {
      @genome_dbs = values %$genome_dbs_in;
      return @genome_dbs;
    } else {
      print "\nERROR selecting genome_dbs, try again\n";
    }
  } while (1);
}


