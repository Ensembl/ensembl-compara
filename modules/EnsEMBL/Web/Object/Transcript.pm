package EnsEMBL::Web::Object::Transcript;

use strict;
use warnings;
no warnings "uninitialized";
use Bio::EnsEMBL::Utils::TranscriptAlleles;
use EnsEMBL::Web::Object;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::ExtIndex;
use POSIX qw(floor ceil);
use Data::Dumper;
our @ISA = qw(EnsEMBL::Web::Object);

sub default_track_by_gene {
  my $self = shift;
  my $db    = $self->get_db;
  my $logic = $self->logic_name;

  my %mappings_db = qw(
    vega evega_transcript
    est est_transcript
  );
  my %mappings_logic_name = qw(
    genscan          genscan
    fgenesh          fgenesh
    genefinder       genefinder
    snap             snap
    gsc              gsc
    gid              gid
    slam             slam
    gws_h            gws_h
    gws_s            gws_s
    genebuilderbeeflymosandswall genebuilderbeeflymosandswall_transcript
    gsten            gsten_transcript
    hox              gsten_transcript
    cyt              gsten_transcript
    flybase          flybase_transcript
    wormbase         wormbase_transcript
    ensembl          ensembl_transcript
    ncrna            rna_transcript
    ensembl_ncrna    erna_transcript
    sgd              sgd_transcript
    homology_low     homology_low_transcript
    homology_medium  homology_low_transcript
    homology_high    homology_low_transcript
    beeprotein       homology_low_transcript
    cow_proteins     cow_proteins_transcript
    otter            vega_transcript						   
  );
  return $mappings_db{ lc( $db ) } ||
         $mappings_logic_name{ lc( $logic ) } || 'ensembl_transcript';
}

sub type_name         { my $self = shift; return $self->species_defs->translate('Transcript'); }
sub source            { my $self = shift; return $self->gene ? $self->gene->source : undef; }
sub stable_id         { my $self = shift; return $self->Obj->stable_id;  }
sub feature_type      { my $self = shift; return $self->Obj->type;       }
sub version           { my $self = shift; return $self->Obj->version;    }
sub logic_name        { my $self = shift; return $self->gene ? $self->gene->analysis->logic_name : $self->Obj->analysis->logic_name; }
sub coord_system      { my $self = shift; return $self->Obj->slice->coord_system->name; }
sub seq_region_type   { my $self = shift; return $self->coord_system; }
sub seq_region_name   { my $self = shift; return $self->Obj->slice->seq_region_name; }
sub seq_region_start  { my $self = shift; return $self->Obj->start; }
sub seq_region_end    { my $self = shift; return $self->Obj->end; }
sub seq_region_strand { my $self = shift; return $self->Obj->strand; }

sub gene_description {
  my $self = shift;
  my %description_by_type = ( 'bacterial_contaminant' => "Probable bacterial contaminant" );
  if( $self->gene ) {
    return $self->gene->description() || $description_by_type{ $self->gene->biotype } || 'No description';
  } else {
    return 'No description';
  }
}


sub get_alternative_locations {
  my $self = shift;
  my @alt_locs = map { [ $_->slice->seq_region_name, $_->start, $_->end, $_->slice->coord_system->name, ] }
                 @{$self->Obj->get_all_alt_locations};
  return \@alt_locs;
}

sub get_Slice {
  my( $self, $context, $ori ) = @_;

  my $db  = $self->get_db ;
  my $gene = $self->gene;   ### should this be called on gene?
  my $slice = $gene->feature_Slice;
  if( $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert();
  }
  return $slice->expand( $context, $context );
}

#-- Transcript strain view -----------------------------------------------

sub get_transcript_Slice {
  my( $self, $context, $ori ) = @_;

  my $db  = $self->get_db ;
  my $slice = $self->Obj->feature_Slice;
  if( $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert();
  }
  return $slice->expand( $context, $context );
}


# Copied from EnsEMBL/Web/Object/Gene.pm for Transcript Strain View

=head2 transcript

 Args        : Web user config, arrayref of slices (see example)
 Example     : my $slice = $object->get_Slice(
		  $wuc,  [ 'context',      'normal', '500%'  ],
				 );
 Description : Gets slices for transcript strain view
 Return type : hash ref of slices

=cut

sub get_transcript_slices {
  my( $self, $master_config, $slice_config ) = @_;
  if( $slice_config->[1] eq 'normal') {
    my $slice= $self->get_transcript_Slice( $slice_config->[2], 1 );
    return [ 'normal', $slice, [], $slice->length ];
  }
  else {
    return $self->get_munged_slice( $master_config, $slice_config->[2], 1 );
  }
}


sub get_munged_slice {
  my $self = shift;
  my $master_config = shift;
  my $slice = $self->get_transcript_Slice( @_ );
  my $length = $slice->length();
  my $munged  = '0' x $length;  # Munged is string of 0, length of slice

  # Context is the padding around the exons in the fake slice
  my $extent = $self->param( 'context' );

  my @lengths;
  if( $extent eq 'FULL' ) {
    $extent = 1000;
    @lengths = ( $length );
  }
  else {
    foreach my $exon (@{$self->Obj->get_all_Exons()}) {
      my $START    = $exon->start - $slice->start + 1 - $extent;
      my $EXON_LEN = $exon->end-$exon->start + 1 + 2 * $extent;

      # Change munged to 1 where there is exon or extent (i.e. flank)
      substr( $munged, $START-1, $EXON_LEN ) = '1' x $EXON_LEN;
    }
    @lengths = map { length($_) } split /(0+)/, $munged;
  }
  ## @lengths contains the sizes of gaps and exons(+- context)

  $munged = undef;

  my $collapsed_length = 0;
  my $flag = 0;
  my $subslices = [];
  my $pos = 0;
  foreach( @lengths , 0) {
    if ( $flag = 1-$flag ) {
      push @$subslices, [ $pos+1, 0, 0 ] ;
      $collapsed_length += $_;
    } else {
      $subslices->[-1][1] = $pos;
    }
    $pos+=$_;
  }

## compute the width of the slice image within the display
  my $PIXEL_WIDTH =
    $self->param('image_width') -
        ( $master_config->get( '_settings', 'label_width' ) || 100 ) -
    3 * ( $master_config->get( '_settings', 'margin' )      ||   5 );

## Work out the best size for the gaps between the "exons"
  my $fake_intron_gap_size = 11;
  my $intron_gaps  = ((@lengths-1)/2);
  if( $intron_gaps * $fake_intron_gap_size > $PIXEL_WIDTH * 0.75 ) {
     $fake_intron_gap_size = int( $PIXEL_WIDTH * 0.75 / $intron_gaps );
  }
## Compute how big this is in base-pairs
  my $exon_pixels  = $PIXEL_WIDTH - $intron_gaps * $fake_intron_gap_size;
  my $scale_factor = $collapsed_length / $exon_pixels;
  my $padding      = int($scale_factor * $fake_intron_gap_size) + 1;
  $collapsed_length += $padding * $intron_gaps;

## Compute offset for each subslice
  my $start = 0;
  foreach(@$subslices) {
    $_->[2] = $start - $_->[0];
    $start += $_->[1]-$_->[0]-1 + $padding;
  }

  return [ 'munged', $slice, $subslices, $collapsed_length+2*$extent ];

}


sub getVariationsOnSlice {
  my( $self, $key, $valids, $slice ) = @_;

  my %ct = %Bio::EnsEMBL::Variation::VariationFeature::CONSEQUENCE_TYPES;
  my @snps =
# [fake_s, fake_e, SNP]              Remove the schwartzian index
    map  { $_->[1] }
# [ index, [fake_s, fake_e, SNP] ]   Sort snps on schwartzian index
    sort { $a->[0] <=> $b->[0] }
# [ index, [fake_s, fake_e, SNP] ]   Compute schwartzian index [ consequence type priority, fake SNP ]
    map  { [ $_->[1] - $ct{$_->[2]->get_consequence_type()} *1e9, $_ ] }
# [ fake_s, fake_e, SNP ]   Grep features to see if the area valid
    grep { ( @{$_->[2]->get_all_validation_states()} ?
           (grep { $valids->{"opt_$_"} } @{$_->[2]->get_all_validation_states()} ) :
           $valids->{'opt_noinfo'} ) }
# [ fake_s, fake_e, SNP ]   Filter our unwanted consequence classifications
    grep { $valids->{'opt_'.lc($_->[2]->get_consequence_type()) } }
# [ fake_s, fake_e, SNP ]   Filter our unwanted classes
    grep { $valids->{'opt_'.$_->[2]->var_class} }
# [ fake_s, fake_e, SNP ]   Filter out any SNPs not on munged slice...
    map  { $_->[1]?[$_->[0]->start+$_->[1],$_->[0]->end+$_->[1],$_->[0]]:() } # Filter out anything that misses
# [ SNP, offset ]           Create a munged version of the SNPS
    map  { [$_, $self->munge_gaps( $key, $_->start, $_->end)] }    # Map to "fake coordinates"
# [ SNP ]                   Filter out all the multiply hitting SNPs
    grep { $_->map_weight < 4 }
# [ SNP ]                   Get all features on slice
    @{ $slice->get_all_VariationFeatures() };
  return \@snps;
}



sub getAllelesOnSlice {
  my( $self, $key, $valids, $strain_slice ) = @_;

  # Get all features on slice
  my $allele_features = $strain_slice->get_all_differences_Slice();
  return [] unless ref $allele_features eq 'ARRAY'; 

  my @genomic_af =
  # Rm many filters as not applicable to Allele Features
  # [ fake_s, fake_e, AlleleFeature ]   Filter out AFs not on munged slice...
    map  { $_->[1]?[$_->[0]->start+$_->[1],$_->[0]->end+$_->[1],$_->[0]]:() } 
     # [ AF, offset ]   Map to fake coords.   Create a munged version AF
      map  { [$_, $self->munge_gaps( $key, $_->start, $_->end)] }
	@$allele_features;
  return \@genomic_af ;
}

sub transcript_alleles {
  my ($self, $valids, $allele_info ) = @_;
  return [] unless @$allele_info;

  # consequences of AlleleFeatures on the transcript
  my @slice_alleles = map { $_->[2]->transfer($self->Obj->slice) } @$allele_info;

  my $consequences =  Bio::EnsEMBL::Utils::TranscriptAlleles::get_all_ConsequenceType($self->Obj, \@slice_alleles);
  return [] unless @$consequences;

  my @valid_conseq;
  foreach ( @$consequences ){  # conseq on our transcript
    push @valid_conseq, $_ if $valids->{'opt_'.lc($_->type)} ;
  }
  return  \@valid_conseq;
}

sub transcript_SNPS_old {
  my ($self, $valids, $slice ) = @_;

  my $our_transcript = $self->stable_id;
  my $transcript_snps = {};

  #slice_snps have vf on strain slice for all transcripts. Grep for ones on our transcript
  my $slice_snps = $self->getAllelesOnSlice("straintranscripts", $valids, $slice);
  foreach my $snp ( @$slice_snps ) {
    foreach( @{$snp->[2]->get_all_TranscriptVariations ||[]} ) {
      next unless $our_transcript eq $_->transcript->stable_id;
      $transcript_snps->{ $snp->[2]->dbID } = [$_ , $snp ] if $valids->{'opt_'.lc($_->consequence_type)};
    }
  }
  return $transcript_snps;
}


sub munge_gaps {
  my( $self, $slice_code, $bp, $bp2  ) = @_;
  my $subslices = $self->__data->{'slices'}{ $slice_code }[2];
   # warn "bp 2 $bp2, bp $bp";
  foreach( @$subslices ) {

    if( $bp >= $_->[0] && $bp <= $_->[1] ) {
      my $return =  defined($bp2) && ($bp2 < $_->[0] || $bp2 > $_->[1] ) ? undef : $_->[2] ;
   #   warn $return;
      return $return;
    }
  }
  return undef;
}


#-- end transcript strain view ----------------------------------------------


=head2 transcript

 Arg[1]        : none
 Example     : my $ensembl_transcript = $transdata->transcript
 Description : Gets the ensembl transcript stored on the transcript data object
 Return type : Bio::EnsEmbl::Transcript

=cut

sub transcript { return $_[0]->Obj; }

=head2 gene

 Arg[1]      : Bio::EnsEMBL::Gene - (OPTIONAL)
 Example     : $ensembl_gene = $transdata->gene
               $transdata->gene( $ensembl_gene )
 Description : returns the ensembl gene object if it exists on the transcript object
                else it creates it from the core-api. Alternativly a ensembl gene object
                reference can be passed to the function if the transcript is being created
                via a gene and so saves on creating a new gene object.
 Return type : Bio::EnsEMBL::Gene

=cut

sub gene{
  my $self = shift ;
  if(@_) {
    $self->{'_gene'} = shift;
  } elsif( !$self->{'_gene'} ) {
    eval {
      my $db = $self->get_db() ;
      my $adaptor_call = $self->param('gene_adaptor') || 'get_GeneAdaptor';
      my $GeneAdaptor = $self->database($db)->$adaptor_call;
      my $Gene = $GeneAdaptor->fetch_by_transcript_stable_id($self->stable_id);   
      $self->{'_gene'} = $Gene if ($Gene);
    };
  }
  return $self->{'_gene'};
}

=head2 translation_object

 Arg[1]      : none
 Example     : $ensembl_translation = $transdata->translation
 Description : returns the ensembl translation object if it exists on the transcript object
                else it creates it from the core-api.
 Return type : Bio::EnsEMBL::Translation

=cut

sub translation_object {
  my $self = shift;
  unless( exists( $self->{'data'}{'_translation'} ) ){
    my $translation = $self->transcript->translation;
    if( $translation ) {
      my $translationObj = EnsEMBL::Web::Proxy::Object->new(
        'Translation', $translation, $self->__data
      );
      $translationObj->gene($self->gene);
      $translationObj->transcript($self->transcript);
      $self->{'data'}{'_translation'} = $translationObj;
    } else {
      $self->{'data'}{'_translation'} = undef;
    }
  }
  return $self->{'data'}{'_translation'};
}

=head2 get_db

 Arg[1]      : none
 Example     : $db = $transdata->get_db
 Description : Gets the database name used to create the object
 Return type : string
                a database type (core, est, snp, etc.)

=cut

# need call in API
sub get_db {
  my $self = shift;
  my $db = $self->param('db') || 'core';
  return $db eq 'estgene' ? 'est' : $db;
}

=head2 db_type

 Arg[1]      : none
 Example     : $type = $transdata->db_type
 Description : Gets the db type of ensembl feature
 Return type : string
                a db type (EnsEMBL, Vega, EST, etc.)

=cut

sub db_type{
  my $self = shift;
  my $db   = $self->get_db;
  my %db_hash = qw(
    core    Ensembl
    est     EST
    estgene EST
    vega    Vega
  );
  return  $db_hash{$db};
}


#----------------------------------------------------------------------

=head2 gene_type

  Arg [1]   : 
  Function  : Pretty-print type of gene; Ensembl, Vega, Pseudogene etc
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub gene_type {
  my $self = shift;
  my $db = $self->get_db;
  my $type = '';
  if( $db eq 'core' ){
    $type = $self->logic_name;
    $type ||= $self->db_type;
  } else {
    $type = $self->db_type;
    $type ||= $self->logic_name;
  }
  $type ||= $db;
  if( $type !~ /[A-Z]/ ){ $type = ucfirst($type) } #All lc, so format
  return $type;
}

#----------------------------------------------------------------------

=head2 analysis

  Arg [1]   : 
  Function  : Returns the analysis object from either the gene or transcript
  Returntype: 
  Exceptions: 
  Caller    : 
  Example   : 

=cut

sub analysis {
  my $self = shift;
  if( $self->gene ){ return $self->gene->analysis  } # for "real" gene objects
  else { return $self->transcript->analysis } # for things like genscans
}



=head2 get_transcript_class

 Arg[1]       : none
 Example     : $version = $transcriptdata->get_transcript_class
 Description : returns the transcript class
 Return type : string
                The transcript class
=cut

sub get_transcript_class { return $_[0]->transcript->transcript_info->class->name; }

=head2 modified

 Description: DEPRECATED - Genes no longer have a modified attribute

=cut

sub modified {
  warn "DEPRECATED - Genes no longer have a modified attribute";
  return undef;
}

=head2 get_author_name

 Arg[1]      : none
 Example     : $author = $transcriptdata->get_author_name
 Description : Gets the author of an annotated gene
 Return type : String
               The author name

=cut

sub get_author_name { return $_[0]->gene->gene_info->author->name; }

=head2 get_author_email

 Arg[1]      : String
               Email address
 Example     : $email = $transcriptdata->get_author_email
 Description : Gets the author's email address of an annotated gene
 Return type : String
               The author's email address

=cut

sub get_author_email { return $_[0]->gene->gene_info->author->email; }

=head2 get_remarks

  Arg[1]      : none
  Example     : $remark_ref = $transcriptdata->get_remarks
  Description : Gets annotation remarks of an annotated gene
  Return type : Arrayref
                A reference to a list of remarks

=cut

sub get_remarks { return [map { $_->remark } $_[0]->transcript->transcript_info->remark]; }

=head2 trans_description

 Arg[1]      : none
 Example     : $description = $transdata->trans_description
 Description : Gets the description from the GENE object (no description on transcript)
 Return type : string
                The description of a feature

=cut

sub trans_description {
  my $gene = $_[0]->gene;
  my %description_by_type = ( 'bacterial_contaminant' => "Probable bacterial contaminant" );
  if( $gene ){
    return $gene->description() || $description_by_type{ $gene->biotype } || 'No description';
  }
  return 'No description';
}

=head2 get_prediction_method

 Arg[1]      : none
 Example     : $prediction_method = $transdata->get_prediction_method
 Description : Gets the prediction method for a transcript
 Return type : string The prediction method of a feature

=cut

sub get_prediction_method {
  my $self = shift ;
  my $db = $self->get_db() ;
  my $logic_name = $self->logic_name || '';

  my $prediction_text;
  if( $logic_name ){
    my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($logic_name);
    $prediction_text = $self->species_defs->$confkey;
  }
  unless( $prediction_text ) {
    my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
    $prediction_text   = $self->species_defs->$confkey;
  }
  return($prediction_text);
}

=head2 display_xref

 Arg[1]      : none
 Example     : ($xref_display_id, $xref_dbname) = $transdata->display_xref
 Description : returns a pair value of xref display_id and xref dbname  (BRCA1, HUGO)
 Return type : a list

=cut

sub display_xref{
  my $trans_xref = $_[0]->transcript->display_xref();    
  return ( $trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $trans_xref->db_display_name ) if $trans_xref;    
}

=head2 get_contig_location

 Arg[1]      : none
 Example     : ($chr, $start, $end, $contig, $contig_start) = $transdata->get_genomic_location
 Description : returns the location of a transcript. Returns a list
                chromosome, chr_start, chr_end, contig, contig_start
 Return type : a list

=cut

sub get_contig_location {
  my $self = shift;
  my ($pr_seg) = @{$self->Obj->project('seqlevel')};
  return undef unless $pr_seg;
  return (
    $self->neat_sr_name( $pr_seg->[2]->coord_system->name, $pr_seg->[2]->seq_region_name ),
    $pr_seg->[2]->seq_region_name,
    $pr_seg->[2]->start
  );
}

=head2 get_trans_seq

 Arg[1]      : none
 Example     : $trans_seq = $transdata->get_trans_seq
 Description : returns a plain transcript sequence, if option numbers = on then
                bp numbers are also added
 Return type : a string
                transcript sequence

=cut

sub get_trans_seq{
  my $self   = shift;
  my $trans  = $self->Obj;
  my $number = $self->param('number');   
  my $flip = 0;
  my $wrap = 60;
  my $pos = 1-$wrap; 
  my $fasta;  
  my @exons = @{$trans->get_all_Exons};
  foreach my $t (@exons){
    my $subseq = uc($t->seq->seq);
       $subseq = lc($subseq) if ($flip++)%2;
       $fasta.=$subseq;
  }
  if($number eq 'on') {
    $fasta =~ s|(\w{1,$wrap})|sprintf( "%6d %s\n",$pos+=$wrap,"$1")|eg;    
  } else {
    $fasta =~ s|(\w{1,$wrap})|$1\n|g;    
  }
  return $fasta;
}

=head2 get_markedup_trans_seq

 Arg[1]      : none
 Example     : $trans_seq = $transdata->get_markedup_trans_seq
 Description : returns the the transcript sequence along with positions for markup
 Return type : list of coding_start, coding_end, trans_strand, array ref of positions

=cut

sub get_markedup_trans_seq {
  my $self   = shift;
  my $trans  = $self->Obj;
  my $number = $self->param('number');
  my $show   = $self->param('show');
  my $flip   = 1;

  my @exons = @{$trans->get_all_Exons};
  my $trans_strand = $exons[0]->strand;
  my @exon_colours = qw(black blue);
  my @bps = map { $flip = 1-$flip; map {{
    'peptide'   => '.',
    'ambigcode' => ' ',
    'snp'       => '',
    'alleles'   => '',
    'aminoacids'=> '',
    'letter'    => $_,
    'fg'        => $exon_colours[$flip],
    'bg'        => 'utr'
    }} split //, uc($_->seq->seq)
  } @exons;

  my $cd_start = $trans->cdna_coding_start;
  my $cd_end   = $trans->cdna_coding_end;
  my $peptide;
  my $can_translate = 0;
  my $pep_obj = '';
  eval {
    my $pep_obj = $trans->translate;
    $peptide = $pep_obj->seq();
    $can_translate = 1;
    $flip = 0;
    my $startphase = $trans->translation->start_Exon->phase;
    
    for my $i ( ($cd_start-1)..($cd_end-1) ) {
      $bps[$i]{'bg'} = "c99";
    }
    my $S = 0;
    if( $startphase > 0 ) {
      $S = 3 - $startphase;
      $peptide = substr($peptide,1);
    }
    for( my $i= $cd_start + $S - 1; ($i+2)<= $cd_end; $i+=3) {
      $bps[$i]{'bg'}=$bps[$i+1]{'bg'}=$bps[$i+2]{'bg'} = "c$flip";
      $bps[$i]{'peptide'}=$bps[$i+2]{'peptide'}='-';    # puts dash a beginging AND end of codon
      $bps[$i+1]{'peptide'}=substr($peptide,int( ($i+1-$cd_start)/3 ), 1 ) || '*';
      $flip = 1-$flip;
    }
    $peptide = '';
  };

  if($show eq 'snps') {
    $self->database('variation');
    my $source = "";
    if (exists($self->species_defs->databases->{'ENSEMBL_GLOVAR'})) {
      $source = "glovar";
      $self->database('glovar');
    }
    $source = 'variation' if $self->database('variation');
    my %snps = %{$trans->get_all_cdna_SNPs($source)};
    my %protein_features = $can_translate==0 ? () : %{ $trans->get_all_peptide_variations($source) };
    foreach my $t (values %snps) {
      foreach my $s (@$t) {
# Due to some changes start of a variation can be greater than its end - insertion happend
        my ($st, $en);
        if($s->start > $s->end) {
          $st = $s->end;
          $en = $s->start;
        } else {
          $en = $s->end;
          $st = $s->start;
        }
        foreach my $r ($st..$en) {
          $bps[$r-1]{'alleles'}.= $s->allele_string;
          my $snpclass = $s->var_class;
          if($snpclass eq 'snp' || $snpclass eq 'SNP - substitution') {
            my $aa = int(($r-$cd_start+3)/3);
            my $aa_bp = $aa*3+$cd_start - 3;
            my @Q = @{$protein_features{ "$aa" }||[]};
            if(@Q>1) {
              my $aas = join ', ', @Q;
              $bps[ $aa_bp - 1 ]{'aminoacids'} =
              $bps[ $aa_bp     ]{'aminoacids'} = 
              $bps[ $aa_bp + 1 ]{'aminoacids'} = $aas;
              $bps[ $aa_bp - 1 ]{'peptide'} =
              $bps[ $aa_bp + 1 ]{'peptide'} = '=';
            }
            $bps[$r-1]{'ambigcode'}= $s->ambig_code;
            if ($s->strand ne "$trans_strand"){
              $bps[$r-1]{'ambigcode'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
              $bps[$r-1]{'alleles'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
            }
            $bps[$r-1]{'snp'}= ( $bps[$r-1]{'snp'} eq 'snp' || @Q!=1 ) ? 'snp' : 'syn';
          } else {
            $bps[$r-1]{'snp'}= 'indel';
          }
        }
      }
    }
  } 
  return ($cd_start, $cd_end, $trans_strand, \@bps);
}

=head2 get_similarity_hash

 Arg[1]      : none
 Example     : @similarity_matches = $transdata->get_similarity_hash
 Description : Returns an arrayref of hashes conating similarity matches
 Return type : an array ref

=cut

sub get_similarity_hash{
  my $DBLINKS;
  eval { $DBLINKS = $_[0]->transcript->get_all_DBLinks; };   
  warn ("SIMILARITY_MATCHES Error on retrieving gene DB links $@") if ($@);    
  return $DBLINKS  || [];
}

=head2 get_go_list

 Arg[1]      : none
 Example     : @go_list = $transdata->get_go_list
 Description : Returns a hashref conating go links
 Return type : a hashref

=cut

sub get_go_list {
  my $self = shift ;
  my $trans = $self->transcript;
  my $goadaptor = $self->get_databases('go')->{'go'};# || return {};
  my @dblinks = @{$trans->get_all_DBLinks};
  my @goxrefs = grep{ $_->dbname eq 'GO' } @dblinks;

  my %go_hash;
  my %hash;
  foreach my $goxref ( sort{ $a->display_id cmp $a->display_id } @goxrefs ){
    my $go = $goxref->display_id;

    my $evidence = '';
    if( $goxref->isa('Bio::EnsEMBL::GoXref') ){
      $evidence = join( ", ", @{$goxref->get_all_linkage_types } ); 
    }
    (my $go2 = $go) =~ s/^GO\:0*//;
    my $term;
    next if exists $hash{$go2};
    $hash{$go2}=1;

    my $term_name;
    if( $goadaptor ){
      my $term;
      eval{ $term = $goadaptor->get_term({acc=>$go2}) };
      if($@){ warn( $@ ) }
      $term_name = $term ? $term->name : '';
    }
    $term_name ||= $goxref->description || '';
    $go_hash{$go} = [$evidence, $term_name];
  }
  return \%go_hash;
}

=head2 get_supporting_evidence
 Arg[1]      : none
 Example     : @supporting_evidence = $transdata->get_supporting_evidence
 Description : Returns a hashref conating supporting evidence hash as follows
 Return type : a hashref

=cut

sub get_supporting_evidence { ## USED!
  my $self    = shift;
  my $transid = $self->stable_id;
  my $db      =  $self->get_db;
  my $dbh     = $self->database($db);

  return undef if $self->transcript->isa('Bio::EnsEMBL::PredictionTranscript');
    # No evidence for PredictionTranscripts!

  # hack because can get exon supp evidence if transformed and
  # need the main transcript transformed for rest of page
  my $transcript_adaptor = $dbh->get_TranscriptAdaptor() ; 
  my $trans              = $transcript_adaptor->fetch_by_stable_id( $transid ); 
  $self->__data->{'_SE_trans'} = $trans ;
  my @dl_seq_list;
  my $show;
  my $exon_count=0;   # count the number of exons
  my $evidence = {
    'transcript' => { 'ID' => $self->stable_id, 'db' => $db, 'exon_count'=> 0, },
    'hits'      => {},
  };
  # Hack for Vega
  # Supporting evidence for annotated transcripts is per transcript/exon, not
  # just per exon (as in Ensembl).  To work around this, we get an annotated
  # transcript object, and get all the relevant supporting evidence IDs from
  # it.  Then we get the exon supporting evidence as usual, and discard any
  # evidence that is not in the AnnotatedTranscript evidence list.    
  my $annot_trans;
  my %orig_trans_evidence; 
  my %trans_evidence;
  if( ($self->species_defs->ENSEMBL_SITETYPE eq "Vega") && $self->database('vega') ){
    eval { 
      $annot_trans = $self->database('vega')->get_TranscriptAdaptor->fetch_by_stable_id($transid);
      # fetch the annotated evidence, take its name, and regex off any 
      # prefix: from it, then load it as keys of %trans_evidence.
      %orig_trans_evidence = map { (my $temp = $_->name) =~ s/^(\w*:)?//; $temp, 1 } $annot_trans->transcript_info->evidence;
      # remove numerical suffix from evidence identifier
      foreach my $key (keys %orig_trans_evidence) {
        my $orig_key = $key;
        $key  =~ s/\.\d+//;
        $trans_evidence{$key} = $orig_trans_evidence{$orig_key};
      }
    }; 
    warn "VEGA:supp_ev: $@" if $@;
  } 

  #Retrieve/make Exon data objects    
  foreach my $exonData ( @{$trans->get_all_Exons} ){
    $exon_count++;
    my $supporting_features;
    eval {
      $supporting_features = $exonData->get_all_supporting_features;
    };    
    if($@){
      warn("Error fetching Protein_Align_Feature: $@");
      return;
    } else {
      foreach my $this_feature (@{$supporting_features}) {
        my $dl_seq_name = $this_feature->hseqname;
        # Second part of Vega hack - throw away evidence not on this transcript
        # compare both before and after chopping off version numbers
        if( ($self->species_defs->ENSEMBL_SITETYPE eq "Vega") && $self->database('vega') ){
          (my $dl_seq_name_chopped) = $dl_seq_name =~ /(\w+)/;
          unless ($orig_trans_evidence{$dl_seq_name} || $orig_trans_evidence{$dl_seq_name_chopped}) {
            unless ($trans_evidence{$dl_seq_name} || $trans_evidence{$dl_seq_name_chopped}) {
              next;
            }
          }
        }  
        my $no_version_no;
        if($dl_seq_name =~ /^[A-Z]{2}\.\d+/i) {
          $no_version_no = $dl_seq_name;
        } else {
          $no_version_no = $dl_seq_name=~/^(\w+)\.\d+/ ? $1 : $dl_seq_name;
        }
        $evidence->{ 'hits' }{$dl_seq_name}{'link'} = $self->get_ExtURL('SRS_FALLBACK',$no_version_no);      
        $evidence->{ 'hits' }{$dl_seq_name}{'exon_ids'}[$exon_count - 1 ] = $exonData->stable_id;
        if( !defined( $evidence->{ 'hits' }{$dl_seq_name}{'datalib'} ) ) {
      # Create array to hold the feature top-score for each exon
          $evidence->{ 'hits' }{$dl_seq_name}{'scores'} = [];          
          push @dl_seq_list, $dl_seq_name ; # list to get descriptions in one go 
      # Hold the data library that this feature is from
          ($evidence->{ 'hits' }{$dl_seq_name}{'datalib'} = $this_feature->analysis->logic_name) =~ s/swir/Swir/;
          $show = 1; 
        }               
        # Compare to see if this is the top-score
        if( $this_feature->score > $evidence->{ 'hits' }{$dl_seq_name}{'scores'}[$exon_count - 1 ] ) {      
      # Adjust the top-score for this hit sequence
      # Subtract old score for this exon and add new score
          $evidence->{ 'hits' }{$dl_seq_name}{'total_score'} = 
          $evidence->{ 'hits' }{$dl_seq_name}{'total_score'} - 
          $this_feature->score > $evidence->{ 'hits' }{$dl_seq_name}{'scores'}[$exon_count - 1 ] + $this_feature->score;
      
      # Keep this new top-score                   
          $evidence->{ 'hits' }{$dl_seq_name}{'scores'}[$exon_count - 1] =$this_feature->score;                   
          if( $this_feature->score > $evidence->{ 'hits' }{$dl_seq_name}{'top_score'} ) {
            $evidence->{ 'hits' }{$dl_seq_name}{'top_score'} = $this_feature->score;
          }
        } # END if 
        $evidence->{ 'hits' }{$dl_seq_name}{'num_exon_hits'} = 0;
        for my $each_score (@{$evidence->{ 'hits' }{$dl_seq_name}{'scores'}}){
          $evidence->{ 'hits' }{$dl_seq_name}{'num_exon_hits'}++ if ($each_score);
        }
      }# END foreach $this_feature  
    }
  } # END foreach $this_exon
  return unless $show;
  $evidence->{ 'transcript' }{'exon_count'} = $exon_count;
  my $indexer = new EnsEMBL::Web::ExtIndex( $self->species_defs ); 
  my $result_ref;
  eval {
    $result_ref = $indexer->get_seq_by_id({ DB  => 'EMBL', ID  => (join " ", (sort @dl_seq_list) ), OPTIONS => 'desc' });
  };
  my $keyword =  $result_ref || [] ;
  my $i = 0 ;
  for my $id (sort  @dl_seq_list ){
    my $description = $keyword->[$i];
    $description =~ s/^DE\s+//g ;
    $description =~ tr/\n/ /;
    $evidence->{ 'hits' }{$id}{'description'} =
    $description =~ /no match/i ? 'No Description' : $description ||  'Unable to retrieve description';
    $i++;
  }
  return $evidence;   
}

sub rna_notation {
  my $self = shift;
  my $obj  = $self->Obj;
  my $T = $obj->get_all_Attributes('miRNA');
  my @strings = ();
  if(@$T) {
    my $string = '-' x $obj->length;
    foreach( @$T ) {
      my( $start, $end ) = split /-/, $_->value;
      substr( $string, $start-1, $end-$start+1 ) = '#' x ($end-$start);
    }
    push @strings, $string;
  }
  $T = $obj->get_all_Attributes('ncRNA');
  if(@$T) {
    my $string = '-' x $obj->length;
    foreach( @$T ) {
      my( $start,$end,$packed ) = $_->value =~ /^(\d+):(\d+)\s+(.*)/;
      substr( $string, $start-1, $end-$start+1 ) =
        join '', map { substr($_,0,1) x (substr($_,1)||1) } ( $packed=~/(\D\d*)/g );
    }
    push @strings, $string;
  }
  warn join "\n", @strings;
  return @strings;
}

sub location_string {
  my $self = shift;
  return sprintf( "%s:%s-%s", $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
}

1;

