package EnsEMBL::Web::Object::Translation;

### NAME: EnsEMBL::Web::Object::Translation
### Wrapper around a Bio::EnsEMBL::Translation object  

### PLUGGABLE: Yes, using Proxy::Object 

### STATUS: At Risk
### Required functionality now moved to Object::Transcript

### DESCRIPTION

use strict;

use base qw(EnsEMBL::Web::Object);

sub translation_object { return $_[0]; }
sub translation        { return $_[0]->Obj; }
sub type_name          { return $_[0]->species_defs->translate('Translation'); }
sub source             { return $_[0]->gene ? $_[0]->gene->source : undef;      }
sub gene_description   { return $_[0]->gene ? $_[0]->gene->description : undef; }
sub feature_type       { return $_[0]->Obj->type;       }
sub version            { return $_[0]->Obj->version;    }
sub coord_system       { return $_[0]->transcript->slice->coord_system->name; }
sub seq_region_type    { return $_[0]->coord_system; }
sub seq_region_name    { return $_[0]->transcript->slice->seq_region_name; }
sub seq_region_start   { return $_[0]->transcript->coding_region_start; }
sub seq_region_end     { return $_[0]->transcript->coding_region_end; }
sub seq_region_strand  { return $_[0]->transcript->strand; }

sub logic_name { 
  my $self = shift;
  return $self->gene->analysis ? $self->gene->analysis->logic_name : undef if $self->gene;
  return $self->transcript->analysis ? $self->transcript->analysis->logic_name : undef;
}

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

sub transcript {
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

=head2 db_type

 Arg[1]         : none
 Example     : $type = $pepdata->db_type
 Description : Gets the db type of ensembl feature
 Return type : string
                a db type (EnsEMBL, Vega, EST, etc.)

=cut

sub db_type {
    my $self = shift;
    my $db     = $self->get_db;
    my %db_hash = (  'core'       => 'Ensembl',
                     'est'       => 'EST',
                     'estgene'       => 'EST',
                     'vega'          => 'Vega');
    
    return $db_hash{$db};
}

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

=head2 stable_id

 Arg[1]         : none
 Example     : $stable_id = $pepdata->stable_id
 Description : Wrapper for stable_id on core_API
 Return type : string
                The features stable_id

=cut

sub stable_id {
  my $self = shift;
  return $self->translation ? $self->translation->stable_id : undef;
}

=head2 display_xref

 Arg[1]         : none
 Example     : ($xref_display_id, $xref_dbname) = $pep_data->display_xref
 Description : returns a pair value of xref display_id and xref dbname  (BRCA1, HUGO)
 Return type : a list

=cut

sub display_xref {
    my $self = shift;
    my $trans_xref = $self->transcript->display_xref;
    return ($trans_xref->display_id, $trans_xref->dbname, $trans_xref->primary_id, $trans_xref->db_display_name ) if $trans_xref;
}

=head2 get_protein_domains

 Arg[1]           : none
 Example     : $protein_domains = $pepdata->get_protein_domains
 Description : Returns all protein domains
 Return type : hashref for protein domains

=cut

sub get_protein_domains {
    my $self = shift;
    my $translation = $self->translation;
    $translation->dbID || return []; # E.g. PredictionTranscript
    return ( $translation->get_all_DomainFeatures);
}

=head2 get_all_ProteinFeatures

 Arg[1]           : type of feature :string
 Example     : $transmem_domains = $pepdata->get_all_ProteinFeatures
 Description : Returns features for a translation object
 Return type : array of ftranslation features

=cut

sub get_all_ProteinFeatures {
    my $self = shift;
    my $translation = $self->translation;
    $translation->dbID || return []; # E.g. PredictionTranscript
    return ( $translation->get_all_ProteinFeatures(shift));
}

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
                  'vdbid'      => 'Variation feature_id',
                ]

=cut

sub pep_snps {
  my $self  = shift;
  my $rtn_structure = shift;
  return $self->{'pep_snps'} if $self->{'pep_snps'}; 

  my $rtn = $rtn_structure eq 'hash' ? {} : [];

  return $rtn unless $self->species_defs->databases->{'DATABASE_VARIATION'};
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
    $aas[$j]{'nt'} = [split (//, $1)];
    $j++;  
  }

  my %snps= %{$trans->get_all_cdna_SNPs($source)};
  my %protein_features =%{$trans->get_all_peptide_variations($source)};
  my $coding_snps = $snps{'coding'};            # coding SNP only
  return $rtn unless @$coding_snps;

  foreach my $snp (@$coding_snps) {
    foreach my $residue ( $snp->start..$snp->end ) { # gets residues for snps longer than 1... indels
      my $aa = int(($residue-$cd_start+3)/3); # aminoacid residue number
      my $aa_bp = ($residue-$cd_start+3) % 3; # NT in codon for that amino acid (0,1,2)
      my $snpclass;
      my $alleles;
      my $id;
      $id = $snp->dbID; 
      $aas[$aa-1]{'vdbid'} = $id;
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
  $self->{'pep_snps'} = \@aas;
  
  if ($rtn_structure eq 'hash') {
    my $i = 0;
    
    for (@aas) {
      $rtn->{$i} = $_;
      $i++;
    }
    
    $self->{'pep_snps'} = $rtn;
  }
  
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

sub get_similarity_hash {
  my $self = shift;
  my $transl = $self->translation;
  my @DBLINKS;
  eval { @DBLINKS = @{$transl->get_all_DBEntries};};   
  warn ("SIMILARITY_MATCHES Error on retrieving translation DB links $@") if ($@);    
  return \@DBLINKS  || [];
}

#######################################################################
## ID history view stuff............................................ ##
#######################################################################

sub get_archive_object {
  my $self = shift;
  my $id = $self->stable_id;
  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  my $archive_object = $archive_adaptor->fetch_by_stable_id($id);

 return $archive_object;
}

=head2 history

 Arg1        : data object
 Description : gets the archive id history tree based around this ID
 Return type : listref of Bio::EnsEMBL::ArchiveStableId
               As every ArchiveStableId knows about it's successors, this is
                a linked tree.

=cut

sub history {
  my $self = shift;

  my $archive_adaptor = $self->database('core')->get_ArchiveStableIdAdaptor;
  return unless $archive_adaptor;

  my $history = $archive_adaptor->fetch_history_tree_by_stable_id($self->stable_id);
  return $history;
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
