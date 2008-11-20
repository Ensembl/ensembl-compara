#!/usr/bin/env perl

use warnings;
use strict;

my $description = q{
###########################################################################
##
## PROGRAM create_mlss.pl
##
## AUTHORS
##    Javier Herrero (jherrero@ebi.ac.uk)
##
## COPYRIGHT
##    This script is part of the Ensembl project http://www.ensembl.org
##
## DESCRIPTION
##    This script creates a new MethodLinkSpeciesSet based on the
##    information provided through the command line and tries to store
##    it in the database 
##
###########################################################################

};

=head1 NAME

create_mlss.pl

=head1 AUTHORS

 Javier Herrero (jherrero@ebi.ac.uk)

=head1 COPYRIGHT

This script is part of the Ensembl project http://www.ensembl.org

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
aliases given in the registry_configuration_file. DEFAULT VALUE: compara-master

=back

=head2 --method_link_type method_link_type

It should be an existing method_link_type. E.g. TRANSLATED_BLAT, BLASTZ_NET, MLAGAN...

=head2 --genome_db_id

This should be a list of genome_db_ids. You can separate them by commas or specify them in
as many --genome_db_id options as you want

=head2 --name

The name for this MethodLinkSpeciesSet

=head2 --source

The source for this MethodLinkSpeciesSet

=head2 --url

The url for this MethodLinkSpeciesSet

=head2 --pw

From a list of genome_db_id 1,2,3,4, it will create all possible pairwise combinaison 
i.e. [1,2] [1,3] [1,4] [2,3] [2,4] [3,4] for a given  method link.

=head2 --sg

From a list of genome_db_id 1,2,3,4, it will create a mlss for each single genome_db_id 
in the list i.e. [1] [2] [3] [4] for a given  method link.

=head2 --use_genomedb_ids

Force the names of the create MLSS to use the Genome DB ID rather than the truncated form
of its name (which is normally of the form H.sap).

=head2 Examples

perl create_mlss.pl

perl create_mlss.pl --method_link_type BLASTZ_NET --genome_db_id 1,2

perl create_mlss.pl --method_link_type MLAGAN --genome_db_id 1,2,3,4 --name "4 species MLAGAN" --source "ensembl" --url ""



=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Getopt::Long;
use ExtUtils::MakeMaker qw(prompt);

my $help;

my $reg_conf;
my $compara = "compara-master";
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

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "method_link_type=s" => \$method_link_type,
    "genome_db_id=s@" => \@input_genome_db_ids,
    "name=s" => \$name,
    "source=s" => \$source,
    "url=s" => \$url,
    "f" => \$force,
    "pw" => \$pairwise,
    "sg" => \$singleton,
    "use_genomedb_ids" => \$use_genomedb_ids
  );

if ($pairwise && $singleton) {
  warn("You can store pairwise way and singleton way at the same time. Please choose one.\n");
  exit 1;
}

@input_genome_db_ids = split(/,/,join(',',@input_genome_db_ids));


# Print Help and exit if help is requested
if ($help) {
  exec("/usr/bin/env perldoc $0");
}

#################################################
## Get the adaptors from the Registry
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $compara_dba = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");
if (!$compara_dba) {
  die "Cannot connect to compara database <$compara>.";
}
my $gdba = $compara_dba->get_GenomeDBAdaptor();
my $mlssa = $compara_dba->get_MethodLinkSpeciesSetAdaptor();
##
#################################################

#################################################
## Set values interactively if needed
if (!$method_link_type) {
  $method_link_type = ask_for_method_link_type($compara_dba);
  print "METHOD_LINK_TYPE = $method_link_type\n";
}

my @new_input_genome_db_ids;
if ($pairwise) {
  while (my $gdb_id1 = shift @input_genome_db_ids) {
    foreach my $gdb_id2 (@input_genome_db_ids) {
      push @new_input_genome_db_ids, [$gdb_id1, $gdb_id2]
    }
  }
} elsif ($singleton) {
  foreach my $gdb_id (@input_genome_db_ids) {
    push @new_input_genome_db_ids, [$gdb_id]
  }
} else {
  push @new_input_genome_db_ids, \@input_genome_db_ids;
}

foreach my $genome_db_ids (@new_input_genome_db_ids) {

  if (!@$genome_db_ids) {
    my @genome_dbs = ask_for_genome_dbs($compara_dba);
    $genome_db_ids = [ map {$_->dbID} @genome_dbs ];
  }
  
  if (!$name) {
    if ($method_link_type eq "FAMILY") {
      $name = "families";
    } elsif ($method_link_type eq "MLAGAN") {
      $name = scalar(@{$genome_db_ids})." species MLAGAN";
    } else {
      if($use_genomedb_ids) {
        $name = join('-',@{$genome_db_ids});
      }
      else {
        foreach my $this_genome_db_id (@{$genome_db_ids}) {
          my $gdb = $gdba->fetch_by_dbID($this_genome_db_id)
            || die( "Cannot fetch_by_dbID genome_db $this_genome_db_id" );
          my $species_name = $gdba->fetch_by_dbID($this_genome_db_id)->name;
          $species_name =~ s/(\S)\S+ /$1\./;
          $species_name = substr($species_name, 0, 5);
          $name .= $species_name."-";
        }
      }
      $name =~ s/\-$//;
      my $type = lc($method_link_type);
      $type =~ s/ensembl_//;
      $type =~ s/_/\-/g;
      $name .= " $type";
      if ($method_link_type eq "BLASTZ_NET") {
        if ($name =~ /H\.sap/) {
          $name .= " (on H.sap)";
        } elsif ($name =~ /M\.mus/) {
          $name .= " (on M.mus)";
        }
      }
    }
    unless ($force) {
      $name = prompt("Set the name for this MethodLinkSpeciesSet", $name);
    }
  }
  
  if (!$source) {
    if ($force) {
      $source = "ensembl";
    } else {
      $source = prompt("Set the source for this MethodLinkSpeciesSet", "ensembl");
    }
  }
  
  if (!defined $url) {
    if ($force) {
      $url = "";
    } else {
      $url = prompt("Set the url for this MethodLinkSpeciesSet", "");
    }
  }
  ##
  #################################################
  
  #################################################
  ## Check if the MethodLinkSpeciesSet already exits
  my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($method_link_type, $genome_db_ids);
  if ($mlss) {
    print "This MethodLinkSpeciesSet already exists in the database!\n  $method_link_type: ",
      join(" - ", map {$_->name."(".$_->assembly.")"} @{$mlss->species_set}), "\n",
        "  Name: ", $mlss->name, "\n",
          "  Source: ", $mlss->source, "\n",
            "  URL: $url\n";
    print "  MethodLinkSpeciesSet has dbID: ", $mlss->dbID, "\n";
    $name = undef if ($pairwise || $singleton);
    next;
#    exit(0);
  }
  ##
  #################################################
  
  #################################################
  ## Get the Bio::EnsEMBL::Compara::GenomeDB
  my $all_genome_dbs;
  foreach my $this_genome_db_id (@{$genome_db_ids}) {
    my $this_genome_db = $gdba->fetch_by_dbID($this_genome_db_id);
    if (!UNIVERSAL::isa($this_genome_db, "Bio::EnsEMBL::Compara::GenomeDB")) {
      throw("Cannot get any Bio::EnsEMBL::Compara::GenomeDB using dbID #$this_genome_db_id");
    }
    push(@$all_genome_dbs, $this_genome_db);
  }
  ##
  #################################################
  print "You are about to store the following MethodLinkSpeciesSet\n  $method_link_type: ",
    join(" - ", map {$_->name."(".$_->assembly.")"} @$all_genome_dbs), "\n",
      "  Name: $name\n",
        "  Source: $source\n",
          "  URL: $url\n";
  unless ($force) {
    print "\nDo you want to continue? [y/N]? ";
    
    my $resp = <STDIN>;
    if ($resp !~ /^y$/i and $resp !~ /^yes$/i) {
      print "Cancelled.\n";
      $name = undef if ($pairwise || $singleton);
      next;
#      exit(0);
    }
  }
  
  my $new_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
                                                                 -method_link_type => $method_link_type,
                                                                 -species_set => $all_genome_dbs,
                                                                 -name => $name,
                                                                 -source => $source,
                                                                 -url => $url);
  
  $mlssa->store($new_mlss);
  print "  MethodLinkSpeciesSet has dbID: ", $new_mlss->dbID, "\n";
  $name = undef if ($pairwise || $singleton);
}

exit(0);
  

###############################################################################
## SUBROUTINES
###############################################################################

sub ask_for_method_link_type {
  my ($compara_dba) = @_;
  my $method_link_type = undef;

  return undef if (!$compara_dba);

  my $sth = $compara_dba->dbc->prepare("SELECT method_link_id, type FROM method_link");
  $sth->execute();
  my $all_rows = $sth->fetchall_arrayref;
  my $answer;
  my $method_link_types = {map {$_->[0], $_->[1]} @{$all_rows}};
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
      print "\nERROR, try again\n";
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
        ($a->assembly_default <=> $b->assembly_default)
          or
        ($a->name cmp $b->name)} values %$genome_dbs_out) {
      my $dbID = $this_genome_db->dbID;
      my $name = $this_genome_db->name;
      my $assembly = $this_genome_db->assembly;
      if ($this_genome_db->assembly_default) {
        printf " %3d. $name $assembly\n", $dbID;
      } else {
        printf " %3d. ($name $assembly)\n", $dbID;
      }
    }
    print "Current species = ",
        join(" - ", map {$_->dbID.". ".$_->name." (".$_->assembly.")"} values %$genome_dbs_in),
        "\n";
    $answer = prompt("Add a GenomeDB", "Pres enter to finish");
    if ($answer =~ /^\d+$/ and defined($genome_dbs_in->{$answer})) {
      delete($genome_dbs_in->{$answer});
    } elsif ($answer =~ /^\d+$/ and defined($genome_dbs_out->{$answer})) {
      $genome_dbs_in->{$answer} = $genome_dbs_out->{$answer};
    } elsif ($answer eq "Pres enter to finish" and keys %$genome_dbs_in) {
      @genome_dbs = values %$genome_dbs_in;
      return @genome_dbs;
    } else {
      print "\nERROR, try again\n";
    }
  } while (1);}


