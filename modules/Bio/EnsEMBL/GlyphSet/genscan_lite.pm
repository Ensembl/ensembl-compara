package Bio::EnsEMBL::GlyphSet::genscan_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Gene;

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    return 'Genscans';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'hi'               => $Config->get('genscan_lite','hi'),
        'super'            => $Config->get('genscan_lite','superhi'),
        'col'              => $Config->get('genscan_lite','col')
    };
}

sub features {
  my $self = shift;
  my @genes = ();
  #obtain genscan transcripts
  foreach my $transcript (@{$self->{'container'}->get_all_PredictionTranscripts('Genscan')}) {
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
    return undef;
 #   my $id = $transcript->id();
 #   return undef if $id =~ /^\d/;
 #   return $self->{'config'}->{'ext_url'}->get_url( 'FASTAVIEW', { 'FASTADB' => 'Peptide_ens_genscan830', 'ID' => $id } );
    
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    return undef;
    my $id = $transcript->id();
    return undef if $id =~ /^\d/;
     return {
	'caption' => $id,
        '01:Peptide sequence' => $self->href( $transcript ),
        '02:cDNA sequence'    => $self->{'config'}->{'ext_url'}->get_url( 'FASTAVIEW', { 'FASTADB' => 'cDNA_ens_genscan830', 'ID' => $id } ),
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

