package Bio::EnsEMBL::GlyphSet::transcript_lite;
use strict;
use vars qw(@ISA);
use EnsWeb;
use Bio::EnsEMBL::GlyphSet_transcript;
use Bio::EnsEMBL::Utils::Eprof qw(eprof_start eprof_end eprof_dump);

@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub my_label {
    my $self = shift;
    return $self->{'config'}->{'_draw_single_Transcript'} || $self->{'config'}->{'geneid'} || "@{[EnsWeb::species_defs->AUTHORITY]} trans.";
}

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    return $Config->get('transcript_lite','colours');
}

sub features {
  my ($self) = @_;

  return [
   @{$self->{'container'}->get_all_Genes(lc(EnsWeb::species_defs->AUTHORITY))},
   @{$self->{'container'}->get_all_Genes('pseudogene')}
  ];
}


sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    my $translation = $transcript->translation;
    my $translation_id = $translation ? $translation->stable_id : '';

    my $genecol = $colours->{ "_".$transcript->external_status };

    if( $transcript->external_status eq '' and ! $translation_id ) {
       $genecol = $colours->{'_PSEUDO'};
    }
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
    my ($self, $gene, $transcript, %highlights ) = @_;

    my $gid = $gene->stable_id();
    my $tid = $transcript->stable_id();
    
    my $script_name = $ENV{'ENSEMBL_SCRIPT'} eq 'genesnpview' ? 'genesnpview' : 'geneview';
    return ( $self->{'config'}->get('transcript_lite','_href_only') eq '#tid' && exists $highlights{$gene->stable_id()} ) ?
        "#$tid" : 
        qq(/@{[$self->{container}{_config_file_name_}]}/$script_name?gene=$gid);

}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $translation = $transcript->translation;
    my $tid = $transcript->stable_id();
    my $pid = $translation ? $translation->stable_id() : '';
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
    my $zmenu = {
        'caption'                       => EnsWeb::species_defs->AUTHORITY." Gene",
        "00:$id"			=> "",
	"01:Gene:$gid"                  => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid&db=core",
        "02:Transcr:$tid"    	        => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid&db=core",                	
        '04:Export cDNA'                => "/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
        
    };
    
    if($pid) {
    $zmenu->{"03:Peptide:$pid"}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid&db=core);
    $zmenu->{'05:Export Peptide'}=
    	qq(/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid);	
    }
    $zmenu->{'05:Gene SNP view'}= "/@{[$self->{container}{_config_file_name_}]}/genesnpview?gene=$gid&db=core" if $ENV{'ENSEMBL_SCRIPT'} =~ /snpview/;
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $eid = $transcript->external_name();

    my $id = $eid || $tid;

    my $Config = $self->{config};
    my $short_labels = $Config->get('_settings','opt_shortlabels');

    if( $self->{'config'}->{'_both_names_'} eq 'yes') {
        $id .= $eid ? " ($eid)" : '';
    }
    unless( $short_labels ){
      $id .= $transcript->external_status eq  'PSEUDO' ? 
            "\nEnsembl pseudogene" :
            ( $eid ? "\nEnsembl known trans" : "\nEnsembl novel trans" );
    }
    return $id;
    #$self->{'config'}->{'_transcript_names_'} eq 'yes' ? IGNORED
}

sub legend {
    my ($self, $colours) = @_;
    return ('genes', 900, 
        [
            EnsWeb::species_defs->AUTHORITY.' predicted genes (known)' => $colours->{'_KNOWN'},
            EnsWeb::species_defs->AUTHORITY.' predicted genes (novel)' => $colours->{'_'},
            EnsWeb::species_defs->AUTHORITY.' pseudogenes' => $colours->{'_PSEUDO'},
        ]
    );
}

sub error_track_name { return EnsWeb::species_defs->AUTHORITY.' transcripts'; }

1;
