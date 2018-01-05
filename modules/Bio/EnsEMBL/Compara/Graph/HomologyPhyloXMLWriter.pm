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

package Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter;

=pod

=head1 NAME

Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter

=head1 SYNOPSIS

  use Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter;

  my $string_handle = IO::String->new();
  my $w = Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $string_handle
  );

  my $h = $dba->get_HomologyAdaptor()->fetch_by_dbID(1);

  $w->write_homologies($h);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG

  my $xml_scalar_ref = $string_handle->string_ref();

  #Or to write to a file via IO::File
  my $file_handle = IO::File->new('output.xml', 'w');
  $w = Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $file_handle
  );
  $w->write_homologies($h);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $file_handle->close();

  #Or letting this deal with it
  $w = Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter->new(
    -SOURCE => 'Ensembl', -ALIGNED => 1, -FILE => 'loc.xml'
  );
  $w->write_homologies($h);
  $w->finish(); #YOU MUST CALL THIS TO WRITE THE FINAL TAG
  $w->handle()->close();

=head1 DESCRIPTION

Used as a way of emitting instances of L<Bio::EnsEMBL::Compara::Homology>
in a format which conforms to L<PhyloXML|http://www.phyloxml.org/>.

The code provides a number of property extensions to the existing PhyloXML
standard:

=over 8

=item B<Compara:genome_db_name>

Used to show the name of the GenomeDB of the species found. Useful when 
taxonomy is not exact

=back

The same document is persistent between write_homologies() calls so to create
a new XML document create a new instance of this object.

=head1 SUBROUTINES/METHODS

See inline

=head1 CONTACT

 Please email comments or questions to the public Ensembl
 developers list at <http://lists.ensembl.org/mailman/listinfo/dev>.

 Questions may also be sent to the Ensembl help desk at
 <http://www.ensembl.org/Help/Contact>.

=cut

use strict;
use warnings;

use Bio::EnsEMBL::Utils::Argument qw(rearrange);
use Bio::EnsEMBL::Utils::Exception qw(throw warning);
use Bio::EnsEMBL::Utils::Scalar qw(check_ref wrap_array);

use base qw/Bio::EnsEMBL::Compara::Graph::PhyloXMLWriter/;



=head2 new()

  Arg[CDNA]             : Boolean; indicates if we want CDNA emitted or peptide.
                          Defaults to B<false>.
  Arg[ALIGNED]          : Boolean; indicates if we want to emit aligned
                          sequence. Defaults to B<false>.
  Arg[NO_SEQUENCES]     : Boolean; indicates we want to ignore sequence
                          dumping. Defaults to B<false>.

  Description : Creates a new homology writer object.
  Returntype  : Instance of the writer
  Exceptions  : None
  Example     : my $w = Bio::EnsEMBL::Compara::Graph::HomologyPhyloXMLWriter->new(
                  -SOURCE => 'Ensembl', -ALIGNED => 1, -HANDLE => $handle
                );
  Status      : Stable

=cut

sub new {
  my ($class, @args) = @_;
  $class = ref($class) || $class;
  my $self = $class->SUPER::new(@args);

  my ($cdna, $aligned, $no_sequences) = 
    rearrange([qw(cdna aligned no_sequences)], @args);

  $cdna ||= 0;
  if( ($cdna || $aligned) && $no_sequences) {
    warning "-CDNA or -ALIGNED was specified but so was -NO_SEQUENCES. Will ignore sequences";
  }

  $self->cdna($cdna);
  $self->aligned($aligned);
  $self->no_sequences($no_sequences);

  return $self;
}

=pod

=head2 cdna()

  Arg[0] : The value to set this to
  Description : Indicates if we want CDNA sequence in the XML. If false
  the code will dump peptide data
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub cdna {
  my ($self, $cdna) = @_;
  $self->{cdna} = $cdna if defined $cdna;
  return $self->{cdna};
}

=pod

=head2 no_sequences()

  Arg[0] : The value to set this to
  Description : Indicates if we do not want to perform sequence dumping 
  Returntype  : Boolean
  Exceptions  : None
  Status      : Stable

=cut

sub no_sequences {
  my ($self, $no_sequences) = @_;
  $self->{no_sequences} = $no_sequences if defined $no_sequences;
  return $self->{no_sequences};
}


=pod

=head2 aligned()

  Arg[0] : The value to set this to
  Description : Indicates if we want to push aligned sequences into the XML
  Returntype : Boolean
  Exceptions : None
  Status     : Stable

=cut

sub aligned {
  my ($self, $aligned) = @_;
  $self->{aligned} = $aligned if defined $aligned;
  return $self->{aligned};
}



=head2 write_homologies()

  Arg[0]      : The homology to write. Can be a single Homology or an ArrayRef
  Description : Writes an homology into the backing document representation
  Returntype  : None
  Exceptions  : Possible if there is an issue with retrieving data from the homology
  instance
  Example     : $writer->write_homologies($homology);
                $writer->write_homologies([$homology1, $homology2]);
  Status      : Stable

=cut

sub write_homologies {
  my ($self, $homologies) = @_;
  $homologies = wrap_array($homologies);
  foreach my $homology (@{$homologies}) {
    $self->_write_homology($homology);
  }
  return;
}


sub _write_homology {
    my ($self, $homology) = @_;

    my $w = $self->_writer();

    my %attr = (rooted => 'false', type => 'homology');
    $w->startTag('phylogeny', %attr);

    # The elements must be in the same order as in the .xsd !!
    $w->dataElement('id', $homology->dbID);
    $w->dataElement('description', $homology->description);
    $w->dataElement('confidence', $homology->is_tree_compliant,
        'type'  => 'is_compliant_to_gene_tree',
    );
    $w->dataElement('confidence', $homology->is_high_confidence,
        'type'  => 'is_high_confidence',
    );

    $w->startTag('clade');
    my $stn = $homology->species_tree_node;
    if($stn) {
        $self->_write_species_tree_node($stn);
    }
    foreach my $prot (@{$homology->get_all_Members}) {
        $w->startTag('clade');
        $self->_write_seq_member($prot);
        $w->endTag('clade');
    }
    $w->endTag('clade');

    foreach my $tag (qw(n s dn ds lnl dnds_ratio goc_score wga_coverage)) {
        my $value = $homology->$tag;
        if (defined $value and $value ne '') {
            $w->dataElement('property', $value,
                'datatype' => 'xsd:float',
                'ref' => 'Compara_homology:'.$tag,
                'applies_to' => 'phylogeny'
            );
        }
    }
    $w->endTag('phylogeny');
}


1;

