package Bio::EnsEMBL::GlyphSet::fgenesh;
use strict;
use vars qw(@ISA);

use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Gene;

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub analysis_logic_name{
  my $self = shift;
  return $self->my_config('LOGIC_NAME'); # E.g. 'Genscan, SNAP etc
}

sub my_label {
	my $self = shift;
	return $self->my_config('track_label') || $self->analysis_logic_name;
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'hi'               => $Config->get('fgenesh','hi'),
        'col'              => $Config->get('fgenesh','col'),
        'super'            => $Config->get('fgenesh','superhi'),
    };
}

sub features {
  my $self = shift;
  my @genes = ();
  my $type = $self->analysis_logic_name;
  #obtain fgenesh transcripts
  foreach my $transcript (@{$self->{'container'}->get_all_PredictionTranscripts($type)}) {
    my $gene = new Bio::EnsEMBL::Gene();
       $gene->add_Transcript($transcript);
    push @genes, $gene;
  }

  return \@genes;
}

sub colour {
    my ($self, $gene, $transcipt, $colours, %highlights) = @_;
    return ( $colours->{'col'}, $self->my_config('LOGIC_NAME'), undef );
}

sub href {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->stable_id();
    return undef unless my $gft = $self->species_defs->GENSCAN_FASTA_TABLE;
    return $self->{'config'}->{'exturl'}->get_url( 'FASTAVIEW', { 'FASTADB' => "Peptide_$gft" , 'ID' => $id } );
    
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->stable_id();
    return { 'caption' => $id } unless my $gft = $self->species_defs->GENSCAN_FASTA_TABLE;
    return {
	'caption' => $id,
        '01:Peptide sequence' => $self->href( $gene, $transcript ),
        '02:cDNA sequence'    => $self->{'config'}->{'exturl'}->get_url( 'FASTAVIEW', { 'FASTADB' => "cDNA_$gft", 'ID' => $id } ),
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

sub error_track_name { return 'Fgenesh'; }

1;

