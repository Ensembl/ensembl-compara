package Bio::EnsEMBL::GlyphSet_transcript_vega;
use strict;
use vars qw(@ISA);
use Bio::EnsEMBL::GlyphSet_transcript;
@ISA = qw(Bio::EnsEMBL::GlyphSet_transcript);

sub colours {
    my $self = shift;
    my $Config = $self->{'config'};
    my $feature_name = $self->check();
    return $Config->get($feature_name, 'colours');
}

sub colour {
    my ($self, $gene, $transcript, $colours, %highlights) = @_;
    my $genecol = $colours->{$gene->type()};
    if(exists $highlights{$transcript->stable_id()}) {
        return ($genecol, $colours->{'superhi'});
    } elsif (exists $highlights{$transcript->external_name()}) {
        return ($genecol, $colours->{'superhi'});
    } elsif (exists $highlights{$gene->stable_id()}) {
        return ($genecol, $colours->{'hi'});
    }
    return ($genecol, undef);
}

sub features {
    my ($self) = @_;
    my ($genes, @genes);
    my @logic_names = $self->logic_name();
    foreach my $ln (@logic_names) {
        $genes =  $self->{'container'}->get_all_Genes($ln);
        push @genes, @$genes;
    }
    return \@genes;
}

sub href {
    my ($self, $gene, $transcript ) = @_;
    my $gid = $gene->stable_id();
    my $tid = $transcript->stable_id();
    return $self->{'config'}->{'_href_only'} eq '#tid' ?
        "#$tid" : 
        qq(/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid);
}

sub zmenu {
    my ($self, $gene, $transcript) = @_;
    my $tid = $transcript->stable_id();
    my $pid = $transcript->translation->stable_id() ,
    my $gid = $gene->stable_id();
    my $id   = $transcript->external_name() eq '' ? $tid : ( $transcript->external_db.": ".$transcript->external_name() );
    my $zmenu = {
        'caption' 	    => $self->zmenu_caption(),
        "00:$id"	    => "",
        '01:Type: ' . $gene->type() => "",
	"02:Gene:$gid"      => "/@{[$self->{container}{_config_file_name_}]}/geneview?gene=$gid&db=core",
        "03:Transcr:$tid"   => "/@{[$self->{container}{_config_file_name_}]}/transview?transcript=$tid&db=core",                	
        "04:Exon:$tid"	    => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid&db=core",
        '05:Supporting evidence'    => "/@{[$self->{container}{_config_file_name_}]}/exonview?transcript=$tid&db=core#evidence",

        '08:Export cDNA'  => "/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=cdna&id=$tid",
    };
    my $DB = EnsWeb::species_defs->databases;
    $zmenu->{'07:Expression information'} = "/@{[$self->{container}{_config_file_name_}]}/sageview?alias=$gid" if $DB->{'ENSEMBL_EXPRESSION'}; 

    if ($pid) {
        $zmenu->{"06:Peptide:$pid"} =  "/@{[$self->{container}{_config_file_name_}]}/protview?peptide=$pid";
        $zmenu->{'09:Export Peptide'}	= "/@{[$self->{container}{_config_file_name_}]}/exportview?tab=fasta&type=feature&ftype=peptide&id=$pid";
    }
    return $zmenu;
}

sub text_label {
    my ($self, $gene, $transcript) = @_;
    my $id = $transcript->external_name() || $transcript->stable_id();
    return $id;
}

sub legend {
    my ($self, $colours) = @_;
    my $gene_type_names = { 
        'Novel_CDS'        => 'Curated novel CDS',
        'Putative'         => 'Curated putative',
        'Known'            => 'Curated known genes',
        'Novel_Transcript' => 'Curated novel Trans',
        'Pseudogene'       => 'Curated pseudogenes',
        'Processed_pseudogene'       => 'Curated processed pseudogenes',
        'Unprocessed_pseudogene'       => 'Curated unprocessed pseudogenes',
        'Ig_Segment'       => 'Curated Ig Segment',
        'Ig_Pseudogene_Segment'   => 'Curated Ig Pseudogene',
        'Predicted_Gene'   => 'Curated predicted',
        'Transposon'	      => 'Curated Transposon',
        'Polymorphic'      => 'Curated Polymorphic',
    }; 
    my @legend = ('genes', 1000, []);
    foreach my $gene_type (sort keys %{ EnsWeb::species_defs->VEGA_GENE_TYPES || {}} ) {
        push(@{@legend[2]}, "$gene_type_names->{$gene_type}" => $colours->{$gene_type} );
    }
    return @legend;
}

sub error_track_name { return 'transcripts'; }

1;

