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
        'unknown'   => $Config->get('genewise_lite','unknown'),
        'known'     => $Config->get('genewise_lite','known'),
        'pseudo'    => $Config->get('genewise_lite','pseudo'),
        'ext'       => $Config->get('genewise_lite','ext'),
        'hi'        => $Config->get('genewise_lite','hi'),
        'superhi'   => $Config->get('genewise_lite','superhi')
    };
}

sub transcript_type {
  my $self = shift;

  return 'genewise';
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    return ( 
      $colours->{$transcript->type()},
      exists $highlights{$transcript->stable_id()} ? $colours->{'superhi'} : 
     (exists $highlights{$transcript->external_name()} ? $colours->{'superhi'} :
     (exists $highlights{$gene->stable_id()} ? $colours->{'hi'} : undef ))
    );
}

sub href {
    my ($self, $gene, $transcript) = @_;
    return $self->{'config'}->{'_href_only'} eq '#tid' ?
        "#$transcript->stable_id()" :
        qq(/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gene->stable_id());

}

sub features {
  my ($self) = @_;
  return $self->{'container'}->get_all_Genes_by_type('similarity_genewise');
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $vtid = $transcript->stable_id();
    my $id   = $transcript->external_name() eq '' 
      ? $vtid : $transcript->external_name();
    my $zmenu = {
        'caption'                       => $id,
        "00:Transcr:$vtid"              => "",
        "01:(Gene:$gene->stable_id())"  => "",
        '03:Transcript information'     => "/$ENV{'ENSEMBL_SPECIES'}/geneview?gene=$gene->stable_id()",
        '04:Protein information'        => "/$ENV{'ENSEMBL_SPECIES'}/protview?peptide=" . $transcript->translation->stable_id(),
        '05:Supporting evidence'        => "/$ENV{'ENSEMBL_SPECIES'}/transview?transcript=$vtid",
        '07:Protein sequence (FASTA)'   => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=peptide&id=$vtid",
        '08:cDNA sequence'              => "/$ENV{'ENSEMBL_SPECIES'}/exportview?tab=fasta&type=feature&ftype=cdna&id=$vtid",
    };
    my $DB = EnsWeb::species_defs->databases;
    if($DB->{'ENSEMBL_EXPRESSION'}) {
      $zmenu->{'06:Expression information'}
        = "/$ENV{'ENSEMBL_SPECIES'}/sageview?alias=$gene->stable_id()";
    }
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $id = ($transcript->external_name() eq '') ? 
      $tid : $transcript->external_name();
    return ($self->{'config'}->{'_transcript_names_'} eq 'yes') ?
      (($transcript->type() eq 'unknown') ? 'NOVEL' : $id) : $tid;    
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

sub error_track_name { return 'EnsEMBL genewises'; }

1;
