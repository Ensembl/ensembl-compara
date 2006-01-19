package Bio::EnsEMBL::GlyphSet::vega_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::evega_transcript;

@ISA = qw(Bio::EnsEMBL::GlyphSet::evega_transcript);

our %VEGA_TO_SHOW_ON_VEGA;

sub features {
    my ($self) = @_;
    
    my $genes = $self->{'container'}->get_all_Genes($self->my_config('logic_name'));
    
    # make a list of gene types for the legend
    foreach my $g (@$genes) {
        my $status = $g->status;
        my $biotype = $g->biotype;
        $VEGA_TO_SHOW_ON_VEGA{"$biotype".'_'."$status"}++;
    }
 
    return $genes;
}

sub my_label {
    my $self = shift;
    return $self->my_config('label');
}

sub colours {
    my $self = shift;
    return $self->{'config'}->get($self->check, 'colours');
}

sub href {
    my ($self, $gene, $transcript, %highlights) = @_;
    my $gid = $gene->stable_id();
    my $tid = $transcript->stable_id();
    my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
    return ( $self->{'config'}->get($self->check, '_href_only') eq '#tid' && exists $highlights{lc($gene->stable_id)} ) ?
        "#$tid" : 
        qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core);
}

sub gene_href {
    my ($self, $gene, %highlights) = @_;
    my $gid = $gene->stable_id();
    return ($self->{'config'}->get($self->check,'_href_only') eq '#gid' && exists $highlights{lc($gene->stable_id)} ) ?
        "#$gid" :
        qq(/@{[$self->{container}{_config_file_name_}]}/geneview?db=core;gene=$gid);
}


sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
	my $author =  shift(@{$transcript->get_all_Attributes('author')})->value;
    my $translation = $transcript->translation;
    my $pid = $translation->stable_id() if $translation;
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
	my $type = $self->format_vega_name($gene,$transcript);
    my $zmenu = {
        'caption' 	    => $self->my_config('zmenu_caption'),
        "00:$id"	    => "",
        '01:Type: '.$type => "",
		'02:Author: '.$author => "",
    	"03:Gene:$gid"   => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
        "04:Transcr:$tid"=> "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",
        "05:Exon:$tid"	 => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid;db=core",
        '06:Supporting evidence'    => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid;db=core#evidence",
        '09:Export cDNA'  => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
    };

    if ($pid) {
        $zmenu->{"06:Peptide:$pid"} =  "/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid";
        $zmenu->{'09:Export Peptide'}	= "/@{[$self->{container}{_config_file_name_}]}/exportview?option=peptide;action=select;format=fasta;type1=peptide;anchor1=$pid";
    }

    return $zmenu;
}

sub gene_zmenu {
    my ($self, $gene) = @_;
    my $gid = $gene->stable_id();
    my $id   = $gene->external_name() eq '' ? $gid : $gene->external_name();
	my $type = $self->format_vega_name($gene);
	#hack to get the author off the first transcript (rather than the gene)
	my $f_trans = shift(@{$gene->get_all_Transcripts()});
	my $author =  shift(@{$f_trans->get_all_Attributes('author')})->value;
    my $zmenu = {
        'caption' 	    => $self->my_config('zmenu_caption'),
        "00:$id"	    => "",
        '01:Type: ' . $type => "",
		'02:Author: '.$author => "",
        "03:Gene:$gid"  => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core),
    };
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->external_name() || $transcript->stable_id();
    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');
    unless( $short_labels ){
        my $type = $self->format_vega_name($gene,$transcript);
        $id .= " \n$type ";
    }
    return $id;
}

sub gene_text_label {
    my ($self, $gene) = @_;
    my $id = $gene->external_name() || $gene->stable_id();
    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');
    unless( $short_labels ){
        my $type = $self->format_vega_name($gene);
        $id .= " \n$type ";
    }
    return $id;
}

sub legend {
    my ($self, $colours) = @_;
	my $labels;
	if (%VEGA_TO_SHOW_ON_VEGA) {
		foreach my $k (keys %VEGA_TO_SHOW_ON_VEGA) {
			if (@{$colours->{$k}}) {
				push @$labels,$colours->{$k}[1]; 
				push @$labels,$colours->{$k}[0]; 
			} else {
				warn "WARNING - no colour map entry for $k";
			}
		}
		return ('genes',1000,$labels);
	} else {
		warn "WARNING - using default colour map";
		return ('genes',1000,
				['Known Protein coding'           => $colours->{'protein_coding_KNOWN'}[0],
				 'Novel Protein coding'           => $colours->{'protein_coding_NOVEL'}[0],
				 'Novel Processed transcript'     => $colours->{'processed_transcript_NOVEL'}[0],
				 'Putative Processed transcript'  => $colours->{'processed_transcript_PUTATIVE'}[0],
				 'Novel Pseudogene'               => $colours->{'pseudogene_NOVEL'}[0],
				 'Novel Processed pseudogenes'    => $colours->{'processed_pseudogene_NOVEL'}[0],
				 'Novel Unprocessed pseudogenes'  => $colours->{'unprocessed_pseudogene_NOVEL'}[0],
				 'Predicted Protein coding'       => $colours->{'protein_coding_PREDICTED'}[0],
				 'Novel Ig segment'               => $colours->{'Ig_segment_NOVEL'}[0],
				 'Novel Ig pseudogene'            => $colours->{'Ig_pseudogene_segment_NOVEL'}[0],
				]
			   );
	}
}


sub error_track_name { 
    my $self = shift;
    return $self->my_config('track_label');
}

1;


