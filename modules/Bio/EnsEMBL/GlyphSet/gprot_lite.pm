package Bio::EnsEMBL::GlyphSet::gprot_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return "GeneWise (Protein)";
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return $Config->get('gprot_lite','colours');
}

sub transcript_type {
  my $self = shift;
  return 'genewise_protein';
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    my $colour = $colours->{'_col'};
    my $highlight;
    if( exists $highlights{$gene->stable_id()} ){
        $highlight = $colours->{'hi'};
    }
    return ( $colour, $highlight );
}

sub href {
    my ($self, $gene, $transcript) = @_;
    return $self->ID_URL( 'UNIPROT', $gene->stable_id );
}

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_Genes_by_type('genewise_protein');
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $pid  = $transcript->stable_id();
    return {
        'caption'  => "GeneWise (Protein)",
        $pid       => $self->href( $gene, $transcript )
    };
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return $transcript->stable_id();
}

sub legend { return ; }

sub error_track_name { return 'GeneWise (Protein)'; }

1;
