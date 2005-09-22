package Bio::EnsEMBL::GlyphSet::vega_transcript;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet::evega_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet::evega_transcript);

sub features {
    my ($self) = @_;
    my $author = $self->my_config('author');
	my $gene_adaptor = $self->{'container'}->adaptor->db->get_db_adaptor('vega')->get_GeneAdaptor;
    my $genes = [];
    if ($author) {
        # if author is defined in UserConfig, fetch only transcripts by this
        # author
        # check data availability first
        
        my $chr = $self->{'container'}->seq_region_name;
        my $avail = (split(/ /, $self->my_config('available')))[1]
                    . "." . $self->{'container'}->seq_region_name;
        return ([]) unless($self->species_defs->get_config(
                    $self->{'container'}{'_config_file_name_'}, 'DB_FEATURES')->{uc($avail)});
        
        $genes = $gene_adaptor->fetch_all_by_Slice_and_author($self->{'container'}, $author, 'otter');
    } else {
        # else fetch all otter transcripts
        $genes = $self->{'container'}->get_all_Genes('otter');
    }

    # determine transcript type
    # $gene_adaptor->set_transcript_type($genes);

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
    my $translation = $transcript->translation;
    my $pid = $translation->stable_id() if $translation;
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
	my $type = $self->format_obj_type($gene,$transcript);
    my $zmenu = {
        'caption' 	    => $self->my_config('zmenu_caption'),
        "00:$id"	    => "",
        '01:Type: '.$type => "",
    	"02:Gene:$gid"   => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core",
        "03:Transcr:$tid"=> "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid;db=core",
        "04:Exon:$tid"	 => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid;db=core",
        '05:Supporting evidence'    => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid;db=core#evidence",
        '08:Export cDNA'  => "/@{[$self->{container}{_config_file_name_}]}/exportview?option=cdna;action=select;format=fasta;type1=transcript;anchor1=$tid",
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
	my $type = $self->format_obj_type($gene);
    my $zmenu = {
        'caption' 	    => $self->my_config('zmenu_caption'),
        "00:$id"	    => "",
        '01:Type: ' . $type => "",
        "02:Gene:$gid"  => qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid;db=core),
    };
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->external_name() || $transcript->stable_id();
    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');
    unless( $short_labels ){
        my $type = $self->format_obj_type($gene,$transcript);
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
        my $type = $self->format_obj_type($gene);
        $id .= " \n$type ";
    }
    return $id;
}

sub legend {
    my ($self, $colours) = @_;
	# species defs doesn't hold details of gene types any more, so do it manually
	return ('genes', 1000,
		[
        'Known Protein coding'           => $colours->{'protein_coding_KNOWN'}[0],
        'Novel Protein coding'           => $colours->{'protein_coding_NOVEL'}[0],
        'Novel Processed transcript'     => $colours->{'processed_transcript_NOVEL'}[0],
        'Putative Processed transcript'  => $colours->{'processed_transcript_PUTATIVE'}[0],
        'Novel Pseudogene'               => $colours->{'pseudogene_NOVEL'}[0],
        'Novel Processed pseudogenes'    => $colours->{'processed_pseudogene_NOVEL'}[0],
        'Novel Unprocessed pseudogenes'  => $colours->{'unprocessed_pseudogene_NOVEL'}[0],
        'Predicted Protein coding'       => $colours->{'protein_coding_PREDICTED'}[0],
        'Novel Immunoglobulin segment'   => $colours->{'Ig_segment_NOVEL'}[0],
        'Novel Immunoglobulin pseudogene'=> $colours->{'Ig_pseudogene_segment_NOVEL'}[0],
		]
	  );
}


sub error_track_name { return 'Vega transcripts'; }


=head2 format_obj_type

  Arg [1]    : $self
  Arg [2]    : gene object
  Arg [3]    : transcript object (optional)
  Example    : my $type = $self->format_obj_type($g,$t);
  Description: retrieves status and biotype of a transcript, or failing that the parent gene, and formats it for display using the Colourmap
  Returntype : string

=cut

sub format_obj_type {
	my ($self,$gene,$trans) = @_;
	my ($status,$biotype);
	my %gm = $self->{'config'}->colourmap()->colourSet('vega_gene');
	if ($trans) {
		$status = $trans->confidence()||$gene->confidence;
		$biotype = $trans->biotype()||$gene->biotype();
	} else {
		$status = $gene->confidence;
		$biotype = $gene->biotype();
	}
	my $t = $biotype.'_'.$status;
	my $label = $gm{$t}[1];
	return $label;
}

1;


