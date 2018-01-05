#!/usr/bin/env perl
# Copyright [1999-2015] Wellcome Trust Sanger Institute and the EMBL-European Bioinformatics Institute
# Copyright [2016-2018] EMBL-European Bioinformatics Institute
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


use strict;
use warnings;

my $description = q{
###########################################################################
##
## PROGRAM get_stats.pl
##
## AUTHORS
##    Javier Herrero
##
## DESCRIPTION
##    This script calculates some stats from a compara DB
##
###########################################################################

};

=head1 NAME

get_stats.pl

=head1 AUTHORS

 Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

=head1 DESCRIPTION

This script calculates some stats from a compara DB

=head1 SYNOPSIS

perl get_stats.pl --help

perl get_stats.pl [options] mode

where mode can be:
 - genomic_alignments

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
aliases given in the registry_configuration_file

=back

=head2 FILTERS

=over

=item B<--species new_species_db_name_or_alias>

Limit the stats to the data for this species. Several species can be used

=item B<--method_link method_link_type>

Limit the stats to this method_link (BLASTZ_NET, TRANSLATED_BLAT...)

=back

=head2 OPTIONS

=over

=item B<[--detail 1|2|3]>

Defines the level of detail of the stats given. Default value is 1.

=back

=head1 OUTPUT

=head2 genomic_alignments MODE

In this mode, the statistics are returned by method_link_species_set. Only the method_link with an ID
lower than 100 are taken into account. The amount of information returned depends on the level of detail:

=head3 detail level 1

There will be 1 single line of text by method_link_species_set with the method_link_type, the set of species and
the number of alignments. This is the fastest way.

=head3 detail level 2

There will be for each method_link_species_set a first line with the metod_link_type and then, for every species,
another line with more data: the number of DnaFrags, the total length in bp, the number of alignments, the total length
of those alignments in bp and the percentage of coverage.

NB: These statistics assume that there is no overlapping alignments!

=head3 detail level 3

In this case, the statistics are given by DnaFrag instead of by species.

NB: These statistics assume that there is no overlapping alignments!

=head1 INTERNAL METHODS

=cut

use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Getopt::Long;

my $usage = qq{USAGE:
perl get_stats.pl --help
perl get_stats.pl [options] mode

where mode can be:
 - genomic_alignments
 
See perldoc for a complete description of the options.
};

my $help;

my $reg_conf;
my $compara;
my $species;
my $method_link_type;
my $detail = 1;

GetOptions(
    "help" => \$help,
    "reg_conf=s" => \$reg_conf,
    "compara=s" => \$compara,
    "species=s@" => \$species,
    "method_link=s" => \$method_link_type,
    "detail=i" => \$detail,
  );
my $mode = shift @ARGV;

# Print Help and exit if help is requested
if ($help) {
  print $description, $usage;
  exit(0);
}

if (!$mode) {
  print $usage;
  exit(1);
}

$| = 0;

##
## Configure the Bio::EnsEMBL::Registry
## Uses $reg_conf if supplied. Uses ENV{ENSMEBL_REGISTRY} instead if defined. Uses
## ~/.ensembl_init if all the previous fail.
##
Bio::EnsEMBL::Registry->load_all($reg_conf);

my $compara_db = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara");

if ($mode =~ /^genomic_alignm/i) {
  my $method_link_species_sets = get_all_mlss_from_species_and_type($species, $method_link_type);
  throw "Nothing to display" if (!$method_link_species_sets or !@$method_link_species_sets);
  print_stats_for_method_link_species_sets($method_link_species_sets, $detail);
} else {
  throw "Mode <$mode> unknown";
}


=head2 get_all_mlss_from_species_and_type

  Arg[1]      : listref of strings $species_names
  Arg[2]      : string $method_link_type
  Description : Returns a set of MethodLinkSpeciesSet objects
                matching the list of species and the method_link_type.
                Any of them or even both can be undef.
  Returns     : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects
  Exceptions  : throws if it can't get the adaptor

=cut

sub get_all_mlss_from_species_and_type {
  my ($species, $method_link_type) = @_;
  my $method_link_species_sets;

  my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "MethodLinkSpeciesSet");
  throw "Cannot get Bio::EnsEMBL::Compara::DBSQL::MethodLinkSpeciesSetAdaptor" if (!$method_link_species_set_adaptor);
  
  if (!$species) {
    if ($method_link_type) {
        $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_method_link_type($method_link_type);
    } else {
        $method_link_species_sets = $method_link_species_set_adaptor->fetch_all();
    }
  
  } else {
    my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "GenomeDB");
    throw "Cannot get Bio::EnsEMBL::Compara::DBSQL::GenomeDBAdaptor" if (!$genome_db_adaptor);
    
    my $mlss_by_dbID;
    my $genome_dbs = $genome_db_adaptor->fetch_all_by_mixed_ref_lists(-SPECIES_LIST => $species);
    throw("No species found from '$species'") unless scalar(@$genome_dbs);

    if ($method_link_type) {
        my $mlss = $method_link_species_set_adaptor->fetch_by_method_link_type_GenomeDBs($method_link_type, $genome_dbs);
        $method_link_species_sets = [$mlss] if $mlss;
    } else {
        my $ssa = Bio::EnsEMBL::Registry->get_adaptor($compara, "compara", "SpeciesSet");
        my $ss = $ssa->fetch_by_GenomeDBs($genome_dbs);
        $method_link_species_sets = $method_link_species_set_adaptor->fetch_all_by_species_set_id($ss->dbID) if $ss;
    }
  }

  return ($method_link_species_sets or []);
}
  
=head2 print_stats_for_method_link_species_sets

  Arg[1]      : listref of Bio::EnsEMBL::Compara::MethodLinkSpeciesSet $method_link_species_sets
  Arg[2]      : int $detail_level (1, 2 or 3)
  Description : This method gets and prints some statistics for a set of
                Bio::EnsEMBL::Compara::MethodLinkSpeciesSet objects. You can
                increase the level of detail from 1 to 3.
  Returns     : -none-
  Exceptions  : throws if it can't get the adaptor

=cut

sub print_stats_for_method_link_species_sets {
  my ($method_link_species_sets, $detail) = @_;

  my $dbc = Bio::EnsEMBL::Registry->get_DBAdaptor($compara, "compara")->dbc;
  throw("Cannot get the DBAdaptor!") if (!$dbc);
  my ($sql, @values);

  $sql = qq{
      SELECT
        COUNT(*), SUM(length)
      FROM
        dnafrag
      WHERE
        genome_db_id = ?
    };
  my $dnafrag_sth = $dbc->prepare($sql);
  $sql = qq{
      SELECT
        COUNT(*)
      FROM
        genomic_align_block
      WHERE
        genomic_align_block.method_link_species_set_id = ?
    };
  my $alignment1_sth = $dbc->prepare($sql);
  $sql = qq{
      SELECT
        COUNT(*), SUM(dnafrag_end - dnafrag_start + 1)
      FROM
        genomic_align
        LEFT JOIN dnafrag USING (dnafrag_id)
      WHERE
        method_link_species_set_id = ? AND
        dnafrag.genome_db_id = ?
    };
  my $alignment2_sth = $dbc->prepare($sql);
  $sql = qq{
      SELECT
        COUNT(*), SUM(dnafrag_end - dnafrag_start + 1), dnafrag.coord_system_name, dnafrag.name, dnafrag.length
      FROM
        dnafrag
        LEFT JOIN genomic_align USING (dnafrag_id)
      WHERE
        (genomic_align.method_link_species_set_id = ? OR genomic_align.genomic_align_id IS NULL) AND
        dnafrag.genome_db_id = ?
      GROUP BY (dnafrag.dnafrag_id)
    };
  my $alignment3_sth = $dbc->prepare($sql);


  foreach my $method_link_species_set (sort {$a->method->dbID <=> $b->method->dbID} @$method_link_species_sets) {
    last if ($method_link_species_set->method->dbID > 100); # keep only method_link related to genomic_aligns
    if ($detail == 1) {
      print uc($method_link_species_set->method->type), " for";
      foreach my $this_genome_db (@{$method_link_species_set->species_set->genome_dbs}) {
        print " -", $this_genome_db->name, " (", $this_genome_db->assembly, ")";
      }
      $alignment1_sth->execute($method_link_species_set->dbID);
      @values = $alignment1_sth->fetchrow_array();
      print ": ", ($values[0] or 0), " alignments\n";
    } else {
      print uc($method_link_species_set->method->type), " for\n";
      foreach my $this_genome_db (@{$method_link_species_set->species_set->genome_dbs}) {
        if (!$this_genome_db->{my_num_of_dnafrags}) {
          $dnafrag_sth->execute($this_genome_db->dbID);
          @values = $dnafrag_sth->fetchrow_array();
          throw($!) if (!@values);
          $this_genome_db->{my_num_of_dnafrags} = $values[0];
          $this_genome_db->{my_length} = $values[1];
        }
        print "  - ", $this_genome_db->name, " (", $this_genome_db->assembly,
            " - $this_genome_db->{my_num_of_dnafrags} DnaFrags - $this_genome_db->{my_length} bp):";
        if ($detail == 2) {
          $alignment2_sth->execute($method_link_species_set->dbID, $this_genome_db->dbID);
          @values = $alignment2_sth->fetchrow_array();
          print " ", ($values[0] or 0), " alignments; ", ($values[1] or 0), " bp";
          if ($values[1]) {
            printf " (%.2f%%)\n", ($values[1] * 100 / $this_genome_db->{my_length}); 
          } else {
            print " (0.00%)\n";
          }
        } else {
          $alignment3_sth->execute($method_link_species_set->dbID, $this_genome_db->dbID);
          print "\n";
          while (@values = $alignment3_sth->fetchrow_array()) {
            print "    - ", $values[2], ".", $values[3], ": ", ($values[1]?$values[0]:0), " alignments; ",
                ($values[1] or 0), " bp";
            if ($values[1]) {
              printf " (%.2f%%)\n", ($values[1] * 100 / $values[4]); 
            } else {
              print " (0.00%)\n";
            }
          }
        }
      }
    }
  }
}
