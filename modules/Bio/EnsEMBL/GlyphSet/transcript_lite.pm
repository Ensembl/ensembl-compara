package Bio::EnsEMBL::GlyphSet::transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || 'Ensembl trans.';
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

sub genes {
  my ($self) = @_;

  return $self->{'container'}->get_Genes_by_source('core');
}


sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;

    my $genecol = $colours->{$transcript->is_known() ? 'known' : 'unknown'};

    if(exists $highlights{$transcript->stable_id()}) {
      return ($genecol, $colours->{'superhi'});
    } elsif(exists $highlights{$transcript->external_name()}) {
      return ($genecol, $colours->{'superhi'});
    } elsif(exists $highlights{$gene->stable_id()}) {
      return ($genecol, $colours->{'hi'});
    }
      
    return ($genecol, undef);
}

sub href {
    my ($self, $gene, $transcript ) = @_;

    my $gid = $gene->stable_id();
    my $tid = $transcript->stable_id();

    return $self->{'config'}->{'_href_only'} eq '#tid' ?
        "#$tid" : 
        qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gid);

}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : $transcript->external_name();
    my $zmenu = {
        'caption'                       => $id,
        "00:Transcr:$tid"              => "",
        "01:(Gene:$gid)"       => "",
        '03:Transcript information'     => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gid",
        '04:Protein information'        => "/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=".$transcript->translation->stable_id(),
        '05:Supporting evidence'        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$tid",
        '07:Protein sequence (FASTA)'   => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$tid",
        '08:cDNA sequence'              => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
    };
    my $DB = EnsWeb::species_defs->databases;

    if($DB->{'ENSEMBL_EXPRESSION'}) {
      $zmenu->{'06:Expression information'} = 
	"/$ENV{'ENSEMBL_SPECIES'}/sageview?alias=$gid";
    }

    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $id  = ($transcript->external_name() eq '') ? 
      $tid : $transcript->external_name();

    if( $self->{'config'}->{'_both_names_'} eq 'yes') {
        return $tid.(($transcript->external_name() eq '') ? '' : " ($id)" );
    }

    return $self->{'config'}->{'_transcript_names_'} eq 'yes' ?
        ($transcript->is_known() ? $id : 'NOVEL') : $tid;    
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
