package Bio::EnsEMBL::GlyphSet::est_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    return 'EST Transcripts(l)';
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

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_VirtualTranscripts_startend_lite_coding( 'estgene' );
}

sub colour {
    my ($self, $vt, $colours, %highlights) = @_;
    return (  $colours->{$vt->{'type'}} );
}

sub href {
    my ($self, $vt) = @_;
    return $self->{'config'}->{'_href_only'} eq '#tid' ?
        "#$vt->{'stable_id'}" :
        qq(/$ENV{'ENSEMBL_SPECIES'}/est_transview?transcript=$vt->{'transcript_name'});

}

sub zmenu {
    my ($self, $vt) = @_;
    my $vtid = $vt->{'stable_id'};
    my $id   = $vt->{'synonym'} eq '' ? $vtid : $vt->{'synonym'};
    my $zmenu = {
        'caption'                       => $id,
        "00:Transcr:$vtid"              => "",
        "01:(Gene:$vt->{'gene'})"       => "",
        "02:Transcript data"            => $self->href($vt),
    };
    return $zmenu;
}

sub text_label { return ''; }

sub legend {
    my ($self, $colours) = @_;
    return ('genes', 1000, 
        [
            'EST genes'                       => $colours->{'genomewise'},
        ]
    );
}

sub error_track_name { return 'EST transcripts'; }

1;
