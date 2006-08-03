package EnsEMBL::Web::Factory::Alignment;

use strict;
use warnings;
no warnings "uninitialized";

use EnsEMBL::Web::ExtIndex;

use EnsEMBL::Web::Factory;
use EnsEMBL::Web::Proxy::Object;
use EnsEMBL::Web::Document::SpreadSheet;
our @ISA = qw(  EnsEMBL::Web::Factory );

=head2 _createObjects

 Arg[1]      : none
 Example     : $self->_createObjects()
 Description : Always called from the parent module, 
               Creates and checks ensembl object(s)
 Return type : Nothing

=cut

sub _prob {
  my( $self, $caption, $error ) = @_;
  $self->problem( 'fatal', $caption, $self->web_usage.$error );
}

sub _createObjects {
  my( $self, $objects, $class ) = @_;
  my $obj  = EnsEMBL::Web::Proxy::Object->new( 'Alignment', $objects, $self->__data );

  $obj->class( $class );
  $self->DataObjects( $obj );
}

sub web_usage {
  my $self = shift;
  my $ss = EnsEMBL::Web::Document::SpreadSheet->new(
    [ { 'title' => 'Class' }, {'title' => 'Description'}, { 'title' => 'Required' },
      { 'title' => 'Optional' } ],
    []
  );
  foreach my $method (sort keys %EnsEMBL::Web::Factory::Alignment::) {
    next unless $method =~ /(usage_(\w+))$/;
    my $class = $2;
    my( $desc, $req, $opt ) = $self->$1();
    $ss->add_row([ $class, $desc,
      @$req ? qq(<dl><dt>@{[join ";</dt>\n<dt>", map {qq(<b>$_->[0]</b>: $_->[1])} @$req  ]}.</dt></dl>) : '&nbsp;',
      @$opt ? qq(<dl><dt>@{[join ";</dt>\n<dt>", map {qq(<b>$_->[0]</b>: $_->[1])} @$opt  ]}.</dt></dl>) : '&nbsp;'
    ]);
  }
  return '
  <p>
    The following classes of alignment can be rendered.
    A list of required and optional parameters are 
    listed:</p>'.
  $ss->render;
}

sub createObjects {
  my $self                 = shift;
  my $class                = $self->param('class');
  unless( $class ) {
    $class = 'External' if $self->param('sequence');
    $class = 'Family'   if $self->param('family_stable_id');
  }
  if( $class ) {
    my $method = "createObjects_$class";
    if( $self->can( $method ) ) {
      $self->$method;
    } else {
      $self->_prob( 'Unknown alignment class' );
    }
  } else {
    $self->_prob( 'Unspecified alignment class' );
  }
}

#---------

sub usage_AlignSlice {
  return 
    'AlignSlice Comparative',
    [ ['chr' => 'Name of the region' ]],
    [ ['bp_start' => 'Start of AlignSlice' ]],
    [ ['bp_end' => 'End of AlignSlice' ]],
    [ ['region' => 'Type of the region (scaffold etc, default - chromosome)']],
    [ ['method' => 'Compara method to get AlignSlice' ]],
    [ ['s'   => 'Secondary species'],
      ['format' => 'SimpleAlign renderer name'] ]
}

sub createObjects_AlignSlice {
  my $self            = shift;
  my $databases       = $self->DBConnection->get_databases( 'core', 'compara' ); #, 'compara_multiple' );

  my ($seq_region_name, $start, $end) = ($self->param('chr'), $self->param('bp_start'), $self->param('bp_end'));

  
  my $species = $ENV{ENSEMBL_SPECIES};
  my $query_slice_adaptor = Bio::EnsEMBL::Registry->get_adaptor($species, "core", "Slice");

  my $cs = $self->param('region') || 'chromosome';

  my $query_slice= $query_slice_adaptor->fetch_by_region($cs, $seq_region_name, $start, $end);


  my $id = $self->param('method') or return $self->_prob( 'Alignment ID is not provided');

  my $comparadb = $databases->{'compara'};
  
  my $mlss_adaptor = $comparadb->get_adaptor("MethodLinkSpeciesSet");

  my $method_link_species_set = $mlss_adaptor->fetch_by_dbID($id);

  return $self->_prob( "Unable to get Method Link Species Set $id" ) unless $method_link_species_set;
  eval {
      my $asa = $comparadb->get_adaptor("AlignSlice" );
      my $align_slice = $asa->fetch_by_Slice_MethodLinkSpeciesSet($query_slice, $method_link_species_set, "expanded" );

      $self->_createObjects( $align_slice, 'AlignSlice' );
  };


  return $self->_prob( 'Unable to get AlignSlice', "<pre>$@</pre>" ) if $@;
}

sub usage_Homology {
  return 
    'Comparative gene homologies',
    [ ['gene' => 'Name of gene' ]],
    [ ['g1'   => 'Secondary gene'],
      ['format' => 'SimpleAlign renderer name'] ]
}

sub createObjects_Homology {
  my $self            = shift;
  my $databases       = $self->DBConnection->get_databases( 'core', 'compara' );
  my $compara_db      = $databases->{'compara'};
  my $ma              = $compara_db->get_MemberAdaptor;
  my $qm              = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$self->param('gene'));
  return $self->_prob( 'Unable to find gene' ) unless $qm;
  eval {
    my $ha = $compara_db->get_HomologyAdaptor;
    my $homologies = $ha->fetch_by_Member($qm);
    $self->_createObjects( $ha->fetch_by_Member($qm), 'Homology' );
  };
  return $self->_prob( 'Unable to get homologies', "<pre>$@</pre>" ) if $@;
}

sub usage_Family {
  return 
    'Comparative family alignments',
    [ ['family_stable_id' => 'Ensembl family identifier'] ],
    [ ['format'           => 'SimpleAlign renderer name'] ];
}

sub createObjects_Family {
  my $self        = shift;
  my $databases   = $self->DBConnection->get_databases( 'core', 'compara' );
  my $compara_db  = $databases->{'compara'};
  my $family;
  eval { $family = $compara_db->get_FamilyAdaptor()->fetch_by_stable_id( $self->param( 'family_stable_id' ) ); };
  return $self->_prob( "unable to create Protein family" ) if $@ || !defined $family;
  $self->_createObjects( [$family], 'Family' );
}

sub usage_DnaDnaAlignFeature {
  return
    'Comparative DNA-DNA alignment',
    [ ['l = location in primary species'],
      ['s1 = secondary species'],
      ['l1 = location in secondary species'],
      ['type = type of match (TBLAT, BLASTZ...)'] ], 
    [];
}

sub createObjects_DnaDnaAlignFeature {
  my $self                       = shift;
  my $databases                  = $self->DBConnection->get_databases( 'core', 'compara' );
  (my $p_species                 = $self->species ) =~ s/_/ /;
  (my $s_species                 = $self->param('s1')      ) =~ s/_/ /;
  my( $p_chr, $p_start, $p_end ) = $self->param('l')=~/^(.+):(\d+)-(\d+)$/;
  my( $s_chr, $s_start, $s_end ) = $self->param('l1')=~/^(.+):(\d+)-(\d+)$/;
  my $type                       = $self->param( 'type' );
  my $compara_db                 = $databases->{'compara'};
  my $dafa                       = $compara_db->get_DnaAlignFeatureAdaptor;
  my $features;
  eval {
    $features = $dafa->fetch_all_by_species_region(
      $p_species, undef, $s_species, undef, $p_chr, $p_start, $p_end, $type
    );
  };
  return $self->_prob( 'Unable to find Dna Dna alignment' ) if $@;
  my $objects                    = [];
  foreach my $f ( @$features ) {
    if( $f->seqname eq $p_chr && $f->start == $p_start && $f->end == $p_end && $f->hseqname eq $s_chr && $f->hstart == $s_start && $f->hend == $s_end ) {
      push @$objects, $f; ## This IS the aligmnent of which we speak 
    }
  }
  return $self->_prob( 'Unable to find Dna Dna alignment' ) unless @$objects;
  $self->_createObjects( $objects, 'DnaDnaAlignFeature' ); 
}

sub usage_External {
  return
    'Alignment with external sequence',
    [ ['sequence', 'Identifier of external sequence'],
      ['ext_db',   'source of external sequence'],
      ['gene/transcript/exon', 'Identifier of internal sequence'] ],
    [];
}

sub createObjects_External {
  my $self      = shift;
  my $seqid     = $self->param( 'sequence' );
  my $db        = $self->param('db') || 'core';    # internal db to retrieve from
  my $ext_db    = $self->param('ext_db');    # external db to retrieve from
  my $tranid    = $self->param('transcript');
  my $exonid    = $self->param('exon');
  my $geneid    = $self->param('gene');
  # Get handle for core database
  my $database = $self->get_databases($db)->{$db};
  unless ($database){
    $self->problem( 'fatal', 'Database Error', "Could not connect to the required $db database." ); 
    return ;
  }
  # Get the external sequence 
  my $ext_seq = $self->get_ext_seq( $seqid, $ext_db );
  unless( $ext_seq ) {
    $self->problem( 'fatal', "External Feature Alignment Does Not Exist", "The sequence for feature $seqid could not be retrieved.");
    return;
  }
  my $seq_type = $self->determine_sequence_type( $ext_seq );
  my @int_seq;
  my $exon_obj;
  my @tran_obj_list;

  # Populate the objects to get int seq
  if( $tranid ){
    my $tran_obj;
    my $tran_apt = $database->get_TranscriptAdaptor;
    eval { $tran_obj =( $tran_apt->fetch_by_stable_id( $tranid ) || $tran_apt->fetch_by_dbID( $tranid )); };
    unless( $tran_obj ) {
      $self->problem( 'fatal',  "Feature not found", "No transcript object was found corresponding to the ID: $tranid ");
      return;
    }
    push @tran_obj_list, $tran_obj;
  } elsif( $geneid ){
    my $gene_obj;
    my $gene_apt = $database->get_GeneAdaptor;
    eval { $gene_obj = ($gene_apt->fetch_by_stable_id( $geneid ) || $gene_apt->fetch_by_dbID( $geneid)); };
    unless( $gene_obj ) {
      $self->problem( 'fatal',  "Feature not found", "No gene object was found corresponding to the ID: $geneid ");
      return;
    }
    # Get a list of transcripts corresponding to the geneid
    @tran_obj_list = @{$gene_obj->get_all_Transcripts};
  } elsif( $exonid ){
    my $exon_apt = $database->get_ExonAdaptor;
    eval { $exon_obj =( $exon_apt->fetch_by_stable_id( $exonid ) || $exon_apt->fetch_by_dbID( $exonid )); };
    unless( $exon_obj ) {
      $self->problem( 'fatal',  "Feature not found", "No exon object was found corresponding to the ID: $exonid ");
    }
  } else {
    $self->problem('fatal', "Please supply an identifier", "This page requires a gene or transcript to align to" );
    return;
  }
  if( $exon_obj ){
    my $is = $self->get_int_seq( $exon_obj, $seq_type);
    if( $is ) {
      push @int_seq , $is if $is;
    } else {
      $self->problem('fatal', "Unable to obtain internal sequence", "Unable to align peptide with non-coding transcript" );
    } 
  } else{
    @int_seq = grep { $_ } map { $self->get_int_seq( $_, $seq_type) } @tran_obj_list;      
    if( @tran_obj_list && !@int_seq ) {
      $self->problem('fatal', "Unable to obtain internal sequence", "Unable to align peptide with non-coding transcript" );
    }
  }
  if( @int_seq ) {
    my @internal;
    my $seqtype = $self->determine_sequence_type( $ext_seq);
    my $alignment;
    foreach my $int ( @int_seq ) { 
      push @internal, { 'seq' => $_, 'alignment' => $self->get_alignment( $ext_seq, $int, $seqtype ) };
    }
    $self->_createObjects( [ {'external_seq' => $ext_seq, 'internal_seqs' => \@internal, 'seqtype' => $seqtype} ], 'External' );
  } else { 
    $self->problem('fatal', "Ensembl Alignment Error", "The Ensembl sequence could not be retrieved.");
  }
}

## Support functions....

sub get_ext_seq{
  my ($self, $id, $ext_db) = @_;
  my $indexer = EnsEMBL::Web::ExtIndex->new( $self->species_defs );
  return unless $indexer; 
  my $seq_ary;
  my %args;
  $args{'ID'} = $id;
  $args{'DB'} = $ext_db if $ext_db;

  eval{
    $seq_ary = $indexer->get_seq_by_id(\%args);
  };
  if( $@ ){
    $self->problem( 'fatal', "Unable to fetch sequence",  "The $ext_db server is unavailable $@");
    return;
  }

  my $list = join " ", @$seq_ary;
  return $list =~ /no match/i ? '' : $list ;
}

sub save_seq {
  my $self = shift;
  my $content = shift ;
  my $seq_file = $self->species_defs->ENSEMBL_TMP_DIR.'/'."SEQ_".time().int(rand()*100000000).$$;
  open (TMP,">$seq_file") or die("Cannot create working file.$!");
  print TMP $content;
  close TMP;
  return ($seq_file)
}

sub get_alignment{
  my $self = shift;
  my $ext_seq  = shift || return undef();
  my $int_seq  = shift || return undef();
  my $seq_type = shift || return undef();

  $int_seq =~ s/<br \/>//g;

  my $int_seq_file = $self->save_seq($int_seq);
  my $ext_seq_file = $self->save_seq($ext_seq);

  my $dnaAlignExe = "%s/bin/matcher -asequence %s -bsequence %s -outfile %s";
  my $pepAlignExe = "%s/bin/psw -m %s/wisecfg/blosum62.bla %s %s > %s";

  my $out_file = time().int(rand()*100000000).$$;
  $out_file = $self->species_defs->ENSEMBL_TMP_DIR.'/'.$out_file.'.out';

  my $command;
  if( $seq_type eq 'DNA' ){
    $command = sprintf( $dnaAlignExe, $self->species_defs->ENSEMBL_EMBOSS_PATH, $int_seq_file, $ext_seq_file, $out_file );
  } elsif( $seq_type eq 'PEP' ){
    $command = sprintf( $pepAlignExe, $self->species_defs->ENSEMBL_WISE2_PATH, $self->species_defs->ENSEMBL_WISE2_PATH, $int_seq_file, $ext_seq_file, $out_file );
  } else{ 
    return undef;
  }

  my $retval = `$command`;
  open( OUT, "<$out_file" ) or $self->problem('fatal', "Cannot open alignment file.", $!);
  my $alignment ;
  while( <OUT> ){
    if( $_ =~ /# Report_file/o ){ next; }
    $alignment .= $_;
  }
  unlink( $out_file );
  unlink( $int_seq_file );
  unlink( $ext_seq_file );
  $alignment;
}


sub split60 {
  my($self,$seq) = @_;
  $seq =~s/(.{1,60})/$1\n/g;
  return $seq;
}

sub get_int_seq {
  my $self = shift;
  my $obj      = shift  || return undef();
  my $seq_type = shift  || return undef(); # DNA || PEP
  my $fasta_prefix = join( '', '>',$obj->stable_id(),"<br />\n");

  if( $seq_type eq "DNA" ){
    return $fasta_prefix.$self->split60($obj->seq->seq());
  } elsif( $seq_type eq "PEP" ){
    if( $obj->isa('Bio::EnsEMBL::Exon') && $obj->peptide() ){
      return $fasta_prefix.$self->split60($obj->peptide()->seq());
    } elsif( $obj->translate ) { 
      return $fasta_prefix.$self->split60($obj->translate->seq());
    }
  }
  return undef;
}

sub determine_sequence_type{
  my $self = shift;
  my $sequence = shift;
  my $threshold = shift || 70; # %ACGT for seq to qualify as DNA
  $sequence = uc( $sequence );
  $sequence =~ s/\s|N//;
  my $all_chars = length( $sequence );
  return unless $all_chars;
  my $dna_chars = ( $sequence =~ tr/ACGT// );
  return ( ( $dna_chars/$all_chars ) * 100 ) > $threshold ? 'DNA' : 'PEP';
}

sub usage_GeneTree {
  return 
    'Comparative gene homologies',
    [ ['gene' => 'Name of gene' ]],
    [ ['format' => 'SimpleAlign renderer name'] ]
}

sub createObjects_GeneTree {
  my $self            = shift;
  my $databases       = $self->DBConnection->get_databases( 'core', 'compara' );
  my $compara_db      = $databases->{'compara'};
  my $ma              = $compara_db->get_MemberAdaptor;
  my $member          = $ma->fetch_by_source_stable_id("ENSEMBLGENE",$self->param('gene'));
  return $self->_prob( 'Unable to find gene' ) unless $member;
  eval {
      my $clusterset_id = 0; 
      my $treeDBA = $compara_db->get_ProteinTreeAdaptor;
      my $aligned_member = $treeDBA->fetch_AlignedMember_by_member_id_root_id(
									      $member->get_longest_peptide_Member->member_id,
									      $clusterset_id);

      my $node = $aligned_member->subroot;
      my $tree = $treeDBA->fetch_node_by_node_id($node->node_id);
      $node->release_tree;
      $self->_createObjects( $tree, 'GeneTree' );
  };
  return $self->_prob( 'Unable to get homologies', "<pre>$@</pre>" ) if $@;
}

1;

