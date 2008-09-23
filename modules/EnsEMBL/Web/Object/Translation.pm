package EnsEMBL::Web::Object::Translation;

use strict;
#use warnings;
#no warnings "uninitialized";

use EnsEMBL::Web::Object;

our @ISA = qw(EnsEMBL::Web::Object);

sub get_database_matches {
  my $self = shift;
  my @DBLINKS;
  eval { @DBLINKS = @{$self->Obj->get_all_DBLinks};};
  return \@DBLINKS  || [];
}

sub type_name         { my $self = shift; return $self->species_defs->translate('Translation'); }
sub source            { my $self = shift; return $self->gene ? $self->gene->source : undef;      }
sub gene_description  { my $self = shift; return $self->gene ? $self->gene->description : undef; }
sub feature_type      { my $self = shift; return $self->Obj->type;       }
sub version           { my $self = shift; return $self->Obj->version;    }
sub logic_name        { my $self = shift;
                        return $self->gene->analysis ? $self->gene->analysis->logic_name : undef if $self->gene;
                        return $self->transcript->analysis ? $self->transcript->analysis->logic_name : undef;
}
sub coord_system      { my $self = shift; return $self->transcript->slice->coord_system->name; }
sub seq_region_type   { my $self = shift; return $self->coord_system; }
sub seq_region_name   { my $self = shift; return $self->transcript->slice->seq_region_name; }
sub seq_region_start  { my $self = shift; return $self->transcript->coding_region_start; }
sub seq_region_end    { my $self = shift; return $self->transcript->coding_region_end; }
sub seq_region_strand { my $self = shift; return $self->transcript->strand; }

sub translation_object { return $_[0]; }

sub feature_length    { 
	my $self   = shift;
	my $length = $self->seq_region_end - $self->seq_region_start + 1;
	return $length;
}

sub get_contig_location {
  my $self = shift;
  my $slice = $self->database('core')->get_SliceAdaptor->fetch_by_region( undef,
     $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
  my ($pr_seg) = @{$slice->project('seqlevel')};
  return undef unless $pr_seg;
  return (
    $self->neat_sr_name( $pr_seg->[2]->coord_system->name, $pr_seg->[2]->seq_region_name ),
    $pr_seg->[2]->seq_region_name,
    $pr_seg->[2]->start
  );
}

sub get_alternative_locations {
  my $self = shift;
  my @alt_locs = map { $_->cdna_coding_start ? [ $_->slice->seq_region_name, $_->cdna_coding_start, $_->cdna_coding_end, $_->slice->coord_system->name, ] : () }
                 @{$self->transcript->get_all_alt_locations};
  return \@alt_locs;
}

#----------------------------------------------------------------------

=head2 translation

 Arg[1]         : none
 Example     : my $ensembl_translation = $pepdata->translation
 Description : Gets the ensembl translation stored on the 
               transcript data object
 Return type : Bio::EnsEmbl::Translation

=cut

sub translation { return $_[0]->Obj; }

#----------------------------------------------------------------------

=head2 gene

 Arg[1]      : Bio::EnsEMBL::Translation - (OPTIONAL)
 Example     : $ensembl_gene = $pepdata->gene
               $pepdata->gene( $ensembl_gene )
 Description : returns the ensembl gene object if it exists on the
               translation object else it creates it from the
               core-api. Alternativly a ensembl gene object reference
               can be passed to the function if the translation is
               being created via a gene and so saves on creating a new
               gene object.


 Return type : Bio::EnsEMBL::Translation

=cut

sub gene {
  my $self = shift ;
  if(@_) {
    $self->__data->{'_gene'} = shift;
  } elsif( !$self->__data->{'_gene'} ) {
    my $db = $self->get_db() ;
    my $adaptor_call = $self->param('gene_adaptor') || 'get_GeneAdaptor';
    my $GeneAdaptor = $self->database($db)->$adaptor_call;
    my $Gene = $GeneAdaptor->fetch_by_translation_stable_id($self->stable_id);    
    $self->__data->{'_gene'} = $Gene if ($Gene);
  }
  return $self->__data->{'_gene'};
}

#----------------------------------------------------------------------

=head2 transcript

 Arg[1]         : Bio::EnsEMBL::transcript - (OPTIONAL)
 Example     : $ensembl_transcript = $pepdata->transcript
               $pepdata->transcript( $ensembl_transcript )
 Description : returns the ensembl transcript object if it exists on
               the translation object else it creates it from the
               core-api. Alternativly a ensembl transcript object
               reference can be passed to the function if the
               translation is being created via a transcript and so
               saves on creating a new transcript object.

 Return type : Bio::EnsEMBL::Transcript

=cut

sub transcript{
  my $self = shift;
  if(@_) {
    $self->__data->{'_transcript'} = shift;
  } elsif( !$self->__data->{'_transcript'} ) {
    my $db = $self->get_db() ;
    my $adaptor_call = $self->param('transcript_adaptor') || 'get_TranscriptAdaptor';
    my $transcriptAdaptor = $self->database($db)->$adaptor_call;
    my $transcript = $transcriptAdaptor->fetch_by_translation_stable_id($self->stable_id);    
    $self->__data->{'_transcript'} = $transcript if ($transcript);
  }
  return $self->__data->{'_transcript'} 
}

#----------------------------------------------------------------------

=head2 get_transcript_object

  Arg[1]      : none
  Example     : my $transdata = $pepdata->get_transcript_object
  Description : gets a transcript object from a peptide
  Return type : Bio::EnsEMBL::Web::Transcript

=cut

sub get_transcript_object {
  my $self = shift;
  my $transcript = $self->transcript;
  unless ($self->__data->{'_transcript_obj'}) {
    my $transcriptObj = EnsEMBL::Web::Proxy::Object->new( 'Transcript', $transcript, $self->__data );
    $transcriptObj->gene($self->gene);
    $self->__data->{'_transcript_obj'} = $transcriptObj;
  }
  return $self->__data->{'_transcript_obj'};
}

#----------------------------------------------------------------------

=head2 protein

 Arg[1]         : Bio::EnsEMBL::protein - (OPTIONAL)
 Example     : $ensembl_protein = $pepdata->protein
 Description : returns the ensembl protein object if it exists on the 
               translation object else it creates it from the core-api. 
               This call will soon be merged with peptide
 Return type : Bio::EnsEMBL::Protein

=cut

sub protein{ 
    my $self = shift;  
    warn( "DEPRECATED - use translation instead " . 
      join( ', ', (caller(0))[3,1,2] ) );
    return $self->translation;

# web core api has changed to there is no protein objects
# however this call is being kept for now for backwards compatability
#    if (!$self->{'_protein'}){
#        my $db = $self->get_db() ;
#        my $pepadaptor = $self->database($db)->get_ProteinAdaptor();
#        my $protein;
#        eval {$protein = #$pepadaptor->fetch_by_transcript_stable_id($self->transcript->stable_id);};
#        $self->{'_protein'} = $protein;         
#    }
#    return $self->{'_protein'} || undef;        
}

#----------------------------------------------------------------------

=head2 get_db

 Arg[1]         : none
 Example     : $db = $pepdata->get_db
 Description : Gets the database name used to create the object
 Return type : string
                a database type (core, est, snp, etc.)

=cut

sub get_db {
    my $self = shift;
    my $T = $self->param('db') || 'core';    
    $T = 'otherfeatures' if $T eq 'est';
    return $T;
}

#----------------------------------------------------------------------

#----------------------------------------------------------------------

=head2 db_type

 Arg[1]         : none
 Example     : $type = $pepdata->db_type
 Description : Gets the db type of ensembl feature
 Return type : string
                a db type (EnsEMBL, Vega, EST, etc.)

=cut

sub db_type{
    my $self = shift;
    my $db     = $self->get_db;
    my %db_hash = (  'core'       => 'Ensembl',
                     'est'       => 'EST',
                     'estgene'       => 'EST',
                     'vega'          => 'Vega');
    
    return $db_hash{$db};
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
  else{ return $self->transcript->analysis } # for things like genscans
}

#----------------------------------------------------------------------

=head2 stable_id

 Arg[1]         : none
 Example     : $stable_id = $pepdata->stable_id
 Description : Wrapper for stable_id on core_API
 Return type : string
                The features stable_id

=cut

sub stable_id{
  my $self = shift;
  return $self->translation ? $self->translation->stable_id : undef;
}

#----------------------------------------------------------------------

=head2 modified

 Description: DEPRECATED - Genes no longer have a modified attribute

=cut

sub modified {
    warn "DEPRECATED - Genes no longer have a modified attribute";
    return undef;
}

=head2 description

 Arg[1]         : none
 Example     : $description = $pepdata->description
 Description : Gets the description from the GENE object
 Return type : string
                The description of a feature

=cut

#
#----------------------------------------------------------------------

=head2 get_prediction_method

 Arg[1]         : none
 Example     : $prediction_method = $pepdata->get_prediction_method
 Description : Gets the prediction method for a gene
 Return type : string
                The prediction method of a feature

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
  if( ! $prediction_text ){
    my $confkey = "ENSEMBL_PREDICTION_TEXT_".uc($db);
    $prediction_text   = $self->species_defs->$confkey;
  }
  return($prediction_text);
}

#----------------------------------------------------------------------

=head2 get_author_name

 Arg[1]         : none
 Example     : $author = $pepdata->get_author_name
 Description : Gets the author of an annotated gene
 Return type : String
               The author name

=cut

sub get_author_name {
    my $self = shift;
	my $attribs;
    eval {$attribs = $self->gene->get_all_Attributes('author'); };
	return undef if $@; 
    if (@$attribs) {
        return $attribs->[0]->value;
    } else {
        return undef;
    }
}

#---------------------------------------------------------------------

=head2 get_author_email

 Arg[1]         : String
               Email address
 Example     : $email = $pepdata->get_author_email
 Description : Gets the author's email address of an annotated gene
 Return type : String
               The author's email address

=cut

sub get_author_email {
    my $self = shift;
    my $attribs = $self->gene->get_all_Attributes('author_email');
    if (@$attribs) {
        return $attribs->[0]->value;
    } else {
        return undef;
    }
}

#----------------------------------------------------------------------
=head2 display_xref

 Arg[1]         : none
 Example     : ($xref_display_id, $xref_dbname) = $pep_data->display_xref
 Description : returns a pair value of xref display_id and xref dbname  (BRCA1, HUGO)
 Return type : a list

=cut

sub display_xref{
    my $self = shift;
    my $trans_xref = $self->transcript->display_xref;
    return ($trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $trans_xref->db_display_name ) if $trans_xref;
}

#----------------------------------------------------------------------
=head2 get_interpro_object

 Arg[1]         : none
 Example     : $interpro = $pepdata->get_interpro_object
 Description : Returns interpro objects
 Return type : arrayref of interpro objects

=cut

sub get_interpro_object {
    my $self = shift ;
    my $trans = $self->transcript;
    my $db = $self->get_db ;
    my @interpro ;

    eval{@interpro = @{$self->database($db)->get_TranscriptAdaptor->get_Interpro_by_transid($trans->stable_id)};}; 
    return $@ ? [] :\@interpro;
}    

#----------------------------------------------------------------------

=head2 get_interpro_links

 Arg[1]           : none
 Example     : $interpro = $pepdata->get_interpro_links
 Description : Returns interpro links hash
 Return type : hashref for interpro links

=cut

sub get_interpro_links {
    my $self = shift ;
    my @interpro = @{$self->get_interpro_object};
    return {} unless(@interpro);
    
    my %interpro_hash;  
    foreach (sort @interpro){ 
        my($accession, $desc) = split(/:/,$_);           
        $interpro_hash{$accession} = $desc;
    }   
    return \%interpro_hash;
}

## expand pod to give how hash is structured for above and below function
#----------------------------------------------------------------------

=head2 get_family_object

 Arg[1]           : none
 Example     : $family = $pepdata->get_family_object
 Description : Returns family objects
 Return type : arrayref of family objects

=cut

sub get_family_object {
    my $self = shift ;
    my $translation = $self->translation;
    my $databases = $self->database('compara') ;
    my $family_adaptor;

    return [] unless ($translation && $databases);
    eval{ $family_adaptor = $databases->get_FamilyAdaptor };
    if ($@){ warn($@); return [] }
    my $families;
    eval{
      $families = $family_adaptor->fetch_by_Member_source_stable_id
    ('ENSEMBLPEP',$translation->stable_id)
    };        

    return $families || [];
}

#----------------------------------------------------------------------

=head2 get_family_links

 Arg[1]           : none
 Example     : $family = $pepdata->get_family_links
 Description : Returns family links
 Return type : hashref for family links

=cut

sub get_family_links {
  my $self = shift ;    
  my $taxon_id;    
    
  eval {
    my $meta = $self->database('core')->get_MetaContainer();
    $taxon_id = $meta->get_taxonomy_id();
  };
  if( $@ ){ warn($@) && return {} }

  my $families = $self->get_family_object || [];

  my %family_hash ;
  foreach my $family( @$families ){
    $family_hash{$family->stable_id}  = 
      {
       'description' => $family->description, 
       'count' => $family->Member_count_by_source_taxon
       ('ENSEMBLGENE',$taxon_id) 
      };
  }
  return \%family_hash;
}

#----------------------------------------------------------------------

=head2 get_protein_domains

 Arg[1]           : none
 Example     : $protein_domains = $pepdata->get_protein_domains
 Description : Returns all protein domains
 Return type : hashref for protein domains

=cut

sub get_protein_domains{
    my $self = shift;
    my $translation = $self->translation;
    $translation->dbID || return []; # E.g. PredictionTranscript
    return ( $translation->get_all_DomainFeatures);
}

#----------------------------------------------------------------------
=head2 get_all_ProteinFeatures

 Arg[1]           : type of feature :string
 Example     : $transmem_domains = $pepdata->get_all_ProteinFeatures
 Description : Returns features for a translation object
 Return type : array of ftranslation features

=cut

sub get_all_ProteinFeatures{
    my $self = shift;
    my $translation = $self->translation;
    $translation->dbID || return []; # E.g. PredictionTranscript
    return ( $translation->get_all_ProteinFeatures(shift));
}

#----------------------------------------------------------------------

=head2 get_pepstats

 Arg[1]           : none
 Example     : $pep_stat = $pepdata->get_pepstats
 Description : gives hash of pepstats
 Return type : hashref

=cut

sub get_pepstats {
  my $self = shift;
  my $peptide_seq ;
  eval { $peptide_seq = $self->Obj->seq ; };
  return {} if ($@ || $peptide_seq =~ m/[BZX]/ig);
  if( $peptide_seq !~ /\n$/ ){ $peptide_seq .= "\n" }
  $peptide_seq =~ s/\*$//;

  my $tmpfile = $self->species_defs->ENSEMBL_TMP_DIR."/$$.pep";
  open( TMP, "> $tmpfile" ) || warn "PEPSTAT: $!";
  print TMP "$peptide_seq";
  close(TMP);
  my $PEPSTATS = $self->species_defs->ENSEMBL_EMBOSS_PATH.'/bin/pepstats';
  open (OUT, "$PEPSTATS -filter < $tmpfile 2>&1 |") || warn "PEPSTAT: $!";
  my @lines = <OUT>;
  close(OUT);
  unlink($tmpfile);
  my %pepstats ;
  foreach my $line (@lines){
    if($line =~ /^Molecular weight = (\S+)(\s+)Residues = (\d+).*/){
      $pepstats{'Number of residues'} = $3 ;
      $pepstats{'Molecular weight'} = $1;
    }
    if($line =~ /^Average(\s+)(\S+)(\s+)(\S+)(\s+)=(\s+)(\S+)(\s+)(\S+)(\s+)=(\s+)(\S+)/){
      $pepstats{'Ave. residue weight'} = $7;
      $pepstats{'Charge'} = $12;
    }
    if($line =~ /^Isoelectric(\s+)(\S+)(\s+)=(\s+)(\S+)/){
      $pepstats{'Isoelectric point'} = $5;
    }
    if ($line =~ /FATAL/){            
      print STDERR "pepstats: $line\n";
      return {};
    }
  }
  return \%pepstats;
}

#----------------------------------------------------------------------

=head2 get_pep_seq

 Arg[1]           : none
 Example     : $pep_seq = $pepdata->get_pep_seq
 Description : returns a plain peptide sequence, if option numbers = on then
                bp numbers are also added
 Return type : a string
                peptide sequence

=cut

sub get_pep_seq{
      my $self = shift;
      my $peptide_seq ;
      eval {$peptide_seq = $self->translation->seq ;};

      return undef if (@_);
      my $number = $self->param('number');   
      my $wrap = 60;
      my $pos = 1-$wrap; 
  
      if($number eq 'on') {
        $peptide_seq =~ s|([\w*]{1,$wrap})|sprintf( "%6d %s\n",$pos+=$wrap,"$1")|eg;    
      } else {
        $peptide_seq =~ s|([\w*]{1,$wrap})|$1\n|g;    
      }      
      return $peptide_seq;
}

#----------------------------------------------------------------------

=head2 pep_splice_site

 Arg[1]           : none
 Example     : $splice_sites = $pepdata->pep_splice_site
 Description : Calculates any overlapping exon boundries for a peptide sequence
                it then builds a hash and stores it on the object. The hash contains
                the exon Ids, phase of the exon and if it has an overlapping slice site
                
                overlapping slice site = exon ends in the middle of a codon and therfore in the middle of
                                        a amino-acid residue of the protein
 Return type : hashref

=cut

sub pep_splice_site {
  my ($self, $peptide) = @_ ;
  return $self->{'pep_splice'} if ($self->{'pep_splice'} && !$peptide);

  my $trans = $self->transcript;
  my @exons = @{$trans->get_all_translateable_Exons};
  my $splice_site = {};
  my $i = 0;
  my $cdna_len = 0;
  my $pep_len  = 0;
  foreach my $e (@exons) {
    $cdna_len += $e->length;
    my $overlap_len = $cdna_len % 3;
    my $pep_len = $overlap_len ? 1+($cdna_len-$overlap_len)/3 : $cdna_len/3;
    $i++;
#    $splice_site->{$pep_len}{'overlap'} = $e->stable_id || $i;
    $splice_site->{$pep_len-1}{'overlap'} = $pep_len-1 if $overlap_len;
    $splice_site->{$pep_len}{'exon'}    = $e->stable_id || $i;
    $splice_site->{$pep_len}{'phase'}   = $overlap_len;
#    warn sprintf " N> %6d %d %s\n", $pep_len, $overlap_len,  $e->stable_id;
  }
  return $self->{'pep_splice'} = $splice_site;

  my %splice_site;
  my $pep_len = 0;
  my $overlap_len = 0;
  my $i;

  for my $exon (@exons){
    $i++;
    my $exon_id  = $exon->stable_id || $i;
    my $exon_len = $exon->length;
    my $pep_seq  = $exon->peptide( $trans )->length;
    # remove the first char of seq if overlap ($exon->peptide()) return full overlapping exon seq   
    $pep_seq -= 1 if ($overlap_len);
    $pep_len += $pep_seq;
    if ($overlap_len = (($exon_len + $overlap_len ) %3)){          # if there is an overlap     
      $splice_site{$pep_len-1}{'overlap'} = $pep_len -1;         # stores overlapping aa-exon boundary      
    } else {
      $overlap_len = 0; 
    }        
    $splice_site{$pep_len}{'exon'} = $exon_id;
    $splice_site{$pep_len}{'phase'} = $overlap_len;                 # positions of exon boundary                      
    warn sprintf " O> %6d %d %s\n", $pep_len, $overlap_len,  $exon_id;
  }     
  $self->{'pep_splice'} = \%splice_site;
  return  $self->{'pep_splice'};
}

#----------------------------------------------------------------------

=head2 pep_snps

 Args       : none
 Example    : $pep_snps = $self->pep_snps();
 Description : calculates snp positions and types on a peptide and give alternative codons, residues and alleles
 Returns    : a arrayref of co-ordinates with snp info

  Array returned  = AA_position [ 'nt'         => [bases at residue position],
                  'snp_id'     => 'SNP_ID' || undef,
                  'snp_source' => 'SNP_DB' || undef,
                  'ambigcode'  => 'Ambiguity code' || undef,
                  'allele'     => 'Alternative alleles',
                  'pep_snp'    =>'Alternative peptide residue',
                  'type'       => 'snp_type',
                ]

=cut

sub pep_snps{
  my $self  = shift ;
  return $self->{'pep_snps'} if ($self->{'pep_snps'} );

  use Time::HiRes qw(time);
  my $T = time;
  unless ($self->species_defs->databases->{'DATABASE_VARIATION'} || $self->species_defs->databases->{'ENSEMBL_GLOVAR'}) {
    return [];
  }
  $self->database('variation');
  my $source = "variation";  # only defined if glovar

  my $trans           = $self->transcript;
  my $cd_start        = $trans->cdna_coding_start;
  my $cd_end          = $trans->cdna_coding_end ;
  my $trans_strand    = $trans->get_all_Exons->[0]->strand;
  my $coding_sequence = substr($trans->seq->seq, $cd_start-1, $cd_end-$cd_start+1 );
  my $j = 0;
  my @aas;

  # add triplicate NTs into array into AA hash
  while( $coding_sequence =~ /(...)/g ){    
    $aas[$j]{'nt'} = [split //, $1];
    $j++;  
  }

  my %snps= %{$trans->get_all_cdna_SNPs($source)};
  my %protein_features =%{$trans->get_all_peptide_variations($source)};
  my $coding_snps = $snps{'coding'};            # coding SNP only
  return [] unless @$coding_snps;

  foreach my $snp (@$coding_snps) {
    foreach my $residue ( $snp->start..$snp->end ) { # gets residues for snps longer than 1... indels
      my $aa = int(($residue-$cd_start+3)/3); # aminoacid residue number
      my $aa_bp = ($residue-$cd_start+3) % 3; # NT in codon for that amino acid (0,1,2)
      my $snpclass;
      my $alleles;
      my $id;
      $id = $snp->dbID;
      $aas[$aa-1]{'snp_id'} = $snp->variation_name();
      if ( $snp->variation ) {
       $aas[$aa-1]{'snp_source'} = $snp->variation->source();
      }
      else {
        warn "we have a dodgy SNP -> '", $snp->variation_name,"' $residue!";
      }
      $snpclass = $snp->var_class;
      $alleles  = $snp->allele_string;

      if($snpclass eq 'snp' || $snpclass eq 'SNP - substitution') {
    # gets all changes to pep by snp
    my @non_syn_snp = @{$protein_features{ $aa }||[]};
     $aas[$aa-1]{'allele'} = $alleles;
    $aas[$aa-1]{'ambigcode'}[($residue-$cd_start)%3] = $snp->ambig_code || $snp->{'_ambiguity_code'};

    if ($snp->strand ne "$trans_strand"){
      $aas[$aa-1]{'ambigcode'}[($residue-$cd_start)%3] =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
      $aas[$aa-1]{'allele'} =~ tr/acgthvmrdbkynwsACGTDBKYHVMRNWS\//tgcadbkyhvmrnwsTGCAHVMRDBKYNWS\//;
    }        
    $aas[$aa-1]{'type'} = 'syn';
    
    if(@non_syn_snp >1) { 
      my $alt_residues = join ', ', @non_syn_snp;
      $aas[$aa-1]{'pep_snp'} = $alt_residues;        # alt AAs
      $aas[$aa-1]{'type'} = 'snp';
    }
      } 
      elsif ($snpclass eq 'in-del') {
    my $start = $snp->start;
    my $end = $snp->end;
    $aas[$aa-1]{'type'} = $start > $end ? 'insert' : 'delete';   
    $aas[$aa-1]{'type'} = 'frameshift' if (length($alleles) %3); 
    $alleles =~ s/-\/// ;
    $aas[$aa-1]{'indel'} = $id;
    $aas[$aa-1]{'allele'} = $alleles;
    $aas[$aa-1]{'allele'} =~ tr/ACGTN/TGCAN/d if ($snp->strand ne "$trans_strand");            
      }
    }  #end $residue
  }  #end $snp    
  warn time - $T," munged data"; $T = time;
  $self->{'pep_snps'} = \@aas;
  return $self->{'pep_snps'};
}

sub get_Slice {
  my( $self, $context, $ori ) = @_;

  my $db  = $self->get_db ;
  my $gene = $self->gene;
  my $slice = $gene->feature_Slice;
  if( $context && $context =~ /(\d+)%/ ) {
    $context = $slice->length * $1 / 100;
  }
  if( $ori && $slice->strand != $ori ) {
    $slice = $slice->invert();
  }
  return $slice->expand( $context, $context );
}

=head2 get_similarity_hash

 Arg[1]      : none
 Example     : @similarity_matches = $pepdata->get_similarity_hash
 Description : Returns an arrayref of hashes containing similarity matches
 Return type : an array ref

=cut

sub get_similarity_hash{
  my $self = shift;
  my $transl = $self->translation;
  my @DBLINKS;
  eval { @DBLINKS = @{$transl->get_all_DBEntries};};   
  warn ("SIMILARITY_MATCHES Error on retrieving translation DB links $@") if ($@);    
  return \@DBLINKS  || [];
}

sub location_string {
  my $self = shift;
  return sprintf( "%s:%s-%s", $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
}


#######################################################################
## DAS collection stuff............................................. ##
#######################################################################


sub get_das_factories {
  my $self = shift;
  return [ $self->Obj->adaptor()->db()->_each_DASFeatureFactory ];
}

sub get_das_features_by_name {
  my $self = shift;
  my $name  = shift || die( "Need a source name" );
  my $scope = shift || '';
  my $data = $self->__data;     
  my $cache = $self->Obj;

  $cache->{_das_features} ||= {}; # Cache
  my %das_features;
  foreach my $dasfact( @{$self->get_das_factories} ){
    my $type = $dasfact->adaptor->type;
    next if $dasfact->adaptor->type =~ /^ensembl_location/;
    my $name = $dasfact->adaptor->name;
    next unless $name;
    my $dsn = $dasfact->adaptor->dsn;
    my $url = $dasfact->adaptor->url;

# Construct a cache key : SOURCE_URL/TYPE
# Need the type to handle sources that serve multiple types of features

    my $key = $url || ($dasfact->adaptor->protocol .'://'.join('/', $dasfact->adaptor->domain, $dasfact->adaptor->dsn));

    unless( $cache->{_das_features}->{$key} ) { ## No cached values - so grab and store them!!
      my ($featref, $styleref) = $dasfact->fetch_all_by_ID($data->{_object}, $data );
      $cache->{_das_features}->{$key} = $featref;
    }
    $das_features{$name} = $cache->{_das_features}->{$key};
  }

  return @{ $das_features{$name} || [] };
}

sub get_das_features_by_slice {
  my $self = shift;
  my $name  = shift || die( "Need a source name" );
  my $slice = shift || die( "Need a slice" );
  my $cache = $self->Obj;     

  $cache->{_das_features} ||= {}; # Cache
  my %das_features;
  foreach my $dasfact( @{$self->get_das_factories} ){
    my $type = $dasfact->adaptor->type;
    next unless $dasfact->adaptor->type =~ /^ensembl_location/;
    my $name = $dasfact->adaptor->name;
    next unless $name;
    my $dsn = $dasfact->adaptor->dsn;
    my $url = $dasfact->adaptor->url;

# Construct a cache key : SOURCE_URL/TYPE
# Need the type to handle sources that serve multiple types of features

    my $key = $url || $dasfact->adaptor->protocol .'://'.$dasfact->adaptor->domain;
    $key .= "/$dsn/$type";

    unless( $cache->{_das_features}->{$key} ) { ## No cached values - so grab and store them!!
      my $featref = ($dasfact->fetch_all_by_Slice( $slice ))[0];
      $cache->{_das_features}->{$key} = $featref;
    }
    $das_features{$name} = $cache->{_das_features}->{$key};
  }

  return @{ $das_features{$name} || [] };
}


=head2 vega_projection

 Arg[1]	     : EnsEMBL::Web::Proxy::Object
 Arg[2]	     : Alternative assembly name
 Example     : my $v_slices = $object->ensembl_projection($alt_assembly)
 Description : map an object to an alternative (vega) assembly
 Return type : arrayref

=cut

sub vega_projection {
	my $self = shift;
	my $alt_assembly = shift;
	my $slice = $self->database('vega')->get_SliceAdaptor->fetch_by_region( undef,
       $self->seq_region_name, $self->seq_region_start, $self->seq_region_end );
	my $alt_projection = $slice->project('chromosome', $alt_assembly);
	my @alt_slices = ();
	foreach my $seg (@{ $alt_projection }) {
		my $alt_slice = $seg->to_Slice;
		push @alt_slices, $alt_slice;
	}
	return \@alt_slices;
}



1;
