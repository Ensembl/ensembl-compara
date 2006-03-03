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

perl create_mlss.pl [options] method_link_type genome_dbs...

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

=item B<--yes>

Do not ask. Assume yes

=back

=head2 method_link_type

It should be an existing method_link_type. E.g. TRANSLATED_BLAT, BLASTZ_NET, MLAGAN...

=head2 genome_dbs

This should a list of genome_db_ids.

=head2 Examples

perl create_mlss.pl BLASTZ_NET 1 2

perl create_mlss.pl MLAGAN 1 2 3 4

perl create_mlss.pl TRANSLATED_BLAT 10 45


=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Getopt::Long;

my $help;

my $reg_conf;
my $compara = "compara-master";
my $yes = 0;
my $method_link_type;
my @genome_db_ids;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "yes" => \$yes,
  );
$method_link_type = shift @ARGV;
@genome_db_ids = @ARGV;

# Print Help and exit if help is requested
if ($help or !$method_link_type or !@genome_db_ids) {
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
## Check if the MethodLinkSpeciesSet already exits
my $mlss = $mlssa->fetch_by_method_link_type_genome_db_ids($method_link_type, \@genome_db_ids);
if ($mlss) {
  print "This MethodLinkSpeciesSet already exists in the database!\n  $method_link_type: ",
    join(" - ", map {$_->name."(".$_->assembly.")"} @{$mlss->species_set}), "\n";
  print "  MethodLinkSpeciesSet has dbID: ", $mlss->dbID, "\n";
  exit(0);
}
##
#################################################

#################################################
## Get the Bio::EnsEMBL::Compara::GenomeDB
my $all_genome_dbs;
foreach my $this_genome_db_id (@genome_db_ids) {
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
    "\nDo you want to continue? [y/N]? ";

my $resp = <STDIN>;
if ($resp !~ /^y$/i and $resp !~ /^yes$/i) {
  print "Cancelled.\n";
  exit(0);
}
my $new_mlss = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
    -method_link_type => $method_link_type,
    -species_set => $all_genome_dbs);

$mlssa->store($new_mlss);
print "  MethodLinkSpeciesSet has dbID: ", $new_mlss->dbID, "\n";
