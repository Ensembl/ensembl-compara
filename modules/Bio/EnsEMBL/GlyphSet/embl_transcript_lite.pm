package Bio::EnsEMBL::GlyphSet::embl_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;

	return $self->{'config'}->{'_draw_single_Transcript'} || 'EMBL trans.';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'hi'               => $Config->get('embl_transcript_lite','hi'),
        'super'            => $Config->get('embl_transcript_lite','superhi'),
        'pseudo'           => $Config->get('embl_transcript_lite','pseudo'),
        'ext'              => $Config->get('embl_transcript_lite','ext'),
        'standard'         => $Config->get('embl_transcript_lite','ext'),
    };
}

sub features {
  my ($self) = @_;

  return $self->{'container'}->get_all_Genes_by_source('embl');
}


sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    
    return ( 
      $colours->{$transcript->type()}, 
       exists $highlights{$transcript->stable_id()} ? $colours->{'superhi'} : 
      (exists $highlights{$transcript->external_name()} ? $colours->{'superhi'} :
      (exists $highlights{$gene->stable_id()} ? $colours->{'hi'} : undef ))
    );
  }

sub href {
  my ($self, $gene, $transcript) = @_;
  my $ID = $transcript->external_name();
  $ID = ~s/\.\d+$//;
  
  if($transcript->external_db() ne '') {
    return $self->{'config'}->{'ext_url'}->get_url( $transcript->external_db(),
						    $ID );
  }
  
  return undef;
}

sub zmenu {
  my ($self, $gene, $transcript) = @_;

  my $type = ($gene->type() eq 'pseudo') ? 'pseudogene' : 'transcript';

  my $tid = $transcript->stable_id();
  my $tname = $transcript->external_name();

  my $zmenu = {
      'caption'  => "EMBL: $tid",
      '01:EMBL curated $type' => ''
    };

  if($transcript->external_db() ne '') {
    $zmenu->{ "02:".$transcript->external_db().":$tname" } = 
      $self->href($gene, $transcript); 
  }

  return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return $transcript->external_name() || $transcript->stable_id();
}

sub legend {
    my ($self, $colours) = @_;
    return ('embl_genes', 1000,
            [
                'EMBL curated genes'      => $colours->{'ext'},
                'EMBL pseudogenes'        => $colours->{'pseudo'},
            ]
    );
}

sub error_track_name { return 'EMBL transcripts'; }

1;
