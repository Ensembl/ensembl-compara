package Bio::EnsEMBL::GlyphSet::genewise;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Gene;

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    return 'Genewise';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'hi'               => $Config->get('genewise','hi'),
        'col'              => $Config->get('genewise','col'),
        'super'            => $Config->get('genewise','superhi'),
    };
}

sub features {
  my $self = shift;
  my @genes = ();
  #obtain genewise transcripts
  foreach my $transcript (@{$self->{'container'}->get_all_PredictionTranscripts('GENEWISE')}) {
    my $gene = new Bio::EnsEMBL::Gene();
       $gene->add_Transcript($transcript);
    push @genes, $gene;
  }

  return \@genes;
}

sub colour {
    my ($self, $gene, $transcipt, $colours, %highlights) = @_;
    return ( $colours->{'col'}, undef );
}

sub href {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->stable_id();
    return undef unless my $gft = EnsWeb::species_defs->GENSCAN_FASTA_TABLE;
    return $self->{'config'}->{'ext_url'}->get_url( 'FASTAVIEW', { 'FASTADB' => "Peptide_$gft" , 'ID' => $id } );
    
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->stable_id();
    return { 'caption' => $id } unless my $gft = EnsWeb::species_defs->GENSCAN_FASTA_TABLE;
    return {
	'caption' => $id,
        '01:Peptide sequence' => $self->href( $gene, $transcript ),
        '02:cDNA sequence'    => $self->{'config'}->{'ext_url'}->get_url( 'FASTAVIEW', { 'FASTADB' => "cDNA_$gft", 'ID' => $id } ),
    };

}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return undef;
}

sub legend {
    my ($self, $colours) = @_;
    return undef;
}

sub error_track_name { return 'Genscans'; }

1;

