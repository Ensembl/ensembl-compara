package Bio::EnsEMBL::GlyphSet::transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || 'Transcripts';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'unknown'   => $Config->get('transcript_lite','unknown'),
        'known'     => $Config->get('transcript_lite','known'),
        'pseudo'    => $Config->get('transcript_lite','pseudo'),
        'ext'       => $Config->get('transcript_lite','ext'),
        'hi'        => $Config->get('transcript_lite','hi'),
        'superhi'   => $Config->get('transcript_lite','superhi')
    };
}

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_VirtualTranscripts_startend_lite( 'ensembl' );
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
    my $id   = $vt->{'synonym'} eq '' ? $vtid : $vt->{'synonym'};
    return {
        'caption'                       => $id,
        "00:Transcr:$vtid"              => "",
        "01:(Gene:$vt->{'gene'})"       => "",
        '03:Transcript information'     => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vt->{'gene'}",
        '04:Protein information'        => "/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=".$vt->{'translation'},
        '05:Supporting evidence'        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$vtid",
        '06:Expression information'     => "/$ENV{'ENSEMBL_SPECIES'}/sageview?alias=$vt->{'gene'}",
        '07:Protein sequence (FASTA)'   => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$vtid",
        '08:cDNA sequence'              => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$vtid",
    };
}

sub text_label {
    my ($self, $vt) = @_;
    my $vtid = $vt->{'stable_id'};
    my $id   = $vt->{'synonym'} eq '' ? $vtid : $vt->{'synonym'};
    return $self->{'config'}->{'_transcript_names_'} eq 'yes' ?
        ($vt->{'type'} eq 'unknown' ? 'NOVEL' : $id) : $vtid;    
}

sub legend {
    my ($self, $colours) = @_;
    return ('genes', 900, 
        [
            'EnsEMBL predicted genes (known)' => $colours->{'known'},
            'EnsEMBL predicted genes (novel)' => $colours->{'unknown'}
        ]
    );
}

sub error_track_name { return 'EnsEMBL transcripts'; }

1;
