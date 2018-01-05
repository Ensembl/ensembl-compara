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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscToEnsemblMapping

=head1 DESCRIPTION


Convert UCSC names to ensembl names (reference only chromosomes and supercontigs, ie no haplotypes)
First check the names using chromInfo.txt and then go to mapping file if necessary eg ctgPos.txt for human
Download from:
http://hgdownload.cse.ucsc.edu/downloads.html
Choose species
Choose Annotation database
wget http://hgdownload.cse.ucsc.edu/goldenPath/ponAbe2/database/chromInfo.txt.gz

=cut

package Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscToEnsemblMapping;

use strict;
use warnings;
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;

use base ('Bio::EnsEMBL::Compara::RunnableDB::BaseRunnable');

############################################################

=head2 fetch_input

    Title   :   fetch_input
    Usage   :   $self->fetch_input
    Returns :   nothing
    Args    :   none

=cut

sub fetch_input {
  my( $self) = @_; 

  #Must define chromInfo file
  return if (!defined $self->param('chromInfo_file') || $self->param('chromInfo_file') eq "");

  my $gdba = $self->compara_dba->get_GenomeDBAdaptor;
  
  my $genome_db = $gdba->fetch_by_name_assembly($self->param('species'));
  $self->param('genome_db', $genome_db);

  #Get slice adaptor
  my $slice_adaptor = $genome_db->db_adaptor->get_SliceAdaptor;

  my $ensembl_names;
  my $ucsc_to_ensembl_mapping;
  
  #Get all toplevel slices
  my $ref_slices = $slice_adaptor->fetch_all("toplevel");
  
  foreach my $this_slice ( @$ref_slices ) {
      $ensembl_names->{$this_slice->seq_region_name} = 1;
  }
  
  #Open UCSC chromInfo file
  open UCSC, $self->param('chromInfo_file') or die ("Unable to open " . $self->param('chromInfo_file'));
  while (<UCSC>) {
      my ($ucsc_chr, $size, $file) = split " ";
      my $chr = $ucsc_chr;
      $chr =~ s/chr//;
      if ($ensembl_names->{$chr}) {
	  $ensembl_names->{$chr} = 2;
	  $ucsc_to_ensembl_mapping->{$ucsc_chr} = $chr;
      } elsif ($chr eq "M") {
	  #Special case for MT
	  $ensembl_names->{"MT"} = 2;
	  $ucsc_to_ensembl_mapping->{$ucsc_chr} = "MT";
      } else {
	  #Try extracting gl from filename
	  if (defined $self->param('ucsc_map')) {
	      read_ucsc_map($self->param('ucsc_map'), $ensembl_names, $ucsc_to_ensembl_mapping);
	  } else {
	      die ("You must provide a UCSC mapping file");
	  }
      }
  }
  
  close UCSC;
  foreach my $chr (keys %$ensembl_names) {
      if ($ensembl_names->{$chr} != 2) {
	  die ("Failed to find $chr in UCSC");
      }
  }
  $self->param('ucsc_to_ensembl_mapping', $ucsc_to_ensembl_mapping);
}

sub read_ucsc_map {
    my ($ucsc_map, $ensembl_names, $ucsc_to_ensembl_mapping) = @_;

    open MAP, $ucsc_map or die ("Unable to open " . $ucsc_map);

    while (<MAP>) {
	my ($contig, $size, $chrom, $chromStart, $chromEnd) = split " ";
	if ($ensembl_names->{$contig}) {
	    #print "FOUND $contig\n";
	    $ensembl_names->{$contig} = 2;
	    $ucsc_to_ensembl_mapping->{$chrom} = $contig;
	}
    }

    close MAP;
}

sub run {
    my $self = shift;

}

sub write_output {
    my ($self) = shift;
 
    return if (!defined $self->param('chromInfo_file') || $self->param('chromInfo_file') eq "");

    my $genome_db_id = $self->param('genome_db')->dbID;

    #Insert into ucsc_to_ensembl_mapping table
    my $sql = "INSERT INTO ucsc_to_ensembl_mapping (genome_db_id, ucsc, ensembl) VALUES (?,?,?)";
    my $sth = $self->compara_dba->dbc->prepare($sql);

    my $ucsc_to_ensembl_mapping = $self->param('ucsc_to_ensembl_mapping');
    foreach my $ucsc_chr (keys %$ucsc_to_ensembl_mapping) {
	#print "$ucsc_chr " . $ucsc_to_ensembl_mapping->{$ucsc_chr} . "\n";
	$sth->execute($genome_db_id, $ucsc_chr, $ucsc_to_ensembl_mapping->{$ucsc_chr});
    }
    $sth->finish();

}

1;
