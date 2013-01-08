=head1 LICENSE

  Copyright (c) 1999-2013 The European Bioinformatics Institute and
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

Bio::EnsEMBL::Compara::RunnableDB::PairAligner::UcscToEnsemblMapping

=head1 SYNOPSIS


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
use Bio::EnsEMBL::Compara::MethodLinkSpeciesSet;
use Bio::EnsEMBL::Utils::Exception qw(throw warning);

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
