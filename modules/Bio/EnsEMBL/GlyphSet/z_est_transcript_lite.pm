package Bio::EnsEMBL::GlyphSet::z_est_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || 'EST transcripts';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'estgene'   => $Config->get('z_est_transcript_lite','estgene'),
        'unknown'   => $Config->get('z_est_transcript_lite','unknown'),
        'pseudo'    => $Config->get('z_est_transcript_lite','pseudo'),
        'ext'       => $Config->get('z_est_transcript_lite','ext'),
        'hi'        => $Config->get('z_est_transcript_lite','hi'),
        'superhi'   => $Config->get('z_est_transcript_lite','superhi')
    };
}

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_VirtualTranscripts_startend_lite_coding( 'z_estgene' );
}

sub colour {
    my ($self, $vt, $colours, %highlights) = @_;
    return ( 
        $colours->{$vt->{'type'}}, 
        exists $highlights{$vt->{'stable_id'}} ? $colours->{'superhi'} : (
         exists $highlights{$vt->{'synonym'}}  ? $colours->{'superhi'} : (
          exists $highlights{$vt->{'gene'}}    ? $colours->{'hi'} : undef ))
    );
}

sub href {
    my ($self, $vt) = @_;
    return $self->{'config'}->{'_href_only'} eq '#tid' ?
        "#$vt->{'stable_id'}" :
        qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vt->{'gene'});

}

sub zmenu {
    my ($self, $vt) = @_;
    my $vtid = $vt->{'stable_id'};
    my $zmenu = {
        'caption'                       => $vtid,
        "00:Transcr:$vtid"              => "",
    };
    return $zmenu;
}

sub text_label { return ''; }


sub legend {
    my ($self, $colours) = @_;
    return ('genes', 900, 
        [
            'EST transcript' => $colours->{'estgene'},
        ]
    );
}

sub error_track_name { return 'EnsEMBL genewises'; }

1;
