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
    my $self = shift;
    return $self->{'container'}->get_all_VirtualTranscripts_startend_lite_coding( 'embl' );
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
    my $ID = $vt->{'synonym'};
    $ID =~ s/\.\d+$//;
    return $vt->{'external_db'} ne '' ?
           $self->{'config'}->{'ext_url'}->get_url( $vt->{'external_db'}, $ID ) :
            undef;
}

sub zmenu {
    my ($self, $vt) = @_;
    my $zmenu = {
        'caption'  => "EMBL: $vt->{'stable_id'}",
        '01:EMBL curated '.($vt->{'type'} eq 'pseudo' ? 'pseudogene' : 'transcript') => ''
    };
    $zmenu->{ "02:$vt->{'external_db'}:$vt->{'synonym'}" } = $self->href($vt) if $vt->{'external_db'} ne '';
    return $zmenu;
}

sub text_label {
    my ($self, $vt) = @_;
    return $vt->{'synonym'} || $vt->{'stable_id'};
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
