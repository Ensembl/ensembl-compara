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
    my $type = $transcript->type() || $gene->type();
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
       qq(/@{[$self->{container}{_config_file_name_}]}/geneview?db=vega&gene=$gid);
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $translation = $transcript->translation;
	my $pid = $translation->stable_id() if $translation;
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : $transcript->external_name();
    my $type = $transcript->type() || $gene->type();
    $type =~ s/HUMACE-//g;
    
    my $zmenu = {
        'caption'                       => "Vega Gene",
        "00:$id"			=> "",
	"01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid&db=vega",
        "02:Transcr:$tid"    	        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid&db=vega",                	
        '04:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
        "06:Sanger curated ($type)"     => '',
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid&db=vega);
    $zmenu->{'05:Export Peptide'}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid);	
    }
    
    return $zmenu;
}


my %legend_map = 
  ( 'Known'                 => 'Curated known gene',
    'Novel_CDS'             => 'Curated novel CDS',
    'Putative'              => 'Curated putative',
    'Novel_Transcript'      => 'Curated novel Trans' ,
    'Pseudogene'            => 'Curated pseudogenes' ,
    'Processed_pseudogene'  => 'Curated processed pseudogenes' ,
    'Unprocessed_pseudogene'=> 'Curated unprocessed pseudogenes' ,
    'Predicted_Gene'        => 'Curated predicted gene' ,
    'Ig_Segment'            => 'Curated Immunoglobulin segment' ,
    'Ig_Pseudogene_Segment' => 'Curated Immunoglobulin pseudogene' ,
    'Polymorphic'           => 'Curated Polymorphic'  );
sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->external_name() || $transcript->stable_id();

    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');
    unless( $short_labels ){
	my $type = $legend_map{$transcript->type} || $transcript->type;
	$id .= " \n$type ";
    }
    return $id;
}

sub features {
  my ($self) = @_;

  if( $self->{'config'}->{'fakecore'} ) {
    return $self->{'container'}->get_all_Genes('otter');
  } else {
    return $self->{'container'}->get_all_Genes('otter','vega');
  }
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
                'Curated processed pseudogenes'    => $colours->{'Processed_pseudogene'},
                'Curated unprocessed pseudogenes'    => $colours->{'Unprocessed_pseudogene'},
                'Curated predicted gene'         => $colours->{'Predicted_Gene'},
                'Curated Immunoglobulin segment' => $colours->{'Ig_Segment'},
                'Curated Immunoglobulin pseudogene' => $colours->{'Ig_Pseudogene_Segment'},
                'Curated Polymorphic' => $colours->{'Polymorphic'},
            ]
    );
}

sub error_track_name { return 'Sanger transcripts'; }

1;
