package Bio::EnsEMBL::GlyphSet::est_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    return 'EST trans.';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'genomewise'=> $Config->get('est_transcript_lite','genomewise'),
        'hi'        => $Config->get('est_transcript_lite','hi'),
        'superhi'   => $Config->get('est_transcript_lite','superhi')
    };
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    
    return (  $colours->{$transcript->type()} );
}

sub href {
  my ($self, $gene, $transcript) = @_;

  if( $self->{'config'}->{'_href_only'} eq '#tid' ) {
    return "#" . $transcript->stable_id();
  }

  my $gid = $gene->stable_id();

  return qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?db=estgene&gene=$gid);
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;

    my $zmenu = {
       'caption'                     => "EST Gene",
       "02:Gene: " . $gene->stable_id()  => $self->href( $gene, $transcript ),
    };

    my $translation_id = $transcript->translation()->stable_id();

    if(defined $translation_id) {
      $zmenu->{"03:Protien: $translation_id"} =
	qq(/$ENV{'ENSEMBL_SPECIES'}/protview?db=estgene&peptide=$translation_id);
    }
    
    return $zmenu;
  }

sub text_label { return ''; }

sub features {
  my ($self) = @_;

  return $self->{'container'}->get_all_Genes_by_source('estgene');
}

sub legend {
    my ($self, $colours) = @_;
    return ('est_genes', 1000, 
        [
            'EST genes' => $colours->{'genomewise'},
        ]
    );
}

sub error_track_name { return 'EST transcripts'; }

1;
