package Bio::EnsEMBL::GlyphSet::rprot_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return "Rodent proteins";
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return $Config->get('rprot_transcript','colours');
}

sub transcript_type {
  my $self = shift;
  return 'rodent_protein';
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
  return $self->{'container'}->get_all_Genes_by_type('rodent_protein');
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $pid  = $transcript->stable_id();
    return {
        'caption'  => "Rodent protein",
        $pid       => $self->href( $gene, $transcript )
    };
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return $transcript->stable_id();
}

sub legend { return ; }

sub error_track_name { return 'Rodent proteins'; }

1;
