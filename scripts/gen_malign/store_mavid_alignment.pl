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


=head1 NAME

store_mavid_alignment.pl

=head1 AUTHOR

Javier Herrero

=head1 CONTACT

Please email comments or questions to the public Ensembl
developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

Questions may also be sent to the Ensembl help desk at
<http://www.ensembl.org/Help/Contact>.

This software is part of the EnsEMBL project.

=head1 DESCRIPTION

This program reads all MAVID alignment files in a directory and stores the alignments into the selected database.

=head1 USAGE

store_mavid_alignment.pl [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'root')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3303)
  -mavid directory_containing_mavid_alignemnts_and_map_file

=head1 KNOWN BUGS

TODO

=head1 INTERNAL FUNCTIONS

=cut

use strict;
use warnings;

use Getopt::Long;
use Pod::Usage;

use Bio::Perl;
use Bio::EnsEMBL::Registry;
use Bio::EnsEMBL::Compara::GenomicAlign;
use Bio::EnsEMBL::Compara::GenomicAlignBlock;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

###############################################################################
##  CONFIGURATION VARIABLES:
##   (*) $berkeley_2_ensembl:  maps the Berkeley species names into the EnseEMBL
##           species naming system.
###############################################################################
my $berkeley_2_ensembl = {
        "hs_34" => ["Homo sapiens", "NCBI34"],
        "rn_3_1"  => ["Rattus norvegicus", "RGSC3.1"],
        "mm_32" => ["Mus musculus", "NCBIM32"],
        "gg_1" => ["Gallus gallus", "WASHUC1"],
        "panTro1" => ["Pan troglodytes", "CHIMP1"],
    };
###############################################################################

my $usage = qq{USAGE:
$0 [-help]
  -host mysql_host_server (for ensembl_compara DB)
  -dbuser db_username (default = 'ensro')
  -dbname ensembl_compara_database
  -port mysql_host_port (default = 3352)
  -mavid directory_containing_mavid_alignemnts
};

my $help = 0;
my $dbname = "compara";
my $dbuser;
my $dbpass;
my $dbport = '3352';
my $mavid_dir;
my $species_string;
my $reg_conf;


GetOptions(
        'help' => \$help,
        'dbname=s' => \$dbname,
        'mavid=s' => \$mavid_dir,
        'species=s' => \$species_string,
        'reg_conf=s' => \$reg_conf,
    );

if ($help) {
  pod2usage({-exitvalue => 0, -verbose => 2});
}

if (defined $reg_conf) {
  Bio::EnsEMBL::Registry->load_all($reg_conf);
}

my $dnafrag_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'DnaFrag');
my $genome_db_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara', 'GenomeDB');
my $method_link_species_set_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara',
    'MethodLinkSpeciesSet');
my $genomic_align_block_adaptor = Bio::EnsEMBL::Registry->get_adaptor($dbname, 'compara',
    'GenomicAlignBlock');

# if (!$dbhost or !$dbname or !$dbuser or !$dbport) {
#   print "ERROR: Not enough information to connect to the database!\n", $usage;
#   exit(1);
# }

## Open and read MAP file
if (!open(MAVID_MAP, $mavid_dir."/map")) {
  print "ERROR: Cannot open <$mavid_dir/map> file!\n", $usage;
  exit(1);
}
my $map_file = [<MAVID_MAP>];
close(MAVID_MAP);

## Parse directory name in order to get species
if ($mavid_dir =~ /((-?\w\w_[\d_]+)+)/) {
  $species_string = $1;
}

if (!$species_string) {
  print "ERROR: Species not defined and cannot be guessed from mavid directory name!\n", $usage;
  exit(1);
}
my @species  = split("-", $species_string);
my $species_set;
foreach my $this_species (@species) {
  my $genome_db = $genome_db_adaptor->fetch_by_name_assembly(@{$berkeley_2_ensembl->{$this_species}});
  push (@$species_set, $genome_db);
}
my $method_link_species_set = new Bio::EnsEMBL::Compara::MethodLinkSpeciesSet(
        -adaptor => $method_link_species_set_adaptor,
        -method => new Bio::EnsEMBL::Compara::Method( -type => 'MAVID' ),
        -species_set => new Bio::EnsEMBL::Compara::SpeciesSet( -genome_dbs => $species_set ),
    );
$method_link_species_set = $method_link_species_set_adaptor->store($method_link_species_set);

## Each line of the MAP file corresponds to a multiple alignment
foreach my $this_line (@{$map_file}) {

  $this_line =~ s/[\r\n]+$//; # chop the <end_of_line> for either Mac, Unix or DOS file
  ## First col corresponds to the alignment_id, next ones to the coordinates of the
  ## sequences in the FASTA files.
  my ($align_id, @fields) = split(" *\t *", $this_line);

  my $this_alignment = {};
  foreach my $this_species (@species) {
    ## Cols are in groups of 4: chrmsme name, starting pos., ending pos. and strand
    my $dnafrag_name = shift(@fields);
    my  $dnafrag_start = shift(@fields);
    my  $dnafrag_end = shift(@fields);
    my  $dnafrag_strand = shift(@fields);

    my ($chromosome) = $dnafrag_name =~ /^chr(.+)$/;
    my $genome_db = $genome_db_adaptor->fetch_by_name_assembly(@{$berkeley_2_ensembl->{$this_species}});
    my $dnafrag = get_this_dnafrag($genome_db, 'chromosome', $chromosome);
    if (!$dnafrag) {
      if ($chromosome) {
        print STDERR
           "Skipping ",
           join("::", @{$berkeley_2_ensembl->{$this_species}}, $chromosome),
           "\n";
      }
      next;
    }

    ## Store data in a hash. MAVID coordinates system does not match EnsEMBL one.
    ## 1 must be added to the starting position of the alignment.
    $this_alignment->{$this_species}->{dnafrag} = $dnafrag;
    $this_alignment->{$this_species}->{dnafrag_start} = $dnafrag_start + 1;
    $this_alignment->{$this_species}->{dnafrag_end} = $dnafrag_end;
    $this_alignment->{$this_species}->{dnafrag_strand} = ($dnafrag_strand eq "+")?1:-1;
  }

  ## Get aligned sequences from FASTA files
  my @these_sequences;
  if (-e "$mavid_dir/$align_id.fa.bz2") {
    @these_sequences = read_all_sequences("bzcat $mavid_dir/$align_id.fa.bz2 |", "fasta");
  } elsif (-e "$mavid_dir/$align_id.fa") {
    @these_sequences = read_all_sequences("$mavid_dir/$align_id.fa", "fasta");
  } else {
    print STDERR "\nCannot find <$mavid_dir/$align_id.fa[.bz2]> file.\n\n";
    next;
  }

  my $alignment_length = $these_sequences[0]->length();

  ## Add aligned sequence to the data hash
  foreach my $this_sequence (@these_sequences) {
    ## Skip this sequence if it is located in an unknown dnafrag.
    next if (!$this_alignment->{$this_sequence->display_id()});
    $this_alignment->{$this_sequence->display_id()}->{aligned_sequence} = $this_sequence->seq();
    $this_sequence = undef;
  }
  @these_sequences = ();
    
  ## Populate objects
  my $these_genomic_aligns;
  foreach my $species (keys %$this_alignment) {
    my $this_genomic_align = new Bio::EnsEMBL::Compara::GenomicAlign(
            -dnafrag => $this_alignment->{$species}->{dnafrag},
            -dnafrag_start => $this_alignment->{$species}->{dnafrag_start},
            -dnafrag_end => $this_alignment->{$species}->{dnafrag_end},
            -dnafrag_strand => $this_alignment->{$species}->{dnafrag_strand},
            -aligned_sequence => $this_alignment->{$species}->{aligned_sequence},
            -level_id => 1
        );
#print STDERR "Bio::EnsEMBL::Compara::GenomicAlign corresponds to ",
#  $this_genomic_align->dnafrag->genome_db->name, " ", $this_genomic_align->dnafrag->name," [",
#  $this_genomic_align->dnafrag_start, "-", $this_genomic_align->dnafrag_end, "] (",
#  ($this_genomic_align->dnafrag_strand == 1?"+":"-"), ")\n";
    my $db_sequence = $this_genomic_align->dnafrag->slice->subseq(
            $this_genomic_align->dnafrag_start,
            $this_genomic_align->dnafrag_end
        );
    my $mavid_sequence = $this_genomic_align->original_sequence;
    if ($db_sequence ne $mavid_sequence) {
      print STDERR "DATAB: ", substr($db_sequence, 0, 10), "..",
          substr($db_sequence, -11), "\n";
      print STDERR "MAVID: ", substr($mavid_sequence, 0, 10), "..",
          substr($mavid_sequence, -11), "\n";
      die "\n\n";
    }
    push(@$these_genomic_aligns, $this_genomic_align) if ($this_genomic_align);
  }
  if (!$these_genomic_aligns) {
    print STDERR "Skipping alignment $align_id!!!\n";
    next;
  }

  my $genomic_align_block = new Bio::EnsEMBL::Compara::GenomicAlignBlock(
          -method_link_species_set => $method_link_species_set,
          -score => undef,
          -length => $alignment_length,
          -genomic_align_array => $these_genomic_aligns
      );

  ## Store everything
  $genomic_align_block_adaptor->store($genomic_align_block);
}

exit(0);


###############################################################################
##  GET THIS DNAFRAG

=head2 get_this_dnafrag

  Arg [1]    : Bio::EnsEMBL::Compara::GenomeDB $genome_db
               The GenomeDB object corresponding to this dnafrag.
  Arg[2]     : string $fragment_type
  Arg[3]     : string $fragment_name
  Example    : get_this_danfrag($human_db, 'chromosome', '17');
  Description: Returns the corresponding DnaFrag object.
  Returntype : Bio::EnsEMBL::Compara::DnaFrag
  Exceptions : returns undef when the DnaFrag does not exist in the database.

=cut

###############################################################################
sub get_this_dnafrag {
  my ($genome_db, $fragment_type, $fragment_name) = @_;

  return if (!$fragment_name);
  my $dnafrags = $dnafrag_adaptor->fetch_all_by_GenomeDB_region($genome_db, $fragment_type, $fragment_name);
  my $dnafrag;
  foreach my $this_dnafrag (@$dnafrags) {
    if ($this_dnafrag->coord_system_name eq $fragment_type && $this_dnafrag->name eq $fragment_name) {
      $dnafrag = $this_dnafrag;
      last;
    }
  }
  
  #returns null if the dnafrag does not exist in the database
  return $dnafrag;
}

