package Bio::EnsEMBL::GlyphSet::sanger_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || 'Sanger trans.';
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return {
        'hi'               => $Config->get('sanger_transcript_lite','hi'),
        'superhi'          => $Config->get('sanger_transcript_lite','superhi'),
        'HUMACE-Novel_CDS'        => $Config->get('sanger_transcript_lite','sanger_Novel_CDS'),
        'HUMACE-Putative'         => $Config->get('sanger_transcript_lite','sanger_Putative'),
        'HUMACE-Known'            => $Config->get('sanger_transcript_lite','sanger_Known'),
        'HUMACE-Novel_Transcript' => $Config->get('sanger_transcript_lite','sanger_Novel_Transcript'),
        'HUMACE-Pseudogene'       => $Config->get('sanger_transcript_lite','sanger_Pseudogene'),
    };
}

sub transcript_type {
  my $self = shift;

  return 'sanger';
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;

    my $highlight = undef;
    my $colour = $colours->{$transcript->type()};

    if(exists $highlights{$transcript->stable_id()}) {
      $highlight = $colours->{'superhi'};
    } elsif(exists $highlights{$transcript->external_name}) {
      $highlight = $colours->{'superhi'};
    } elsif(exists $highlights{$gene->stable_id()}) {
      $highlight = $colours->{'hi'};
    }

    return ($colour, $highlight); 
  }

sub href {
    my ($self, $gene, $transcript) = @_;

    my $tid = $transcript->stable_id();
    my $gid = $gene->stable_id();

    return $self->{'config'}->{'_href_only'} eq '#tid' ?
       "#$tid" :
       qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?db=sanger&gene=$gid);
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $pid = $transcript->translation->stable_id(),
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : $transcript->external_name();
    my $type = $transcript->type();
    $type =~ s/HUMACE-//g;
    
    my $zmenu = {
        'caption'                       => "Sanger Gene",
        "00:$tid"			=> "",
	"01:Gene:$gid"                  => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gid&db=sanger",
        "02:Transcr:$tid"    	        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$tid&db=sanger",                	
        '04:Export cDNA'                => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
        "06:Sanger curated ($type)"     => '',
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=$pid&db=sanger);
    $zmenu->{'05:Export Peptide'}=
    	qq(/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid);	
    }
    
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return $transcript->stable_id();
}

sub features {
  my ($self) = @_;

  return $self->{'container'}->get_all_Genes_by_source('sanger');
}


sub legend {
    my ($self, $colours) = @_;
    return ('sanger_genes', 1000,
            [
                'Sanger curated known genes'    => $colours->{'HUMACE-Known'},
                'Sanger curated novel CDS'      => $colours->{'HUMACE-Novel_CDS'},
                'Sanger curated putative'       => $colours->{'HUMACE-Putative'},
                'Sanger curated novel Trans'    => $colours->{'HUMACE-Novel_Transcript'},
                'Sanger curated pseudogenes'    => $colours->{'HUMACE-Pseudogene'}
            ]
    );
}

sub error_track_name { return 'Sanger transcripts'; }

1;
