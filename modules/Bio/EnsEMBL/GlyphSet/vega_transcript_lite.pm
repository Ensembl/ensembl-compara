package Bio::EnsEMBL::GlyphSet::vega_transcript_lite;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || 'Vega trans.';
}

sub colours {
    my $self = shift;
    return $self->{'config'}->get('vega_transcript_lite','colours');
}

sub transcript_type {
  my $self = shift;
  return 'vega';
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;

    my $highlight = undef;
    my $type = $transcript->type();
    $type =~ s/HUMACE-//g;
    my $colour = $colours->{$type};

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
    my ($self, $gene, $transcript, %highlights ) = @_;

    my $tid = $transcript->stable_id();
    my $gid = $gene->stable_id();

    return ($self->{'config'}->get('vega_transcript_lite','_href_only') eq '#tid' && exists $highlights{$gene->stable_id()} ) ?
       "#$tid" :
       qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?db=vega&gene=$gid);
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
        'caption'                       => "Vega Gene",
        "00:$id"			=> "",
	"01:Gene:$gid"                  => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gid&db=vega",
        "02:Transcr:$tid"    	        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$tid&db=vega",                	
        '04:Export cDNA'                => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
        "06:Sanger curated ($type)"     => '',
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=$pid&db=vega);
    $zmenu->{'05:Export Peptide'}=
    	qq(/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid);	
    }
    
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    return $transcript->external_name() || $transcript->stable_id();
}

sub features {
  my ($self) = @_;

  return $self->{'container'}->get_all_Genes('otter');
}


sub legend {
    my ($self, $colours) = @_;
    return ('vega_genes', 1000,
            [
                'Curated known genes'    => $colours->{'Known'},
                'Curated novel CDS'      => $colours->{'Novel_CDS'},
                'Curated putative'       => $colours->{'Putative'},
                'Curated novel Trans'    => $colours->{'Novel_Transcript'},
                'Curated pseudogenes'    => $colours->{'Pseudogene'},
                'Curated predicted gene'         => $colours->{'Predicted_Gene'},
                'Curated Immunoglobulin segment' => $colours->{'Ig_Segment'},
                'Curated Immunoglobulin pseudogene' => $colours->{'Ig_Pseudogene'},
                'Curated Polymorphic' => $colours->{'Polymorphic'},
            ]
    );
}

sub error_track_name { return 'Sanger transcripts'; }

1;
