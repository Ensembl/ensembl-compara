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
        'xref'      => $Config->get('transcript_lite','xref'),
        'pred'      => $Config->get('transcript_lite','pred'),
        'known'     => $Config->get('transcript_lite','known'),
        'hi'        => $Config->get('transcript_lite','hi'),
        'superhi'   => $Config->get('transcript_lite','superhi')
    };
}

sub features {
  my ($self) = @_;

  return $self->{'container'}->get_all_Genes_by_source('core');
}


sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;

    my $genecol = $colours->{ $transcript->is_known() ? lc( $transcript->external_status ) : 'unknown'};

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
    my $pid = $transcript->translation->stable_id(),
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
    my $zmenu = {
        'caption'                       => "Ensembl Gene",
        "00:$id"			=> "",
	"01:Gene:$gid"                  => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gid&db=core",
        "02:Transcr:$tid"    	        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$tid&db=core",                	
        '04:Export cDNA'                => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
        
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=$pid&db=core);
    $zmenu->{'05:Export Peptide'}=
    	qq(/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid);	
    }
    
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
           # 'EnsEMBL predicted genes (xref)' => $colours->{'xref'},
           # 'EnsEMBL predicted genes (pred)' => $colours->{'pred'},
            'EnsEMBL predicted genes (novel)' => $colours->{'unknown'}
        ]
    );
}

sub error_track_name { return 'EnsEMBL transcripts'; }

1;
