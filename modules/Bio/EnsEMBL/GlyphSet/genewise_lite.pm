package Bio::EnsEMBL::GlyphSet::genewise_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || 'Genewise';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'similarity_genewise'   => $Config->get('genewise_lite','similarity_genewise'),
        'unknown'   => $Config->get('genewise_lite','unknown'),
        'pseudo'    => $Config->get('genewise_lite','pseudo'),
        'ext'       => $Config->get('genewise_lite','ext'),
        'hi'        => $Config->get('genewise_lite','hi'),
        'superhi'   => $Config->get('genewise_lite','superhi')
    };
}

sub features {
    my $self = shift;
    return $self->{'container'}->get_all_VirtualTranscripts_startend_lite_coding( 'genewise' );
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
    my $zmenu = {
        'caption'                       => $id,
        "00:Transcr:$vtid"              => "",
        "01:(Gene:$vt->{'gene'})"       => "",
        '03:Transcript information'     => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$vt->{'gene'}",
        '04:Protein information'        => "/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=".$vt->{'translation'},
        '05:Supporting evidence'        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$vtid",
        '07:Protein sequence (FASTA)'   => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$vtid",
        '08:cDNA sequence'              => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$vtid",
    };
    my $DB = EnsWeb::species_defs->databases;
    $zmenu->{'06:Expression information'}
      = "/$ENV{'ENSEMBL_SPECIES'}/sageview?alias=$vt->{'gene'}" if $DB->{'ENSEMBL_EXPRESSION'};
    return $zmenu;
}

sub text_label {
    my ($self, $vt) = @_;
    my $vtid = $vt->{'stable_id'};
    my $id   = $vt->{'synonym'} eq '' ? $vtid : $vt->{'synonym'};
    return $self->{'config'}->{'_transcript_names_'} eq 'yes' ?
        ($vt->{'type'} eq 'unknown' ? 'NOVEL' : $id) : $vtid;    
}

sub error_track_name { return 'EnsEMBL genewises'; }

1;
